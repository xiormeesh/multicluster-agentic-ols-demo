#!/usr/bin/env bash
# Disable automatic runs and remove the demo-specific AAA host alias.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

# Stage 03 creates this ConfigMap even in core mode. Only reset it if it still
# matches the exact stage-05 configuration; preserve hub defaults or other edits.
if hub_exists configmap/hub-alerts-adapter-config -n "$NAMESPACE"; then
  current="$(hub_oc get configmap/hub-alerts-adapter-config -n "$NAMESPACE" \
    -o jsonpath='{.data.config\.yaml}')" || fail 'cannot read adapter configuration'
  if [[ "$current" == "$(< "$DIR/config.yaml")" ]]; then
    hub_oc patch configmap/hub-alerts-adapter-config -n "$NAMESPACE" --type=merge \
      -p '{"data":{"config.yaml":"filtering:\n  allowedReceivers: []\n"}}'
    if hub_exists deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE"; then
      hub_oc patch deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE" \
        --type=merge -p '{"spec":{"template":{"spec":{"hostAliases":null}}}}'
      hub_oc rollout restart deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE"
      hub_oc rollout status deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE" \
        --timeout=300s
    fi
  fi
fi
