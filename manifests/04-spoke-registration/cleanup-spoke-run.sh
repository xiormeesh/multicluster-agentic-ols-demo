#!/usr/bin/env bash
# Remove direct target-spoke smoke-test resources during stage cleanup only.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

hub_oc delete agenticruns.agentic.openshift.io/direct-spoke-smoke -n "$NAMESPACE" \
  --ignore-not-found
hub_oc wait --for=delete agenticruns.agentic.openshift.io/direct-spoke-smoke \
  -n "$NAMESPACE" --timeout=300s || true
spoke_oc delete configmap/multicluster-proof -n openshift-lightspeed-managed \
  --ignore-not-found
