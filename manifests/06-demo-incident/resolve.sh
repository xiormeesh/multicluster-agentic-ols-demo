#!/usr/bin/env bash
# Clear the always-firing spoke PrometheusRule while retaining its AgenticRun.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

if spoke_exists crd prometheusrules.monitoring.coreos.com; then
  spoke_oc delete -f "$DIR/prometheusrule.yaml" --ignore-not-found --wait=false
  if spoke_exists prometheusrule/demo-critical-alert -n openshift-monitoring; then
    spoke_oc wait --for=delete prometheusrule/demo-critical-alert \
      -n openshift-monitoring --timeout=60s || \
      fail 'demo PrometheusRule is still deleting; inspect its finalizers'
  fi
fi
printf 'cleared DemoCriticalAlert PrometheusRule, retained AgenticRun resources are unchanged\n'
