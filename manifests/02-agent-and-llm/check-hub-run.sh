#!/usr/bin/env bash
# Verify the manually approved hub-local quickstart smoke test completed.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

RUN_NAME="deploy-test-workload"
hub_oc wait --for=condition=Executed=True \
  "agenticruns.agentic.openshift.io/${RUN_NAME}" -n "$NAMESPACE" --timeout=600s
hub_oc get deployment/hello-test -n "$NAMESPACE" >/dev/null
hub_oc get service/hello-test -n "$NAMESPACE" >/dev/null
printf 'hub-local AgenticRun completed and created hello-test resources\n'
