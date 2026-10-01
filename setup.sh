#!/usr/bin/env bash
# Install required demo stages in dependency order.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$ROOT/scripts/common.sh"

usage() {
  cat <<'USAGE'
Usage: ./setup.sh [--core] [--build-images] [--mce]

Install stages 01-05 by default, or only 01-04 for direct hub/spoke testing.
Stage 06 (incident) is always manual. Rerun after a failed stage to resume.

Options:
  --core          stop after spoke registration (no Alertmanager configuration)
  --build-images  build and lock controller images before cluster setup
  --mce           set up the MCE prerequisite first: install the operator,
                  ensure a MultiClusterEngine instance, and import the spoke
                  with cluster-proxy. Does not change the secret-mode
                  SpokeCluster registration (stage 04).
  -h, --help      show this help
USAGE
}

build_images=""
core=false
mce=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --core) core=true ;;
    --build-images) build_images=true ;;
    --mce) mce=true ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
  shift
done

load_demo_config
if [[ -z "$build_images" ]]; then
  build_images="${WITH_IMAGES:-false}"
fi

case "$build_images" in
  true) run_stage "00-images" install ;;
  false) ;;
  *) fail "WITH_IMAGES must be true or false" ;;
esac

# The MCE prerequisite is independent of the OLS stack, but importing the spoke
# and rolling out cluster-proxy is slow, so run it first and let it settle.
if [[ "$mce" == true ]]; then
  printf '=== 00-mce ===\n'
  run_stage "00-mce" install
fi

for stage in \
  "01-agentic-ols" \
  "02-agent-and-llm" \
  "03-lightspeed-hub" \
  "04-spoke-registration"; do
  printf '=== %s ===\n' "$stage"
  run_stage "$stage" install
done

if [[ "$core" == false ]]; then
  printf '=== 05-alerts-adapter ===\n'
  run_stage "05-alerts-adapter" install
fi
