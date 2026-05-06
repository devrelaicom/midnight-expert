#!/usr/bin/env bash
# Stop.sh blocks (exit 2) when a .compact file has changed since the
# SessionStart snapshot AND no `compact compile` invocation naming it
# appears in the transcript after the file's mtime.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT=$(mk_project_root)
trap 'rm -rf "$ROOT"' EXIT

write_compact "$ROOT" "a.compact" "contract a v1"

# Take SessionStart baseline.
PAYLOAD=$(jq -cn --arg cwd "$ROOT" '{cwd: $cwd}')
run_hook "SessionStart-compact-check.sh" "$PAYLOAD" _ _ _

# Modify the contract so its hash diverges from the snapshot.
write_compact "$ROOT" "a.compact" "contract a v2 -- modified"

# Pre-set cooldown state to one-below-trigger so a single Stop call fires.
SETTINGS=$(settings_path "$ROOT")
jq '.compact_compilation_check_hook.triggers_since_last_block = 4
    | .compact_compilation_check_hook.last_block_timestamp = null' \
   "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"

TRANSCRIPT="$ROOT/transcript.jsonl"
transcript_no_compile "$TRANSCRIPT"

PAYLOAD=$(jq -cn --arg cwd "$ROOT" --arg t "$TRANSCRIPT" \
  '{cwd: $cwd, transcript_path: $t, stop_hook_active: false}')
run_hook "Stop.sh" "$PAYLOAD" OUT ERR RC

chk_eq        "Stop exits 2"                     "2" "$RC"
chk_contains  "block reason names a.compact"     "$ERR" "a.compact"
chk_contains  "block reason mentions compile"    "$ERR" "compact compile"
chk_jq        "triggers reset to 0 after block"  "$SETTINGS" \
  '.compact_compilation_check_hook.triggers_since_last_block' "0"
chk_jq        "last_block_timestamp recorded"    "$SETTINGS" \
  '.compact_compilation_check_hook.last_block_timestamp | type' "string"

summary
