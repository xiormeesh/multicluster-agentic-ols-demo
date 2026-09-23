#!/usr/bin/env bash
# Configure the OpenAI provider and default Agent on the hub.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config
: "${ONLY_OLS_OPENAI_API_KEY:?ONLY_OLS_OPENAI_API_KEY is required}"

hub_oc create secret generic llm-creds-openai -n "$NAMESPACE" \
  --from-literal="OPENAI_API_KEY=${ONLY_OLS_OPENAI_API_KEY}" \
  --dry-run=client -o yaml | hub_oc apply -f -
hub_oc apply -f "$DIR/openai.yaml"

hub_oc get llmprovider/openai -n "$NAMESPACE" >/dev/null
hub_oc get agents.agentic.openshift.io/default -n "$NAMESPACE" >/dev/null
hub_oc get approvalpolicy/cluster >/dev/null
hub_oc get agents.agentic.openshift.io/default -n "$NAMESPACE" \
  -o jsonpath='{.spec.timeouts.analysisSeconds}' | grep -qx '300'
hub_oc get approvalpolicy/cluster \
  -o jsonpath='{.spec.stages[?(@.name=="Analysis")].approval}' | grep -qx 'Automatic'
hub_oc get approvalpolicy/cluster \
  -o jsonpath='{.spec.stages[?(@.name=="Execution")].approval}' | grep -qx 'Manual'
printf 'OpenAI provider and default Agent are ready\n'
