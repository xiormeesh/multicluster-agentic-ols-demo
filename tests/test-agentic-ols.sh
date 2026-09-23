#!/usr/bin/env bash
# Validate stage-01 script structure without contacting a cluster.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="${ROOT}/manifests/01-agentic-ols/install.sh"
UNINSTALL="${ROOT}/manifests/01-agentic-ols/uninstall.sh"

bash -n "$INSTALL"
bash -n "$UNINSTALL"

grep -Fq -- '--operator-image=${AGENTIC_OPERATOR_IMAGE}' "$INSTALL"
grep -Fq -- 'args+=(--postgres)' "$INSTALL"
grep -Fq -- 'lightspeed-agentic-alerts-adapter' "$INSTALL"
grep -Fq -- 'scale deployment/lightspeed-agentic-alerts-adapter' "$INSTALL"
grep -Fq -- 'approval-policy.yaml' "$INSTALL"
grep -Fq 'approval: Manual' "${ROOT}/manifests/01-agentic-ols/approval-policy.yaml"
grep -Fq -- 'uninstall.sh" --force' "$UNINSTALL"

if grep -Fq 'NAMESPACE="$NAMESPACE"' "$INSTALL" "$UNINSTALL"; then
  printf 'stage scripts must not reassign readonly NAMESPACE\n' >&2
  exit 1
fi

printf 'agentic OLS stage checks passed\n'
