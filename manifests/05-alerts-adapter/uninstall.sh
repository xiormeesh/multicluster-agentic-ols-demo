#!/usr/bin/env bash
# Disable automatic runs and remove the demo-specific AAA host alias.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

hub_oc patch configmap/hub-alerts-adapter-config -n "$NAMESPACE" --type=merge \
  -p '{"data":{"config.yaml":"filtering:\n  allowedReceivers: []\n"}}'
if [[ -n "${SPOKE_ROUTER_IP:-}" ]]; then
  hub_oc patch deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE" \
    --type=merge -p '{"spec":{"template":{"spec":{"hostAliases":null}}}}'
fi
hub_oc rollout restart deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE"
hub_oc rollout status deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE" \
  --timeout=300s
