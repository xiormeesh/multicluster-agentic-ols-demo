#!/usr/bin/env bash
# Remove the spoke while the hub controller is still available for finalizers.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

"$DIR/cleanup-spoke-run.sh"
hub_oc delete "spokecluster/${SPOKE_NAME}" --ignore-not-found
hub_oc wait --for=delete "spokecluster/${SPOKE_NAME}" --timeout=300s
hub_oc delete "secret/spoke-admin-kubeconfig-${SPOKE_NAME}" -n "$NAMESPACE" \
  --ignore-not-found
