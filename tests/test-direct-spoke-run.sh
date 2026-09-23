#!/usr/bin/env bash
# Validate direct target-spoke smoke-test files without contacting a cluster.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE="${ROOT}/manifests/06-manual-agenticruns"

for script in "${STAGE}"/*.sh; do
  bash -n "$script"
done

grep -Fq 'targetCluster: spoke' "${STAGE}/spoke-run.yaml"
grep -Fq 'multicluster-proof' "${STAGE}/spoke-run.yaml"
grep -Fq 'condition=Analyzed=True' "${STAGE}/install.sh"
grep -Fq 'condition=Executed=True' "${STAGE}/check.sh"
grep -Fq 'direct-spoke-smoke' "${STAGE}/uninstall.sh"

printf 'direct target-spoke stage checks passed\n'
