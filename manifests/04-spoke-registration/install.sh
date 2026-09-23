#!/usr/bin/env bash
# Register the fixed spoke and wait for hub-managed spoke provisioning.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config
require_command envsubst

flat_kubeconfig="$(mktemp)"
trap 'rm -f "$flat_kubeconfig"' EXIT
SPOKE_API_SERVER="$(spoke_oc whoami --show-server)"
export SPOKE_API_SERVER

KUBECONFIG="$SPOKE_KUBECONFIG" oc config view --raw --flatten > "$flat_kubeconfig"
hub_oc create secret generic "spoke-admin-kubeconfig-${SPOKE_NAME}" -n "$NAMESPACE" \
  --from-file="kubeconfig=${flat_kubeconfig}" --dry-run=client -o yaml | hub_oc apply -f -
envsubst < "${DIR}/spokecluster.yaml" | hub_oc apply -f -

for condition in Connected Provisioned AdaptersReady Ready; do
  hub_oc wait --for="condition=${condition}" "spokecluster/${SPOKE_NAME}" \
    --timeout=600s
done

hub_oc get "secret/spoke-kubeconfig-${SPOKE_NAME}" -n "$NAMESPACE" >/dev/null
spoke_oc get namespace/openshift-lightspeed-managed >/dev/null
hub_oc rollout status deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE" \
  --timeout=300s
printf 'spoke registration is ready\n'
