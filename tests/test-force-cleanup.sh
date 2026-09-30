#!/usr/bin/env bash
# Validate last-resort finalizer guards without contacting a cluster.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

run_case() {
  bash -c '
    source "$1/scripts/common.sh"
    hub_exists() { return 0; }
    hub_oc() {
      case "$1" in
        get)
          case "$*" in
            *metadata.uid*) printf "run-uid-123" ;;
            *metadata.finalizers*) printf "%s" "$MOCK_FINALIZERS" ;;
          esac ;;
        patch) printf "%s\n" "$*" >> "$MOCK_PATCH_LOG" ;;
        *) exit 8 ;;
      esac
    }
    clear_hub_finalizers agenticruns.agentic.openshift.io/example \
      "agentic.openshift.io/execution-rbac-cleanup,agentic.openshift.io/templog-cleanup" \
      -n openshift-lightspeed
  ' -- "$ROOT"
}

export MOCK_PATCH_LOG="$tmp/patches"
export MOCK_FINALIZERS='["agentic.openshift.io/execution-rbac-cleanup","agentic.openshift.io/templog-cleanup"]'
run_case >/dev/null
python3 - "$tmp/patches" <<'PY'
import json
import pathlib
import sys

patch = pathlib.Path(sys.argv[1]).read_text().split(' -p ', 1)[1].strip()
ops = json.loads(patch)
assert ops[0] == {'op': 'test', 'path': '/metadata/uid', 'value': 'run-uid-123'}
assert ops[1]['value'] == [
    'agentic.openshift.io/execution-rbac-cleanup',
    'agentic.openshift.io/templog-cleanup',
]
assert ops[2] == {'op': 'remove', 'path': '/metadata/finalizers'}
PY

export MOCK_PATCH_LOG="$tmp/rejected"
export MOCK_FINALIZERS='["unrelated.io/cleanup"]'
if run_case >/dev/null 2>&1; then
  printf 'expected unknown finalizers to fail closed\n' >&2
  exit 1
fi
[[ ! -e "$MOCK_PATCH_LOG" ]]
printf 'force cleanup guard checks passed\n'
