#!/usr/bin/env bash
# Remove the local image lock without deleting remote images or the source cache.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "$DIR/../../scripts/common.sh"

load_demo_config
rm -f "$IMAGE_LOCK_FILE"
printf 'removed local image lock, retained .demo/sources for future builds\n'
