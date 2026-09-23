#!/usr/bin/env bash
# Install required demo stages in dependency order.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$ROOT/scripts/common.sh"

usage() {
  cat <<'USAGE'
Usage: ./setup.sh [--build-images]

Install the required Agentic OLS hub and spoke setup stages.

Options:
  --build-images  build and lock controller images before cluster setup
  -h, --help      show this help
USAGE
}

build_images=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-images) build_images=true ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
  shift
done

if [[ "$build_images" == true ]]; then
  run_stage "00-images" install
fi

for stage in \
  "01-agentic-ols" \
  "02-agent-and-llm" \
  "03-lightspeed-hub" \
  "04-spoke-registration" \
  "05-alerts-adapter"; do
  printf '=== %s ===\n' "$stage"
  run_stage "$stage" install
done
