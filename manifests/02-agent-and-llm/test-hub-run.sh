#!/usr/bin/env bash
# Start the upstream hub-local full-lifecycle smoke test and wait for analysis.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

RUN_NAME="deploy-test-workload"
EXAMPLE="${DEMO_ROOT}/.demo/sources/agentic-operator/hack/quickstart/examples/deploy-test-workload.yaml"
require_file "$EXAMPLE"

hub_oc apply -f "$EXAMPLE"
printf 'approve analysis in the console, then this script will wait for its result\n'
hub_oc wait --for=condition=Analyzed=True \
  "agenticruns.agentic.openshift.io/${RUN_NAME}" -n "$NAMESPACE" --timeout=600s

printf 'analysis completed for %s, approve execution in the console before running check-hub-run.sh\n' \
  "$RUN_NAME"
