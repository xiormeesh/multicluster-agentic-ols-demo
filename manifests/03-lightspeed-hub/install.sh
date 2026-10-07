#!/usr/bin/env bash
# Install the hub controller and its hub-owned multicluster alerts adapter.
# Reads DEMO_CREDENTIAL_MODE (secret|mce) from the environment to select the
# right HubConfig; defaults to secret if unset.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config
require_digest_image HUB_IMAGE
require_digest_image AAA_IMAGE

HUB_SOURCE="${DEMO_ROOT}/.demo/sources/hub"
require_file "${HUB_SOURCE}/config/crd/bases/hub.openshift.io_hubconfigs.yaml"
require_command envsubst

MODE="${DEMO_CREDENTIAL_MODE:-secret}"

hub_oc apply -f "${HUB_SOURCE}/config/crd/bases"
export HUB_IMAGE AAA_IMAGE
envsubst < "${DIR}/hub.yaml" | hub_oc apply -f -

# MCE mode needs the proxy CA ConfigMap for TLS to the cluster-proxy Service.
# The service-ca operator injects the cluster's service CA into ConfigMaps
# annotated with service.beta.openshift.io/inject-cabundle=true.
if [[ "$MODE" == mce ]]; then
  hub_oc apply -f "${DIR}/proxy-ca-configmap.yaml"
fi

# Apply the mode-specific HubConfig
case "$MODE" in
  secret) hub_oc apply -f "${DIR}/hubconfig-secret.yaml" ;;
  mce)    hub_oc apply -f "${DIR}/hubconfig-mce.yaml" ;;
  *)      fail "unknown credential mode: $MODE" ;;
esac

hub_oc rollout status deployment/lightspeed-hub-controller -n "$NAMESPACE" \
  --timeout=300s

# In MCE mode the hub auto-discovers spokes and creates the SpokeCluster.
# Wait for it to appear so we can verify the AAA adapter it triggers.
if [[ "$MODE" == mce ]]; then
  printf 'waiting for MCE auto-discovery to create SpokeCluster/%s\n' "$SPOKE_NAME"
  for _ in $(seq 1 60); do
    if hub_exists "spokecluster/${SPOKE_NAME}"; then
      break
    fi
    sleep 2
  done
  hub_exists "spokecluster/${SPOKE_NAME}" || \
    fail "SpokeCluster/${SPOKE_NAME} was not auto-discovered within 120s"
fi

for _ in $(seq 1 60); do
  if hub_oc get deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE" \
    >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
hub_oc get deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE" >/dev/null

adapter_image="$(hub_oc get deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].image}')"
[[ "$adapter_image" == "$AAA_IMAGE" ]] || \
  fail "hub-owned AAA image does not match the image lock"
hub_oc get deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].args}' | grep -Fq -- '--multicluster'
printf 'lightspeed-hub (%s mode) and its hub-owned multicluster AAA are ready\n' "$MODE"
