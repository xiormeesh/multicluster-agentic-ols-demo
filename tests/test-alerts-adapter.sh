#!/usr/bin/env bash
# Validate AAA configuration stage files without contacting a cluster.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE="${ROOT}/manifests/05-alerts-adapter"

bash -n "${STAGE}/install.sh"
bash -n "${STAGE}/uninstall.sh"
grep -Fq 'allowedReceivers:' "${STAGE}/config.yaml"
grep -Fq -- '- critical' "${STAGE}/config.yaml"
grep -Fq 'pollInterval: "45s"' "${STAGE}/config.yaml"
grep -Fq 'preRunDelay: "10s"' "${STAGE}/config.yaml"
grep -Fq 'postRunDelay: "2h"' "${STAGE}/config.yaml"
grep -Fq 'server-side' "${STAGE}/install.sh"
grep -Fq 'failed to get alerts' "${STAGE}/install.sh"
grep -Fq 'allowedReceivers: []' "${STAGE}/uninstall.sh"

printf 'alerts adapter stage checks passed\n'
