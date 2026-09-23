#!/usr/bin/env bash
# Verify the manually approved direct target-spoke smoke test completed.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

hub_oc wait --for=condition=Executed=True \
  agenticruns.agentic.openshift.io/direct-spoke-smoke -n "$NAMESPACE" \
  --timeout=600s
spoke_oc get configmap/multicluster-proof -n openshift-lightspeed-managed \
  -o jsonpath='{.data.verified}' | grep -qx 'true'
printf 'direct target-spoke AgenticRun completed and wrote the proof ConfigMap\n'
