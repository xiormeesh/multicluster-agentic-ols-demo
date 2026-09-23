#!/usr/bin/env bash
# Remove the hub only after every SpokeCluster has been deprovisioned.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

if [[ -n "$(hub_oc get spokeclusters.hub.openshift.io -o name 2>/dev/null)" ]]; then
  fail 'remove spoke registration before uninstalling lightspeed-hub'
fi

HUB_SOURCE="${DEMO_ROOT}/.demo/sources/hub"
require_file "${HUB_SOURCE}/config/crd/bases/hub.openshift.io_hubconfigs.yaml"

hub_oc delete hubconfig/cluster --ignore-not-found
hub_oc wait --for=delete hubconfig/cluster --timeout=180s 2>/dev/null || true
hub_oc delete deployment/lightspeed-hub-controller -n "$NAMESPACE" --ignore-not-found
hub_oc delete serviceaccount/lightspeed-hub-controller -n "$NAMESPACE" --ignore-not-found
hub_oc delete clusterrolebinding/lightspeed-hub-controller-demo --ignore-not-found
hub_oc delete -f "${HUB_SOURCE}/config/crd/bases" --ignore-not-found
