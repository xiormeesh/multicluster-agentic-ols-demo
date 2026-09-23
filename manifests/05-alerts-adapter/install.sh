#!/usr/bin/env bash
# Configure hub-owned AAA and give its pod spoke Alertmanager DNS reachability.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config
require_command python3
: "${SPOKE_ROUTER_IP:?SPOKE_ROUTER_IP is required}"

ALERTMANAGER_HOST="alertmanager-main-openshift-monitoring.apps.spoke.shiftlet.local"
hub_oc create configmap hub-alerts-adapter-config -n "$NAMESPACE" \
  --from-file=config.yaml="$DIR/config.yaml" --dry-run=client -o yaml | hub_oc apply -f -

patch="$(SPOKE_ROUTER_IP="$SPOKE_ROUTER_IP" python3 -c '
import json
import os
print(json.dumps({"spec": {"template": {"spec": {"hostAliases": [{
    "ip": os.environ["SPOKE_ROUTER_IP"],
    "hostnames": ["alertmanager-main-openshift-monitoring.apps.spoke.shiftlet.local"],
}]}}}}))
')"
hub_oc patch deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE" \
  --type=merge -p "$patch"
hub_oc rollout restart deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE"
hub_oc rollout status deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE" \
  --timeout=300s

hub_oc get configmap/hub-alerts-adapter-config -n "$NAMESPACE" \
  -o jsonpath='{.data.config\.yaml}' | grep -Fq -- '- critical'
hub_oc get deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.hostAliases[0].ip}' | grep -qx "$SPOKE_ROUTER_IP"

sleep 15
if hub_oc logs deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE" \
  --since=30s | grep -Fq 'failed to get alerts'; then
  fail "AAA still cannot reach the spoke Alertmanager"
fi
printf 'hub-owned AAA is configured and can poll the spoke Alertmanager\n'
