#!/usr/bin/env bash
# Partial MCE teardown: detach the demo spoke only.
#
# This intentionally does NOT remove the MCE operator or the MultiClusterEngine
# instance. Reinstalling them is slow and they are shared environment infra, so
# a disposable-pair reset leaves them in place for the next setup. Remove them
# manually if a full MCE uninstall is ever needed (delete the MultiClusterEngine
# CR first, then the operator subscription/CSV and the multicluster-engine
# namespace).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

# Deleting the ManagedCluster detaches the spoke and removes its add-ons and
# per-cluster namespace via MCE; do not block on a possibly-offline spoke.
if hub_exists "managedcluster/${SPOKE_NAME}"; then
  hub_oc delete "managedcluster/${SPOKE_NAME}" --ignore-not-found --wait=false
  printf 'waiting up to 300s for spoke "%s" detach\n' "$SPOKE_NAME" >&2
  hub_oc wait --for=delete "managedcluster/${SPOKE_NAME}" --timeout=300s || \
    printf 'warning: ManagedCluster/%s still detaching; inspect it before reusing the cluster\n' \
      "$SPOKE_NAME" >&2
fi

hub_oc delete secret auto-import-secret -n "$SPOKE_NAME" --ignore-not-found
printf 'spoke "%s" detached from MCE; operator and MultiClusterEngine left in place\n' "$SPOKE_NAME"
