#!/usr/bin/env bash
# Validate stage-02 manifests and scripts without contacting a cluster.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE="${ROOT}/manifests/02-agent-and-llm"

bash -n "${STAGE}/install.sh"
bash -n "${STAGE}/uninstall.sh"
bash -n "${STAGE}/test-hub-run.sh"
bash -n "${STAGE}/check-hub-run.sh"
grep -Fq 'model: gpt-5.6-luna' "${STAGE}/openai.yaml"
grep -Fq 'analysisSeconds: 600' "${STAGE}/openai.yaml"
grep -Fq 'executionSeconds: 600' "${STAGE}/openai.yaml"
grep -Fq 'verificationSeconds: 600' "${STAGE}/openai.yaml"
grep -Fq 'ONLY_OLS_OPENAI_API_KEY is required' "${STAGE}/install.sh"
grep -Fq 'approvalpolicy/cluster' "${STAGE}/install.sh"
grep -Fq "grep -qx 'Manual'" "${STAGE}/install.sh"
grep -Fq 'agents.agentic.openshift.io/default' "${STAGE}/install.sh"
grep -Fq 'deploy-test-workload.yaml' "${STAGE}/test-hub-run.sh"
grep -Fq 'condition=Analyzed=True' "${STAGE}/test-hub-run.sh"
grep -Fq 'approve analysis in the console' "${STAGE}/test-hub-run.sh"
grep -Fq 'condition=Executed=True' "${STAGE}/check-hub-run.sh"
grep -Fq 'deploy-test-workload' "${STAGE}/uninstall.sh"

printf 'agent and LLM stage checks passed\n'
