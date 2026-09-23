#!/usr/bin/env bash
# Install the hub controller and its hub-owned multicluster alerts adapter.
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

hub_oc apply -f "${HUB_SOURCE}/config/crd/bases"
export HUB_IMAGE AAA_IMAGE
envsubst < "${DIR}/hub.yaml" | hub_oc apply -f -

hub_oc rollout status deployment/lightspeed-hub-controller -n "$NAMESPACE" \
  --timeout=300s
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
printf 'lightspeed-hub and its hub-owned multicluster AAA are ready\n'
