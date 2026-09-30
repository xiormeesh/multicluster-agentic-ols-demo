#!/usr/bin/env bash
# Remove the Agentic OLS quickstart after dependent demo stages are removed.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

QUICKSTART_DIR="${DEMO_ROOT}/.demo/sources/agentic-operator/hack/quickstart"
require_file "${QUICKSTART_DIR}/uninstall.sh"

# Quickstart suppresses AgenticRun deletion errors. Give controller cleanup a
# bounded chance, then bypass only known finalizers in this confirmed wipe.
if hub_exists crd agenticruns.agentic.openshift.io && \
  hub_exists namespace/"$NAMESPACE"; then
  runs="$(hub_oc get agenticruns.agentic.openshift.io -n "$NAMESPACE" -o name)" || \
    fail 'cannot list AgenticRuns before namespace deletion'
  if [[ -n "$runs" ]]; then
    hub_oc delete agenticruns.agentic.openshift.io --all -n "$NAMESPACE" \
      --wait=false
    printf 'Waiting up to 60s for AgenticRun cleanup before forced fallback...\n' >&2
    for _ in $(seq 1 60); do
      remaining="$(hub_oc get agenticruns.agentic.openshift.io -n "$NAMESPACE" -o name)" || \
        fail 'cannot list deleting AgenticRuns'
      [[ -z "$remaining" ]] && break
      sleep 1
    done
    remaining="$(hub_oc get agenticruns.agentic.openshift.io -n "$NAMESPACE" -o name)" || \
      fail 'cannot list deleting AgenticRuns'
    if [[ -n "$remaining" ]]; then
      while IFS= read -r run; do
        clear_hub_finalizers "$run" \
          'agentic.openshift.io/execution-rbac-cleanup,agentic.openshift.io/templog-cleanup' \
          -n "$NAMESPACE"
      done <<< "$remaining"
    fi
    remaining="$(hub_oc get agenticruns.agentic.openshift.io -n "$NAMESPACE" -o name)" || \
      fail 'cannot verify AgenticRun deletion'
    if [[ -n "$remaining" ]]; then
      while IFS= read -r run; do
        hub_oc wait --for=delete "$run" -n "$NAMESPACE" --timeout=60s || \
          fail "$run remains after known-finalizer cleanup"
      done <<< "$remaining"
    fi
  fi
fi

KUBECONFIG="$HUB_KUBECONFIG" bash "${QUICKSTART_DIR}/uninstall.sh" --force
if hub_exists namespace/"$NAMESPACE"; then
  hub_oc wait --for=delete namespace/"$NAMESPACE" --timeout=120s || \
    fail "namespace/$NAMESPACE is still terminating; inspect remaining finalizers"
fi
if hub_exists crd agenticruns.agentic.openshift.io; then
  fail 'AgenticRun CRD remains after quickstart uninstall'
fi
