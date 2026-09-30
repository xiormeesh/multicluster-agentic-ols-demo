#!/usr/bin/env bash
# Remove the hub only after every SpokeCluster has been deprovisioned.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

if hub_exists crd spokeclusters.hub.openshift.io; then
  spokes="$(hub_oc get spokeclusters.hub.openshift.io -o name)" || fail 'cannot list registered spokes'
  [[ -z "$spokes" ]] || fail "remove registered spokes before uninstalling lightspeed-hub: $spokes"
fi

HUB_SOURCE="${DEMO_ROOT}/.demo/sources/hub"
if hub_exists crd hubconfigs.hub.openshift.io; then
  require_file "${HUB_SOURCE}/config/crd/bases/hub.openshift.io_hubconfigs.yaml"
  hub_oc delete hubconfig/cluster --ignore-not-found --wait=false
  if hub_exists hubconfig/cluster; then
    printf 'Waiting up to 60s for HubConfig adapter cleanup before forced fallback...\n' >&2
    for _ in $(seq 1 60); do
      hub_exists hubconfig/cluster || break
      sleep 1
    done
    if hub_exists hubconfig/cluster; then
      clear_hub_finalizers hubconfig/cluster 'hub.openshift.io/adapter-cleanup'
    fi
    if hub_exists hubconfig/cluster; then
      hub_oc wait --for=delete hubconfig/cluster --timeout=60s || \
        fail 'HubConfig/cluster remains after known-finalizer cleanup'
    fi
  fi
fi
# If HubConfig was already missing, its adapter cleanup never ran. These
# cluster-scoped resources do not disappear with the hub namespace.
hub_oc delete clusterrolebinding/lightspeed-hub-alerts-adapter-cluster \
  clusterrole/lightspeed-hub-alerts-adapter-cluster --ignore-not-found
hub_oc delete rolebinding/lightspeed-hub-alerts-adapter-alertmanager \
  -n openshift-monitoring --ignore-not-found
hub_oc delete deployment/lightspeed-hub-alerts-adapter \
  configmap/hub-alerts-adapter-config -n "$NAMESPACE" --ignore-not-found
hub_oc delete deployment/lightspeed-hub-controller -n "$NAMESPACE" --ignore-not-found
hub_oc delete serviceaccount/lightspeed-hub-controller -n "$NAMESPACE" --ignore-not-found
hub_oc delete clusterrolebinding/lightspeed-hub-controller-demo --ignore-not-found
if hub_exists crd hubconfigs.hub.openshift.io || \
  hub_exists crd spokeclusters.hub.openshift.io; then
  require_file "${HUB_SOURCE}/config/crd/bases/hub.openshift.io_hubconfigs.yaml"
  hub_oc delete -f "${HUB_SOURCE}/config/crd/bases" --ignore-not-found
fi
