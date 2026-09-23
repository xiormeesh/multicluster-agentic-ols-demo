#!/usr/bin/env bash
# Start the direct target-spoke smoke test and wait for its analysis result.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

hub_oc apply -f "$DIR/spoke-run.yaml"
hub_oc wait --for=condition=Analyzed=True \
  agenticruns.agentic.openshift.io/direct-spoke-smoke -n "$NAMESPACE" \
  --timeout=600s

hub_oc get agenticruns.agentic.openshift.io/direct-spoke-smoke -n "$NAMESPACE" \
  -o jsonpath='{.spec.targetCluster}' | grep -qx "$SPOKE_NAME"
printf 'direct target-spoke analysis completed, approve execution in the console\n'
