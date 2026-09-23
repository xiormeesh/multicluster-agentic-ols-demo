#!/usr/bin/env bash
# Static checks for the PrometheusRule-driven demo stage.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE="${ROOT}/manifests/07-demo-incident"

for file in prometheusrule.yaml trigger.sh check.sh resolve.sh uninstall.sh; do
  [[ -f "${STAGE}/${file}" ]]
done
for script in trigger.sh check.sh resolve.sh uninstall.sh; do
  [[ -x "${STAGE}/${script}" ]]
done
grep -Fq 'kind: PrometheusRule' "${STAGE}/prometheusrule.yaml"
grep -Fq 'expr: vector(1)' "${STAGE}/prometheusrule.yaml"
grep -Fq 'alert: DemoCriticalAlert' "${STAGE}/prometheusrule.yaml"
grep -Fq 'severity: critical' "${STAGE}/prometheusrule.yaml"
grep -Fq 'alert-name=democriticalalert' "${STAGE}/check.sh"
grep -Fq 'targetCluster' "${STAGE}/check.sh"
grep -Fq 'approve execution in the console' "${STAGE}/check.sh"
grep -Fq 'delete -f' "${STAGE}/resolve.sh"

printf 'demo incident stage checks passed\n'
