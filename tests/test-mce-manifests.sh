#!/usr/bin/env bash
# Validate the rendered 00-mce manifests against the hub API without creating
# anything. The cluster-scoped ManagedCluster gets a full server-side dry-run
# (admission + required fields); objects whose target namespace does not exist
# yet fall back to client-side schema validation. Requires HUB_KUBECONFIG and
# the MCE CRDs; it is a live check, not part of the offline suite.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/common.sh
source "$ROOT/scripts/common.sh"

load_demo_config
: "${HUB_KUBECONFIG:?HUB_KUBECONFIG is required}"
require_file "$HUB_KUBECONFIG"
require_command oc
require_command envsubst

MANIFESTS="$ROOT/manifests/00-mce"
export SPOKE_NAME
export MCE_CHANNEL="${MCE_CHANNEL:-stable-2.11}"

for crd in managedclusters.cluster.open-cluster-management.io \
  managedclusteraddons.addon.open-cluster-management.io; do
  hub_exists crd "$crd" || fail "missing CRD $crd; run against a hub with MCE installed"
done

# ManagedCluster is cluster-scoped: validate it in full against admission.
printf 'ManagedCluster: server-side dry-run\n'
envsubst '${SPOKE_NAME}' < "$MANIFESTS/managedcluster.yaml" \
  | hub_oc apply --dry-run=server -f -

# The add-on lives in the spoke's namespace, which only exists after import.
# Server dry-run when it is present, otherwise schema-validate the fields.
addon_mode=client
if hub_exists namespace "$SPOKE_NAME"; then
  addon_mode=server
fi
printf 'ManagedClusterAddOn (cluster-proxy): %s-side dry-run\n' "$addon_mode"
envsubst '${SPOKE_NAME}' < "$MANIFESTS/cluster-proxy-addon.yaml" \
  | hub_oc apply "--dry-run=${addon_mode}" --validate=true -f -

# Static operator/engine manifests: schema validation (install.sh never applies
# these over an existing install, so avoid a live-state update diff).
printf 'operator group + subscription: client-side schema dry-run\n'
hub_oc apply --dry-run=client --validate=true -f "$MANIFESTS/operatorgroup.yaml"
envsubst '${MCE_CHANNEL}' < "$MANIFESTS/subscription.yaml" \
  | hub_oc apply --dry-run=client --validate=true -f -
printf 'MultiClusterEngine profile: client-side schema dry-run\n'
hub_oc apply --dry-run=client --validate=true -f "$MANIFESTS/multiclusterengine.yaml"

printf 'all 00-mce manifests validated\n'
