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
  IMAGE_LOCK_FILE="${DEMO_ROOT}/${IMAGE_LOCK_FILE}"

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
