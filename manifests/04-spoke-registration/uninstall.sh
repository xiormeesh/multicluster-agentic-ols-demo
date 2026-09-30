#!/usr/bin/env bash
# Remove the spoke while the hub controller is still available for finalizers.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
require_cluster_config

"$DIR/cleanup-spoke-run.sh"
if hub_exists crd spokeclusters.hub.openshift.io; then
  hub_oc delete "spokecluster/${SPOKE_NAME}" --ignore-not-found --wait=false
  if hub_exists "spokecluster/${SPOKE_NAME}"; then
    printf 'Waiting up to 60s for spoke registration cleanup before forced fallback...\n' >&2
    for _ in $(seq 1 60); do
      hub_exists "spokecluster/${SPOKE_NAME}" || break
      sleep 1
    done
    if hub_exists "spokecluster/${SPOKE_NAME}"; then
      clear_hub_finalizers "spokecluster/${SPOKE_NAME}" 'hub.openshift.io/spoke-cleanup'
    fi
    if hub_exists "spokecluster/${SPOKE_NAME}"; then
      hub_oc wait --for=delete "spokecluster/${SPOKE_NAME}" --timeout=60s || \
        fail "spokecluster/${SPOKE_NAME} remains after known-finalizer cleanup"
    fi
  fi
fi
hub_oc delete "secret/spoke-admin-kubeconfig-${SPOKE_NAME}" -n "$NAMESPACE" \
  --ignore-not-found

# Bypassing the hub finalizer can leave managed spoke resources behind. Delete
# only hub-managed bindings; fail rather than deleting an unrelated binding.
for name in lightspeed-hub:cluster-reader lightspeed-hub:cluster-monitoring-view; do
  if spoke_exists "clusterrolebinding/${name}"; then
    subject="$(spoke_oc get "clusterrolebinding/${name}" \
      -o jsonpath='{.subjects[0].name} {.subjects[0].namespace}')" || fail "cannot inspect binding $name"
    [[ "$subject" == 'lightspeed-agent openshift-lightspeed-managed' ]] || \
      fail "unexpected subject on $name: $subject"
    spoke_oc delete "clusterrolebinding/${name}"
  fi
done
# Per-run reader bindings are cluster-scoped and survive namespace deletion.
bindings="$(spoke_oc get clusterrolebindings -l agentic.openshift.io/run -o name)" || \
  fail 'cannot list run-owned spoke bindings'
if [[ -n "$bindings" ]]; then
  while IFS= read -r binding; do
    [[ "$binding" == clusterrolebinding.rbac.authorization.k8s.io/ls-reader-* ]] || \
      fail "unexpected run binding: $binding"
    subject_ns="$(spoke_oc get "$binding" -o jsonpath='{.subjects[0].namespace}')" || \
      fail "cannot inspect $binding"
    [[ "$subject_ns" == openshift-lightspeed-managed ]] || \
      fail "unexpected subject namespace on $binding: $subject_ns"
    spoke_oc delete "$binding" --ignore-not-found
  done <<< "$bindings"
fi
spoke_oc delete namespace/openshift-lightspeed-managed --ignore-not-found --wait=false
if spoke_exists namespace/openshift-lightspeed-managed; then
  spoke_oc wait --for=delete namespace/openshift-lightspeed-managed --timeout=120s || \
    fail 'spoke managed namespace is still terminating; inspect its finalizers'
fi
