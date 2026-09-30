#!/usr/bin/env bash
# Shared helpers for the multicluster Agentic OLS demo lifecycle.
set -euo pipefail

DEMO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-${DEMO_ROOT}/.env}"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

require_file() {
  [[ -f "$1" ]] || fail "required file not found: $1"
}

load_demo_config() {
  require_file "$ENV_FILE"

  # shellcheck disable=SC1090
  source "$ENV_FILE"

  readonly NAMESPACE="openshift-lightspeed"
  readonly SPOKE_NAME="spoke"
  IMAGE_LOCK_FILE="${IMAGE_LOCK_FILE:-.demo/image-lock.env}"
  if [[ "$IMAGE_LOCK_FILE" != /* ]]; then
    IMAGE_LOCK_FILE="${DEMO_ROOT}/${IMAGE_LOCK_FILE}"
  fi

  if [[ -f "$IMAGE_LOCK_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$IMAGE_LOCK_FILE"
  fi
}

require_cluster_config() {
  : "${HUB_KUBECONFIG:?HUB_KUBECONFIG is required}"
  : "${SPOKE_KUBECONFIG:?SPOKE_KUBECONFIG is required}"
  require_file "$HUB_KUBECONFIG"
  require_file "$SPOKE_KUBECONFIG"
  require_command oc
}

require_digest_image() {
  local image_name="$1"
  local image_ref="${!image_name:-}"

  [[ "$image_ref" == *@sha256:* ]] || \
    fail "$image_name must be an immutable digest reference"
}

hub_oc() {
  KUBECONFIG="$HUB_KUBECONFIG" oc "$@"
}

spoke_oc() {
  KUBECONFIG="$SPOKE_KUBECONFIG" oc "$@"
}

# --ignore-not-found handles absence only; authentication/API failures still abort.
hub_exists() {
  local found
  found="$(hub_oc get "$@" --ignore-not-found -o name)" || fail "hub resource lookup failed: $*"
  [[ -n "$found" ]]
}

spoke_exists() {
  local found
  found="$(spoke_oc get "$@" --ignore-not-found -o name)" || fail "spoke resource lookup failed: $*"
  [[ -n "$found" ]]
}

# Last resort for a confirmed disposable namespace wipe. Reject changed UIDs
# and unknown finalizers rather than bypassing another controller's cleanup.
clear_hub_finalizers() {
  local resource="$1"
  local allowed="$2"
  shift 2
  local uid finalizers patch
  hub_exists "$resource" "$@" || return 0
  uid="$(hub_oc get "$resource" "$@" -o jsonpath='{.metadata.uid}')" || fail "cannot read UID for $resource"
  finalizers="$(hub_oc get "$resource" "$@" -o jsonpath='{.metadata.finalizers}')" || fail "cannot read finalizers for $resource"
  require_command python3
  patch="$(python3 -c '
import json, sys
uid, raw, allowed = sys.argv[1:]
finalizers = json.loads(raw)
if not finalizers or not set(finalizers).issubset(set(allowed.split(","))):
    sys.exit("unexpected finalizers, refusing forced cleanup: " + raw)
print(json.dumps([
    {"op": "test", "path": "/metadata/uid", "value": uid},
    {"op": "test", "path": "/metadata/finalizers", "value": finalizers},
    {"op": "remove", "path": "/metadata/finalizers"},
]))
' "$uid" "$finalizers" "$allowed")" || fail "unsafe finalizers on $resource"
  printf 'WARNING: bypassing known cleanup finalizers on %s; spoke-side artifacts may remain\n' "$resource" >&2
  hub_oc patch "$resource" "$@" --type=json -p "$patch"
}

wait_for_deployment() {
  local cluster="$1"
  local deployment="$2"
  local namespace="$3"
  local timeout="$4"

  case "$cluster" in
    hub) hub_oc rollout status "deployment/${deployment}" -n "$namespace" \
      --timeout="$timeout" ;;
    spoke) spoke_oc rollout status "deployment/${deployment}" -n "$namespace" \
      --timeout="$timeout" ;;
    *) fail "unknown cluster: $cluster" ;;
  esac
}

wait_for_condition() {
  local resource="$1"
  local condition="$2"
  local timeout="$3"

  hub_oc wait --for="condition=${condition}" "$resource" --timeout="$timeout"
}

run_stage() {
  local stage="$1"
  local action="$2"
  local script="${DEMO_ROOT}/manifests/${stage}/${action}.sh"

  [[ -x "$script" ]] || fail "stage ${stage} does not provide ${action}.sh yet"
  "$script"
}
