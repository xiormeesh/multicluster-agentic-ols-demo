#!/usr/bin/env bash
# Validate hub and spoke stage scripts without contacting either cluster.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HUB_STAGE="${ROOT}/manifests/03-lightspeed-hub"
SPOKE_STAGE="${ROOT}/manifests/04-spoke-registration"

for script in "${HUB_STAGE}"/*.sh "${SPOKE_STAGE}"/*.sh; do
  bash -n "$script"
done

grep -Fq -- '--alerts-adapter-image=${AAA_IMAGE}' "${HUB_STAGE}/hub.yaml"
grep -Fq -- 'HubConfig' "${HUB_STAGE}/hub.yaml"
grep -Fq -- 'export HUB_IMAGE AAA_IMAGE' "${HUB_STAGE}/install.sh"
grep -Fq -- 'lightspeed-hub-alerts-adapter' "${HUB_STAGE}/install.sh"
grep -Fq -- '--multicluster' "${HUB_STAGE}/install.sh"
grep -Fq -- 'spoke-admin-kubeconfig-spoke' "${SPOKE_STAGE}/spokecluster.yaml"
grep -Fq -- 'for condition in Connected Provisioned AdaptersReady Ready' \
  "${SPOKE_STAGE}/install.sh"
grep -Fq -- 'condition=${condition}' "${SPOKE_STAGE}/install.sh"
grep -Fq 'targetCluster: spoke' "${SPOKE_STAGE}/direct-spoke-run.yaml"
grep -Fq 'cleanup-spoke-run.sh' "${SPOKE_STAGE}/uninstall.sh"

printf 'hub and spoke stage checks passed\n'
