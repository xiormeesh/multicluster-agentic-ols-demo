#!/usr/bin/env bash
# Remove only LLM resources owned by this stage, preserving quickstart policy.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

hub_oc delete "agenticruns.agentic.openshift.io/deploy-test-workload" -n "$NAMESPACE" \
  --ignore-not-found
hub_oc delete deployment/hello-test service/hello-test -n "$NAMESPACE" \
  --ignore-not-found
hub_oc delete agents.agentic.openshift.io/default llmprovider/openai -n "$NAMESPACE" \
  --ignore-not-found
hub_oc delete secret/llm-creds-openai -n "$NAMESPACE" --ignore-not-found
