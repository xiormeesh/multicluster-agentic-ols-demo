#!/usr/bin/env bash
# Remove demo-owned resources in reverse dependency order.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$ROOT/scripts/common.sh"

usage() {
  cat <<'USAGE'
Usage: ./teardown.sh

Remove demo-owned resources. The spoke registration is removed before the hub
controller so the hub can complete spoke cleanup finalizers.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

[[ $# -eq 0 ]] || fail "teardown.sh does not accept arguments"

for stage in \
  "07-demo-incident" \
  "05-alerts-adapter" \
  "04-spoke-registration" \
  "03-lightspeed-hub" \
  "02-agent-and-llm" \
  "01-agentic-ols"; do
  printf '=== removing %s ===\n' "$stage"
  run_stage "$stage" uninstall
done
