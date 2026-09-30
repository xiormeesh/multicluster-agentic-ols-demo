#!/usr/bin/env bash
# Exercise top-level dispatch and safety gates with no cluster access.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/scripts"
cp "$ROOT/setup.sh" "$ROOT/teardown.sh" "$tmp/"
printf '%s\n' \
  'fail() { printf "error: %s\n" "$*" >&2; exit 1; }' \
  'load_demo_config() { SPOKE_NAME=spoke; }' \
  'require_cluster_config() { :; }' \
  'hub_exists() { [[ "${MOCK_SPOKES:-}" != missing ]]; }' \
  'hub_oc() { printf "%s\n" "${MOCK_SPOKES:-}"; }' \
  'run_stage() { printf "%s %s\n" "$1" "$2"; [[ "$1" != "${FAIL_STAGE:-}" ]]; }' \
  > "$tmp/scripts/common.sh"

assert_output() {
  local expected="$1"
  shift
  local actual
  actual="$("$@")"
  [[ "$actual" == "$expected" ]] || {
    printf 'expected:\n%s\ngot:\n%s\n' "$expected" "$actual" >&2
    exit 1
  }
}

core=$'=== 01-agentic-ols ===\n01-agentic-ols install\n=== 02-agent-and-llm ===\n02-agent-and-llm install\n=== 03-lightspeed-hub ===\n03-lightspeed-hub install\n=== 04-spoke-registration ===\n04-spoke-registration install'
full="${core}"$'\n=== 05-alerts-adapter ===\n05-alerts-adapter install'
assert_output "$core" bash "$tmp/setup.sh" --core
assert_output "$full" bash "$tmp/setup.sh"
if FAIL_STAGE=03-lightspeed-hub bash "$tmp/setup.sh" --core \
  > "$tmp/output" 2>&1; then
  printf 'expected setup failure to propagate\n' >&2
  exit 1
fi
! grep -q '04-spoke-registration install' "$tmp/output"
assert_output "$core" bash "$tmp/setup.sh" --core # retry after failure
images="$(WITH_IMAGES=true bash "$tmp/setup.sh" --core)"
[[ "$images" == $'=== 01-agentic-ols ==='* ]] && exit 1
[[ "$images" == *'00-images install'* ]] && [[ "$images" == *'04-spoke-registration install'* ]]

removed=$'=== removing 06-demo-incident ===\n06-demo-incident uninstall\n=== removing 05-alerts-adapter ===\n05-alerts-adapter uninstall\n=== removing 04-spoke-registration ===\n04-spoke-registration uninstall\n=== removing 03-lightspeed-hub ===\n03-lightspeed-hub uninstall\n=== removing 02-agent-and-llm ===\n02-agent-and-llm uninstall\n=== removing 01-agentic-ols ===\n01-agentic-ols uninstall'
MOCK_SPOKES='spokecluster.hub.openshift.io/spoke' assert_output "$removed" bash "$tmp/teardown.sh" --confirm-namespace-wipe
if bash "$tmp/teardown.sh" > "$tmp/output" 2>&1; then
  printf 'expected namespace confirmation gate\n' >&2
  exit 1
fi
grep -q 'ALL hub AgenticRuns' "$tmp/output"
grep -q 'namespace-wide wipe, run: ./teardown.sh --confirm-namespace-wipe' "$tmp/output"
! grep -q '^=== removing' "$tmp/output"
if bash "$tmp/teardown.sh" --core --confirm-namespace-wipe >/dev/null 2>&1; then
  printf 'expected unsupported teardown selection to fail\n' >&2
  exit 1
fi
if MOCK_SPOKES=$'spokecluster.hub.openshift.io/spoke\nspokecluster.hub.openshift.io/other' \
  bash "$tmp/teardown.sh" --confirm-namespace-wipe > "$tmp/output" 2>&1; then
  printf 'expected unrelated spoke guard\n' >&2
  exit 1
fi
! grep -q '^=== removing' "$tmp/output"
if FAIL_STAGE=04-spoke-registration bash "$tmp/teardown.sh" \
  --confirm-namespace-wipe > "$tmp/output" 2>&1; then
  printf 'expected failure propagation\n' >&2
  exit 1
fi
! grep -q '03-lightspeed-hub uninstall' "$tmp/output"

# Stage 03 owns the adapter ConfigMap even in core mode. Stage 05 must not
# patch/restart if its configuration is absent or still the hub default.
mkdir -p "$tmp/manifests/05-alerts-adapter"
cp "$ROOT/manifests/05-alerts-adapter/uninstall.sh" \
  "$ROOT/manifests/05-alerts-adapter/config.yaml" \
  "$tmp/manifests/05-alerts-adapter/"
printf '%s\n' \
  'load_demo_config() { NAMESPACE=openshift-lightspeed; }' \
  'require_cluster_config() { :; }' \
  'hub_exists() { [[ "$1" == configmap/hub-alerts-adapter-config && "${MOCK_CONFIG:-}" == present ]] || [[ "$1" == deployment/lightspeed-hub-alerts-adapter ]]; }' \
  'hub_oc() { if [[ "$1" == get ]]; then if [[ "${MOCK_CONFIG:-}" == default ]]; then printf "filtering:\n  allowedReceivers: []\n"; else printf "%s" "$(< "$MOCK_CONFIG_FILE")"; fi; else printf "%s\n" "$*" >> "$MOCK_LOG"; [[ "${MOCK_FAIL:-}" != patch || "$1" != patch ]]; fi; }' \
  > "$tmp/scripts/common.sh"
MOCK_LOG="$tmp/calls" bash "$tmp/manifests/05-alerts-adapter/uninstall.sh"
[[ ! -f "$tmp/calls" ]]
MOCK_LOG="$tmp/calls" MOCK_CONFIG=default \
  bash "$tmp/manifests/05-alerts-adapter/uninstall.sh"
[[ ! -f "$tmp/calls" ]]
MOCK_LOG="$tmp/calls" MOCK_CONFIG=present \
  MOCK_CONFIG_FILE="$tmp/manifests/05-alerts-adapter/config.yaml" \
  bash "$tmp/manifests/05-alerts-adapter/uninstall.sh"
grep -q 'patch configmap/hub-alerts-adapter-config' "$tmp/calls"
if MOCK_LOG="$tmp/calls" MOCK_CONFIG=present MOCK_FAIL=patch \
  MOCK_CONFIG_FILE="$tmp/manifests/05-alerts-adapter/config.yaml" \
  bash "$tmp/manifests/05-alerts-adapter/uninstall.sh" >/dev/null 2>&1; then
  printf 'expected stage 05 API failure to propagate\n' >&2
  exit 1
fi

printf 'lifecycle dispatch checks passed\n'
