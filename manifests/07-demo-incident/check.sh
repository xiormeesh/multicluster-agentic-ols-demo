#!/usr/bin/env bash
# Wait for AAA to create the target-spoke AgenticRun for the demo alert.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config
require_command python3

state_file="${DEMO_ROOT}/.demo/demo-incident.env"
selector='agentic.openshift.io/source=alertmanager,agentic.openshift.io/alert-name=democriticalalert'
deadline=$((SECONDS + 180))
run_name=""
while (( SECONDS < deadline )); do
  run_name="$(hub_oc get agenticruns.agentic.openshift.io -n "$NAMESPACE" \
    -l "$selector" -o json | \
    TARGET_SPOKE="$SPOKE_NAME" python3 -c '
import json
import os
import sys
runs = [
    run for run in json.load(sys.stdin).get("items", [])
    if run.get("spec", {}).get("targetCluster") == os.environ["TARGET_SPOKE"]
]
print(max(runs, key=lambda run: run["metadata"]["creationTimestamp"])["metadata"]["name"] if runs else "")
')"
  [[ -n "$run_name" ]] && break
  sleep 5
done

[[ -n "$run_name" ]] || fail "AAA did not create the demo AgenticRun within 180 seconds"
hub_oc get agenticruns.agentic.openshift.io "$run_name" -n "$NAMESPACE" \
  -o jsonpath='{.spec.targetCluster}' | grep -qx "$SPOKE_NAME"
mkdir -p "$(dirname "$state_file")"
printf 'DEMO_INCIDENT_RUN=%q\n' "$run_name" > "$state_file"
printf 'hub created target-spoke AgenticRun/%s, approve execution in the console\n' \
  "$run_name"
