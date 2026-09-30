#!/usr/bin/env bash
# Remove direct target-spoke smoke-test resources during stage cleanup only.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

if hub_exists crd agenticruns.agentic.openshift.io; then
  hub_oc delete agenticruns.agentic.openshift.io/direct-spoke-smoke -n "$NAMESPACE" \
    --ignore-not-found --wait=false
  # Stage 01 clears stuck run finalizers only after spoke registration cleanup.
  printf 'Direct spoke run deletion requested; finalizer cleanup is part of the confirmed namespace wipe\n' >&2
fi
if spoke_exists namespace/openshift-lightspeed-managed; then
  spoke_oc delete configmap/multicluster-proof -n openshift-lightspeed-managed \
    --ignore-not-found
fi
