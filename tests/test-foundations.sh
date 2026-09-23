#!/usr/bin/env bash
# Validate the shell-only lifecycle foundation without contacting a cluster.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while IFS= read -r -d '' script; do
  bash -n "$script"
done < <(find "$ROOT" -type f -name '*.sh' -print0)

"$ROOT/setup.sh" --help >/dev/null
"$ROOT/teardown.sh" --help >/dev/null

bash -c '
  source "$1/scripts/common.sh"
  AGENTIC_OPERATOR_IMAGE="quay.io/example/operator@sha256:abc"
  require_digest_image AGENTIC_OPERATOR_IMAGE
' -- "$ROOT"

if bash -c '
  source "$1/scripts/common.sh"
  AGENTIC_OPERATOR_IMAGE="quay.io/example/operator:latest"
  require_digest_image AGENTIC_OPERATOR_IMAGE
' -- "$ROOT" >/dev/null 2>&1; then
  printf "expected mutable image rejection\n" >&2
  exit 1
fi

if command -v shellcheck >/dev/null 2>&1; then
  find "$ROOT" -type f -name '*.sh' -print0 | xargs -0 shellcheck
fi

printf 'foundation checks passed\n'
