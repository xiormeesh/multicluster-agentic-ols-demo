#!/usr/bin/env bash
# Clear the always-firing spoke PrometheusRule while retaining its AgenticRun.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

spoke_oc delete -f "$DIR/prometheusrule.yaml" --ignore-not-found
printf 'deleted DemoCriticalAlert PrometheusRule, retained AgenticRun resources are unchanged\n'
