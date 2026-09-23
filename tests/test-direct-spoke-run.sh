#!/usr/bin/env bash
# Validate direct target-spoke smoke-test files without contacting a cluster.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE="${ROOT}/manifests/04-spoke-registration"

for script in "${STAGE}"/*.sh; do
  bash -n "$script"
done

grep -Fq 'targetCluster: spoke' "${STAGE}/direct-spoke-run.yaml"
grep -Fq 'multicluster-proof' "${STAGE}/direct-spoke-run.yaml"
grep -Fq 'condition=Analyzed=True' "${STAGE}/test-spoke-run.sh"
grep -Fq 'approve analysis in the console' "${STAGE}/test-spoke-run.sh"
grep -Fq 'condition=Executed=True' "${STAGE}/check-spoke-run.sh"
grep -Fq 'direct-spoke-smoke' "${STAGE}/cleanup-spoke-run.sh"

printf 'direct target-spoke stage checks passed\n'
