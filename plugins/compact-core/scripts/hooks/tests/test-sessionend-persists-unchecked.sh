#!/usr/bin/env bash
# SessionEnd.sh runs the same compile-found check as Stop.sh, persists any
# unchecked .compact files into compact_compilation_check_hook.unchecked_from_previous_session,
# and drops the SessionStart hash baseline.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT=$(mk_project_root)
trap 'rm -rf "$ROOT"' EXIT

write_compact "$ROOT" "a.compact" "contract a v1"
PAYLOAD=$(jq -cn --arg cwd "$ROOT" '{cwd: $cwd}')
run_hook "SessionStart-compact-check.sh" "$PAYLOAD" _ _ _

write_compact "$ROOT" "a.compact" "contract a v2 -- modified"
TRANSCRIPT="$ROOT/transcript.jsonl"
transcript_no_compile "$TRANSCRIPT"

PAYLOAD=$(jq -cn --arg cwd "$ROOT" --arg t "$TRANSCRIPT" \
  '{cwd: $cwd, transcript_path: $t}')
run_hook "SessionEnd.sh" "$PAYLOAD" OUT ERR RC

SETTINGS=$(settings_path "$ROOT")

chk_eq "SessionEnd exits 0" "0" "$RC"
chk_jq "unchecked list contains a.compact" "$SETTINGS" \
  '.compact_compilation_check_hook.unchecked_from_previous_session | length' "1"
chk_jq "unchecked list path matches" "$SETTINGS" \
  ".compact_compilation_check_hook.unchecked_from_previous_session[0]" \
  "$ROOT/a.compact"
chk_jq "compact_files baseline removed" "$SETTINGS" \
  '.compact_compilation_check_hook.compact_files // "absent"' "absent"

summary
