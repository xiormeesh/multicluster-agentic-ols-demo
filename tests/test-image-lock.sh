#!/usr/bin/env bash
# Validate image-lock loading and immutable controller image enforcement.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_env="$(mktemp)"
tmp_lock="$(mktemp)"
trap 'rm -f "$tmp_env" "$tmp_lock"' EXIT

printf 'HUB_KUBECONFIG=/tmp/hub-kubeconfig\nSPOKE_KUBECONFIG=/tmp/spoke-kubeconfig\nIMAGE_LOCK_FILE=%s\n' \
  "$tmp_lock" > "$tmp_env"
printf '%s\n' \
  'AGENTIC_OPERATOR_IMAGE="quay.io/kgordeev/lightspeed-agentic-operator@sha256:agentic"' \
  'HUB_IMAGE="quay.io/kgordeev/lightspeed-hub-operator@sha256:hub"' \
  'AAA_IMAGE="quay.io/kgordeev/lightspeed-agentic-alerts-adapter@sha256:adapter"' \
  > "$tmp_lock"

ENV_FILE="$tmp_env" bash -c '
  source "$1/scripts/common.sh"
  load_demo_config
  require_digest_image AGENTIC_OPERATOR_IMAGE
  require_digest_image HUB_IMAGE
  require_digest_image AAA_IMAGE
' -- "$ROOT"

printf 'image lock checks passed\n'
