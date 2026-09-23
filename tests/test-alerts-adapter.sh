#!/usr/bin/env bash
# Validate AAA configuration stage files without contacting a cluster.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE="${ROOT}/manifests/05-alerts-adapter"

bash -n "${STAGE}/install.sh"
bash -n "${STAGE}/uninstall.sh"
grep -Fq 'allowedReceivers:' "${STAGE}/config.yaml"
grep -Fq -- '- critical' "${STAGE}/config.yaml"
grep -Fq 'SPOKE_ROUTER_IP:-' "${STAGE}/install.sh"
grep -Fq 'using normal pod DNS' "${STAGE}/install.sh"
grep -Fq -- '- critical' "${STAGE}/install.sh"
grep -Fq 'hostAliases' "${STAGE}/install.sh"
grep -Fq 'failed to get alerts' "${STAGE}/install.sh"
grep -Fq 'allowedReceivers: []' "${STAGE}/uninstall.sh"

printf 'alerts adapter stage checks passed\n'
