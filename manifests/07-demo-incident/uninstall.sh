#!/usr/bin/env bash
# Clear resources owned by the demo-incident stage.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

"$DIR/resolve.sh"
state_file="${DEMO_ROOT}/.demo/demo-incident.env"
if [[ -f "$state_file" ]]; then
  # shellcheck disable=SC1090
  source "$state_file"
  if [[ -n "${DEMO_INCIDENT_RUN:-}" ]]; then
    hub_oc delete agenticruns.agentic.openshift.io "$DEMO_INCIDENT_RUN" \
      -n "$NAMESPACE" --ignore-not-found
  fi
  unset DEMO_INCIDENT_RUN
  rm -f "$state_file"
fi
printf 'removed demo incident resources\n'
