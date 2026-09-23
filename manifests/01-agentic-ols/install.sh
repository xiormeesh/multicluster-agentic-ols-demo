#!/usr/bin/env bash
# Install the Agentic OLS quickstart on the hub from the immutable image lock.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config
require_digest_image AGENTIC_OPERATOR_IMAGE

QUICKSTART_DIR="${DEMO_ROOT}/.demo/sources/agentic-operator/hack/quickstart"
require_file "${QUICKSTART_DIR}/install.sh"

args=("--operator-image=${AGENTIC_OPERATOR_IMAGE}")
case "${WITH_POSTGRES:-false}" in
  true) args+=(--postgres) ;;
  false) ;;
  *) fail "WITH_POSTGRES must be true or false" ;;
esac

KUBECONFIG="$HUB_KUBECONFIG" bash "${QUICKSTART_DIR}/install.sh" "${args[@]}"

hub_oc rollout status deployment/lightspeed-agentic-operator -n "$NAMESPACE" \
  --timeout=300s
hub_oc scale deployment/lightspeed-agentic-alerts-adapter -n "$NAMESPACE" \
  --replicas=0
hub_oc rollout status deployment/lightspeed-agentic-alerts-adapter -n "$NAMESPACE" \
  --timeout=120s || true

hub_oc get crd agenticruns.agentic.openshift.io >/dev/null
hub_oc get configmap/lightspeed-agentic-configuration -n "$NAMESPACE" >/dev/null
hub_oc get deployment/lightspeed-agentic-alerts-adapter -n "$NAMESPACE" \
  -o jsonpath='{.spec.replicas}' | grep -qx '0'
printf 'Agentic OLS is ready and its single-cluster adapter is disabled\n'
