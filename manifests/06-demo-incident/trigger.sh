#!/usr/bin/env bash
# Create the always-firing PrometheusRule on the spoke for the live demo.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

spoke_oc apply -f "$DIR/prometheusrule.yaml"
printf 'created DemoCriticalAlert on the spoke, wait for the hub run with %s/check.sh\n' \
  "$DIR"
