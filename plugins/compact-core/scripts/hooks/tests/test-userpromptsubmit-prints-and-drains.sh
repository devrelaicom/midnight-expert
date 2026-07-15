#!/usr/bin/env bash
# midnight-expert UserPromptSubmit hook (per-session state): format queued
# entries to stdout, exclusion-filter each compact-not-compiled entry's
# files (dropping entries left empty), and drain ONLY the own session's
# state file's on_next_user_prompt queue -- a sibling session's queue must
# be left untouched.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT=$(mk_project_root)
trap 'rm -rf "$ROOT"' EXIT

mkdir -p "$ROOT/.claude"
cat > "$ROOT/.claude/compact-check.json" << JSON
{"exclude": ["sub/excluded.compact"]}
JSON

SID="sess-1"
STATE_FILE=$(state_path "$ROOT" "$SID")
mkdir -p "$(dirname "$STATE_FILE")"
cat > "$STATE_FILE" << JSON
{
  "schema_version": 1,
  "project_root": "$ROOT",
  "session_id": "$SID",
  "created_at": "2026-07-15T00:00:00Z",
  "compact_files": {},
  "triggers_since_last_block": 0,
  "last_block_timestamp": null,
  "flag_events": [],
  "on_next_user_prompt": [
    {
      "type": "compact-not-compiled",
      "files": ["$ROOT/a.compact", "$ROOT/sub/b.compact", "$ROOT/sub/excluded.compact"]
    },
    {
      "type": "unknown-future-type",
      "payload": "should be silently dropped from the message"
    }
  ],
  "unchecked_from_previous_session": []
}
JSON

# A sibling session's queue must survive untouched -- only the OWN session's
# state file is drained.
SIB_SID="sess-2"
SIB_STATE_FILE=$(state_path "$ROOT" "$SIB_SID")
mkdir -p "$(dirname "$SIB_STATE_FILE")"
cat > "$SIB_STATE_FILE" << JSON
{
  "schema_version": 1,
  "project_root": "$ROOT",
  "session_id": "$SIB_SID",
  "created_at": "2026-07-15T00:00:00Z",
  "compact_files": {},
  "triggers_since_last_block": 0,
  "last_block_timestamp": null,
  "flag_events": [],
  "on_next_user_prompt": [
    {
      "type": "compact-not-compiled",
      "files": ["$ROOT/sibling-only.compact"]
    }
  ],
  "unchecked_from_previous_session": []
}
JSON

PAYLOAD=$(hook_payload "$ROOT" "$SID")
run_hook_at "$MIDNIGHT_EXPERT_HOOKS_DIR/UserPromptSubmit.sh" "$PAYLOAD" OUT ERR RC

chk_eq        "UserPromptSubmit exits 0" "0" "$RC"
chk_eq        "UserPromptSubmit no stderr" "" "$ERR"
chk_contains  "stdout names a.compact"       "$OUT" "$ROOT/a.compact"
chk_contains  "stdout names sub/b.compact"   "$OUT" "$ROOT/sub/b.compact"
chk_eq        "stdout omits excluded file" "0" \
  "$(printf '%s' "$OUT" | grep -cF "$ROOT/sub/excluded.compact" || true)"
chk_eq        "stdout omits sibling-only file" "0" \
  "$(printf '%s' "$OUT" | grep -cF "$ROOT/sibling-only.compact" || true)"
chk_contains  "stdout has heads-up heading"  "$OUT" "Heads up"
chk_jq        "own queue drained"                 "$STATE_FILE" \
  '.on_next_user_prompt // "absent"' "absent"
chk_jq        "sibling queue untouched"           "$SIB_STATE_FILE" \
  '.on_next_user_prompt | length' "1"

summary
