#!/usr/bin/env bash
# UserPromptSubmit hook (per-session state): with a missing state file, an
# absent queue key, an empty queue, or a compact-not-compiled entry whose
# files are all excluded, emit no stdout and exit 0 without touching state.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT=$(mk_project_root)
trap 'rm -rf "$ROOT"' EXIT

SID="sess-1"
STATE_FILE=$(state_path "$ROOT" "$SID")

# --- Case 1: no session_id at all -- must never block ---
PAYLOAD_NO_SID=$(jq -cn --arg cwd "$ROOT" '{cwd: $cwd}')
run_hook_at "$MIDNIGHT_EXPERT_HOOKS_DIR/UserPromptSubmit.sh" "$PAYLOAD_NO_SID" OUT ERR RC

chk_eq "no session_id: exits 0"  "0" "$RC"
chk_eq "no session_id: no stdout" "" "$OUT"
chk_eq "no session_id: no stderr" "" "$ERR"

PAYLOAD=$(hook_payload "$ROOT" "$SID")

# --- Case 2: state file does not exist at all ---
run_hook_at "$MIDNIGHT_EXPERT_HOOKS_DIR/UserPromptSubmit.sh" "$PAYLOAD" OUT ERR RC

chk_eq "no state file: exits 0"  "0" "$RC"
chk_eq "no state file: no stdout" "" "$OUT"
chk_eq "no state file: no stderr" "" "$ERR"
chk_eq "no state file: still doesn't exist" "no" "$([ -f "$STATE_FILE" ] && echo yes || echo no)"

mkdir -p "$(dirname "$STATE_FILE")"

# --- Case 3: state file exists, queue key absent ---
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
  "unchecked_from_previous_session": []
}
JSON
run_hook_at "$MIDNIGHT_EXPERT_HOOKS_DIR/UserPromptSubmit.sh" "$PAYLOAD" OUT ERR RC

chk_eq "no queue key: exits 0"   "0" "$RC"
chk_eq "no queue key: no stdout" "" "$OUT"

# --- Case 4: state file exists, queue is empty array ---
jq '.on_next_user_prompt = []' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
run_hook_at "$MIDNIGHT_EXPERT_HOOKS_DIR/UserPromptSubmit.sh" "$PAYLOAD" OUT ERR RC

chk_eq "empty queue: exits 0"   "0" "$RC"
chk_eq "empty queue: no stdout" "" "$OUT"

# --- Case 5: compact-not-compiled entry whose only file is excluded -- the
# entry is dropped, no heads-up text emitted, but the queue is still
# drained (it was successfully read). ---
mkdir -p "$ROOT/.claude"
cat > "$ROOT/.claude/compact-check.json" << JSON
{"exclude": ["only.compact"]}
JSON
jq '.on_next_user_prompt = [{"type": "compact-not-compiled", "files": ["'"$ROOT"'/only.compact"]}]' \
  "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
run_hook_at "$MIDNIGHT_EXPERT_HOOKS_DIR/UserPromptSubmit.sh" "$PAYLOAD" OUT ERR RC

chk_eq "all-excluded entry: exits 0"   "0" "$RC"
chk_eq "all-excluded entry: no stdout" "" "$OUT"
chk_jq "all-excluded entry: queue drained" "$STATE_FILE" \
  '.on_next_user_prompt // "absent"' "absent"

summary
