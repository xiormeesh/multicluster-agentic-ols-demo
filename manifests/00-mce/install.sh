#!/usr/bin/env bash
# Optional MCE prerequisite: ensure the MCE operator, a MultiClusterEngine
# instance, and the imported demo spoke (with cluster-proxy) exist. This stage
# only sets up the MCE environment; it does not change the lightspeed-hub
# SpokeCluster credential source, which stays secret mode.
#
# Every step is idempotent and detects existing resources before creating them,
# so a failed run can be rerun to pick up where it left off. Crucially it never
# re-applies operator resources over an existing install (a second OperatorGroup
# breaks the CSV) and only creates the cluster-proxy add-on when it is missing
# (some MCE installs auto-deploy it via a global placement).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config
require_command envsubst

MCE_NAMESPACE="multicluster-engine"
MCE_CHANNEL="${MCE_CHANNEL:-stable-2.11}"
# Short by design: the import is complete without it, and in local setups the
# spoke often cannot reach the hub proxy endpoint (see the warning below).
CLUSTER_PROXY_TIMEOUT="${CLUSTER_PROXY_TIMEOUT:-120s}"
export MCE_CHANNEL SPOKE_NAME

# --- 1. Operator -------------------------------------------------------------
# The MCE CRD is created by the operator CSV, so its presence means the operator
# is already installed (manually or by a previous run). Do not touch operator
# resources in that case; re-applying the OperatorGroup is what broke the CSV.
if hub_exists crd multiclusterengines.multicluster.openshift.io; then
  printf 'MCE operator already installed (CRD present); skipping operator install\n'
else
  printf 'installing MCE operator (channel %s)\n' "$MCE_CHANNEL"
  hub_exists namespace "$MCE_NAMESPACE" || hub_oc create namespace "$MCE_NAMESPACE"

  # Only one OperatorGroup is allowed per namespace; create ours only if none.
  if [[ -n "$(hub_oc get operatorgroup -n "$MCE_NAMESPACE" -o name)" ]]; then
    printf 'an OperatorGroup already exists in %s; not creating another\n' "$MCE_NAMESPACE"
  else
    hub_oc apply -f "$DIR/operatorgroup.yaml"
  fi
  envsubst '${MCE_CHANNEL}' < "$DIR/subscription.yaml" | hub_oc apply -f -

  printf 'waiting for the MCE operator CSV to reach Succeeded\n'
  csv=""
  phase=""
  for _ in $(seq 1 60); do
    csv="$(hub_oc get subscription multicluster-engine -n "$MCE_NAMESPACE" \
      -o jsonpath='{.status.installedCSV}' 2>/dev/null || true)"
    if [[ -n "$csv" ]]; then
      phase="$(hub_oc get csv "$csv" -n "$MCE_NAMESPACE" \
        -o jsonpath='{.status.phase}' 2>/dev/null || true)"
      [[ "$phase" == "Succeeded" ]] && break
    fi
    sleep 10
  done
  [[ "${phase:-}" == "Succeeded" ]] || \
    fail "MCE CSV did not reach Succeeded (installedCSV: ${csv:-none}, phase: ${phase:-none}); inspect it in $MCE_NAMESPACE"
fi

# --- 2. MultiClusterEngine instance (only one allowed per cluster) -----------
# Never create a second instance over a manual one; verify the existing one.
mce_instance="$(hub_oc get multiclusterengine -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -n "$mce_instance" ]]; then
  printf 'MultiClusterEngine "%s" already exists; verifying instead of recreating\n' "$mce_instance"
else
  printf 'creating the recommended MultiClusterEngine instance "engine"\n'
  hub_oc apply -f "$DIR/multiclusterengine.yaml"
  mce_instance="engine"
fi
printf 'waiting for MultiClusterEngine/%s to become Available\n' "$mce_instance"
hub_oc wait --for=condition=Available "multiclusterengine/${mce_instance}" --timeout=600s

# --- 3. Import the spoke as a ManagedCluster --------------------------------
printf 'importing spoke "%s" into MCE\n' "$SPOKE_NAME"
hub_exists namespace "$SPOKE_NAME" || hub_oc create namespace "$SPOKE_NAME"

# auto-import-secret bootstraps the klusterlet on the spoke (no spoke pre-install).
# Rebuild it every run so a rotated spoke kubeconfig is always current.
flat_kubeconfig="$(mktemp)"
trap 'rm -f "$flat_kubeconfig"' EXIT
KUBECONFIG="$SPOKE_KUBECONFIG" oc config view --raw --flatten > "$flat_kubeconfig"
hub_oc create secret generic auto-import-secret -n "$SPOKE_NAME" \
  --from-file="kubeconfig=${flat_kubeconfig}" --dry-run=client -o yaml | hub_oc apply -f -

envsubst '${SPOKE_NAME}' < "$DIR/managedcluster.yaml" | hub_oc apply -f -

# Create the add-on only if MCE has not already provisioned it via a placement.
if hub_exists managedclusteraddon cluster-proxy -n "$SPOKE_NAME"; then
  printf 'cluster-proxy add-on already present; leaving it in place\n'
else
  envsubst '${SPOKE_NAME}' < "$DIR/cluster-proxy-addon.yaml" | hub_oc apply -f -
fi

for condition in HubAcceptedManagedCluster ManagedClusterJoined ManagedClusterConditionAvailable; do
  hub_oc wait --for="condition=${condition}" "managedcluster/${SPOKE_NAME}" --timeout=600s
done

# --- 4. cluster-proxy readiness (non-fatal) ---------------------------------
# The add-on reports Available via a health lease that the spoke agent only
# writes once its konnectivity tunnel to the hub connects. In local clusters
# without cross-cluster apps DNS the agent cannot resolve the hub proxy host, so
# this never goes Available. The import above is already complete and this does
# not block OLS-3954 development, so warn instead of failing.
printf 'checking cluster-proxy add-on availability (reported via lease)\n'
if hub_oc wait --for=condition=Available "managedclusteraddon/cluster-proxy" \
    -n "$SPOKE_NAME" --timeout="$CLUSTER_PROXY_TIMEOUT"; then
  proxy_state="Available"
else
  proxy_state="not Available"
  cat >&2 <<'WARN'
warning: cluster-proxy add-on is not Available yet.
  The ManagedCluster import is complete, but the spoke agent could not confirm
  its tunnel to the hub. In this local setup that is usually because the spoke
  cannot resolve the hub proxy endpoint (cluster-proxy-anp.apps.<hub>) from
  inside the cluster, so the health lease is never written. This does not block
  OLS-3954 development (tested without a live tunnel). For live MCE-mode spoke
  access, make that hub apps hostname resolve from the spoke (see README).
WARN
fi

printf 'MCE environment ready: operator, MultiClusterEngine/%s, spoke "%s" imported; cluster-proxy %s\n' \
  "$mce_instance" "$SPOKE_NAME" "$proxy_state"
