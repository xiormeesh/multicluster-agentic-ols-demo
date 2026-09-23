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

KUBECONFIG="$HUB_KUBECONFIG" bash "${QUICKSTART_DIR}/uninstall.sh" --force
