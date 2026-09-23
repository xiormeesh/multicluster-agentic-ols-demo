#!/usr/bin/env bash
# Configure hub-owned AAA and give its pod spoke Alertmanager DNS reachability.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config
require_command python3

ALERTMANAGER_HOST="alertmanager-main-openshift-monitoring.apps.spoke.shiftlet.local"
hub_oc create configmap hub-alerts-adapter-config -n "$NAMESPACE" \
  --from-file=config.yaml="$DIR/config.yaml" --dry-run=client -o yaml | hub_oc apply -f -

if [[ -n "${SPOKE_ROUTER_IP:-}" ]]; then
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
else
  printf 'SPOKE_ROUTER_IP is unset, using normal pod DNS for %s\n' \
    "$ALERTMANAGER_HOST"
fi
hub_oc rollout restart deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE"
hub_oc rollout status deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE" \
  --timeout=300s

config_yaml="$(hub_oc get configmap/hub-alerts-adapter-config -n "$NAMESPACE" \
  -o jsonpath='{.data.config\.yaml}')"
grep -Fqx 'pollInterval: "45s"' <<< "$config_yaml"
grep -Fqx 'preRunDelay: "10m"' <<< "$config_yaml"
grep -Fqx 'postRunDelay: "2h"' <<< "$config_yaml"
grep -Fqx '  - critical' <<< "$config_yaml"
if [[ -n "${SPOKE_ROUTER_IP:-}" ]]; then
  hub_oc get deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE" \
    -o jsonpath='{.spec.template.spec.hostAliases[0].ip}' | \
    grep -qx "$SPOKE_ROUTER_IP"
fi

sleep 15
if hub_oc logs deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE" \
  --since=30s | grep -Fq 'failed to get alerts'; then
  fail "AAA still cannot reach the spoke Alertmanager"
fi
printf 'hub-owned AAA is configured and can poll the spoke Alertmanager\n'
