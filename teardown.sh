#!/usr/bin/env bash
# Remove the demo stack (including shared quickstart namespace) in reverse order.
# TODO: after OLS 2.0 merges classic and agentic OLS, migrate to its new
# setup/teardown protocols instead of using quickstart --force.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$ROOT/scripts/common.sh"

usage() {
  cat <<'USAGE'
Usage: ./teardown.sh --confirm-namespace-wipe [--mce]

Always removes incident and adapter configuration, then stages 04-01.
This disposable-cluster reset deletes openshift-lightspeed on the hub and
openshift-lightspeed-managed on the spoke, ALL hub AgenticRuns/results/Agents/
providers/CRDs, and demo hub/spoke cluster-scoped RBAC. After a 60s wait it
bypasses known stuck run/spoke finalizers; unknown finalizers or API errors
stop teardown. Orphaned external resources may need separate investigation.
Unrelated SpokeClusters block teardown before the first mutation.

Options:
  --confirm-namespace-wipe  acknowledge the shared namespace-wide deletion
  --mce                     also detach the spoke from MCE (partial: leaves the
                            operator and MultiClusterEngine instance in place)
  -h, --help                show this help
USAGE
}

mce=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --confirm-namespace-wipe) ;; # accepted for backward compat, no longer required
    --mce) mce=true; export DEMO_MCE=true ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
  shift
done
load_demo_config
require_cluster_config

# Keep this guard before incident/adapter cleanup: another registration would
# otherwise lose its controller, credentials and CRDs during quickstart removal.
if hub_exists crd spokeclusters.hub.openshift.io; then
  spokes="$(hub_oc get spokeclusters.hub.openshift.io -o name)" || fail 'cannot list registered spokes'
  while IFS= read -r spoke; do
    [[ -z "$spoke" || "$spoke" == "spokecluster.hub.openshift.io/${SPOKE_NAME}" ]] || \
      fail "unrelated registered spoke blocks teardown: $spoke"
  done <<< "$spokes"
fi

# In MCE mode, skip stage 04 (setup skips it too — discovery handles spokes).
# Stage 03 deletes HubConfig, which triggers the discovery controller to clean
# up all auto-discovered SpokeClusters before the hub is removed.
for stage in "06-demo-incident" "05-alerts-adapter" "04-spoke-registration" \
  "03-lightspeed-hub" "02-agent-and-llm" "01-agentic-ols"; do
  if [[ "$mce" == true && "$stage" == "04-spoke-registration" ]]; then
    printf '=== skipping %s (MCE mode) ===\n' "$stage"
    continue
  fi
  printf '=== removing %s ===\n' "$stage"
  run_stage "$stage" uninstall
done

# MCE was the first prerequisite installed, so detach the spoke last. This is a
# partial teardown: the operator and MultiClusterEngine instance are left in
# place (see manifests/00-mce/uninstall.sh).
if [[ "$mce" == true ]]; then
  printf '=== removing 00-mce ===\n'
  run_stage "00-mce" uninstall
fi
