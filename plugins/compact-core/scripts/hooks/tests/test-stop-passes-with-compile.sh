#!/usr/bin/env bash
# Stop.sh passes (exit 0) when the modified .compact file has a matching
# `compact compile <fname>` Bash tool_use entry in the transcript dated
# at-or-after the file's mtime.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT=$(mk_project_root)
trap 'rm -rf "$ROOT"' EXIT

write_compact "$ROOT" "a.compact" "contract a v1"
PAYLOAD=$(jq -cn --arg cwd "$ROOT" '{cwd: $cwd}')
run_hook "SessionStart-compact-check.sh" "$PAYLOAD" _ _ _

# Modify, then build a transcript with a compile call timestamped AFTER mtime.
write_compact "$ROOT" "a.compact" "contract a v2"
sleep 1
COMPILE_TS=$(date -u "+%Y-%m-%dT%H:%M:%SZ")

TRANSCRIPT="$ROOT/transcript.jsonl"
transcript_with_compile "$TRANSCRIPT" "$COMPILE_TS" "a.compact"

SETTINGS=$(settings_path "$ROOT")
jq '.compact_compilation_check_hook.triggers_since_last_block = 4
    | .compact_compilation_check_hook.last_block_timestamp = null' \
   "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"

PAYLOAD=$(jq -cn --arg cwd "$ROOT" --arg t "$TRANSCRIPT" \
  '{cwd: $cwd, transcript_path: $t, stop_hook_active: false}')
run_hook "Stop.sh" "$PAYLOAD" OUT ERR RC

chk_eq       "Stop exits 0"            "0" "$RC"
chk_eq       "no block reason emitted" "" "$ERR"

summary
