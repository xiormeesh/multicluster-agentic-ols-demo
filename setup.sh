#!/usr/bin/env bash
# Install required demo stages in dependency order.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$ROOT/scripts/common.sh"

usage() {
  cat <<'USAGE'
Usage: ./setup.sh <--secret | --mce> [--core] [--build-images]

Set up the multicluster Agentic OLS demo with either secret-based or
MCE-based spoke credentials.

Credential mode (exactly one required):
  --secret        spoke registered via admin kubeconfig Secret (stage 04)
  --mce           spoke auto-discovered via MCE cluster-proxy (stage 00-mce);
                  stage 04 is skipped because MCE auto-creates the SpokeCluster

Common options:
  --core          stop after spoke registration (no Alertmanager configuration);
                  useful for e2e test environments
  --build-images  build and lock controller images before cluster setup
  -h, --help      show this help

Examples:
  ./setup.sh --secret --core          # e2e baseline with admin kubeconfig
  ./setup.sh --mce --core             # e2e baseline with MCE auto-discovery
  ./setup.sh --secret                 # full demo with alerts adapter
  ./setup.sh --mce                    # full demo with MCE + alerts adapter
  ./setup.sh --mce --build-images     # rebuild images, then full MCE demo
USAGE
}

build_images=""
core=false
mode=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --core) core=true ;;
    --build-images) build_images=true ;;
    --secret)
      [[ -z "$mode" ]] || fail "cannot combine --secret and --mce"
      mode=secret ;;
    --mce)
      [[ -z "$mode" ]] || fail "cannot combine --secret and --mce"
      mode=mce ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
  shift
done

[[ -n "$mode" ]] || fail "credential mode is required: --secret or --mce"

load_demo_config
if [[ -z "$build_images" ]]; then
  build_images="${WITH_IMAGES:-false}"
fi

case "$build_images" in
  true) run_stage "00-images" install ;;
  false) ;;
  *) fail "WITH_IMAGES must be true or false" ;;
esac

# MCE prerequisite: install operator, MCE instance, import spoke, cluster-proxy.
# Run first so the spoke import can settle while OLS stages install.
if [[ "$mode" == mce ]]; then
  printf '=== 00-mce ===\n'
  run_stage "00-mce" install
fi

# Export the credential mode so stage 03 (lightspeed-hub) can select the right
# HubConfig and stage 04 can be conditionally skipped.
export DEMO_CREDENTIAL_MODE="$mode"

for stage in \
  "01-agentic-ols" \
  "02-agent-and-llm" \
  "03-lightspeed-hub"; do
  printf '=== %s ===\n' "$stage"
  run_stage "$stage" install
done

# Stage 04 creates a secret-mode SpokeCluster with an admin kubeconfig.
# In MCE mode the hub auto-discovers spokes from ManagedCluster CRs, so
# stage 04 is skipped entirely.
if [[ "$mode" == secret ]]; then
  printf '=== 04-spoke-registration ===\n'
  run_stage "04-spoke-registration" install
fi

if [[ "$core" == false ]]; then
  printf '=== 05-alerts-adapter ===\n'
  run_stage "05-alerts-adapter" install
fi
