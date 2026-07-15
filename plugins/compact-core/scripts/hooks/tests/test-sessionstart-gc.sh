#!/usr/bin/env bash
# SessionStart-compact-check.sh GCs sibling state files older than 7 days
# (by mtime) before doing anything else. A sibling just inside the TTL (6
# days) and a freshly-written sibling both survive.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT=$(mk_project_root)
trap 'rm -rf "$ROOT"' EXIT

NEW_SID="new-sess"
NEW_STATE=$(state_path "$ROOT" "$NEW_SID")
STATE_DIR="$(dirname "$NEW_STATE")"
mkdir -p "$STATE_DIR"

sib_json() {
  local sid="$1"
  jq -n --arg root "$ROOT" --arg sid "$sid" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
    schema_version: 1, project_root: $root, session_id: $sid, created_at: $now,
    compact_files: {}, triggers_since_last_block: 0, last_block_timestamp: null,
    flag_events: [], on_next_user_prompt: [], unchecked_from_previous_session: []
  }'
}

OLD_SIB="$STATE_DIR/old-sess.json"
sib_json "old-sess" > "$OLD_SIB"
touch -d "10 days ago" "$OLD_SIB"

BOUNDARY_SIB="$STATE_DIR/boundary-sess.json"
sib_json "boundary-sess" > "$BOUNDARY_SIB"
touch -d "6 days ago" "$BOUNDARY_SIB"

FRESH_SIB="$STATE_DIR/fresh-sess.json"
sib_json "fresh-sess" > "$FRESH_SIB"
# mtime left at "now" (just written)

PAYLOAD=$(hook_payload "$ROOT" "$NEW_SID")
run_hook "SessionStart-compact-check.sh" "$PAYLOAD" OUT ERR RC

chk_eq "SessionStart exits 0"       "0"   "$RC"
chk_eq "10-day-old sibling deleted" "no"  "$([ -f "$OLD_SIB" ] && echo yes || echo no)"
chk_eq "6-day-old sibling survives" "yes" "$([ -f "$BOUNDARY_SIB" ] && echo yes || echo no)"
chk_eq "fresh sibling survives"     "yes" "$([ -f "$FRESH_SIB" ] && echo yes || echo no)"
chk_eq "own state file created"     "yes" "$([ -f "$NEW_STATE" ] && echo yes || echo no)"

summary
