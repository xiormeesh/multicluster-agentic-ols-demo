#!/usr/bin/env bash
# Configure the hub-owned AAA with production polling settings.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

# Replace the default ConfigMap (created by the hub controller) with the demo
# polling configuration. --force-conflicts handles the ownership annotation.
hub_oc create configmap hub-alerts-adapter-config -n "$NAMESPACE" \
  --from-file=config.yaml="$DIR/config.yaml" \
  --dry-run=client -o yaml | hub_oc apply --server-side --force-conflicts -f -

hub_oc rollout restart deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE"
hub_oc rollout status deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE" \
  --timeout=300s

# Verify the config was applied
config_yaml="$(hub_oc get configmap/hub-alerts-adapter-config -n "$NAMESPACE" \
  -o jsonpath='{.data.config\.yaml}')"
grep -Fqx 'pollInterval: "45s"' <<< "$config_yaml"
grep -Fqx 'preRunDelay: "10s"' <<< "$config_yaml"
grep -Fqx 'postRunDelay: "2h"' <<< "$config_yaml"
grep -Fqx '  - critical' <<< "$config_yaml"

sleep 15
if hub_oc logs deployment/lightspeed-hub-alerts-adapter -n "$NAMESPACE" \
  --since=30s | grep -Fq 'failed to get alerts'; then
  fail "AAA still cannot reach the spoke Alertmanager"
fi
printf 'hub-owned AAA is configured and can poll the spoke Alertmanager\n'
