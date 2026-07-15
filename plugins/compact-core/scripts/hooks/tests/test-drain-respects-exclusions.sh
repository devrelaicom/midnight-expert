#!/usr/bin/env bash
# A queued compact-not-compiled entry's files are re-filtered through the
# CURRENT exclusion config at drain time (UserPromptSubmit), not the config
# that existed when Stop.sh queued the entry -- the second exclusion race.
# A file excluded after queueing is silently dropped from the surfaced
# message while an unexcluded sibling file in the SAME entry still surfaces,
# and the queue still drains either way.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT=$(mk_project_root)
trap 'rm -rf "$ROOT"' EXIT

SID="sess-1"
STATE_FILE=$(state_path "$ROOT" "$SID")
mkdir -p "$(dirname "$STATE_FILE")"
cat > "$STATE_FILE" << JSON
{
  "schema_version": 1, "project_root": "$ROOT", "session_id": "$SID",
  "created_at": "2026-07-15T00:00:00Z", "compact_files": {},
  "triggers_since_last_block": 0, "last_block_timestamp": null, "flag_events": [],
  "on_next_user_prompt": [
    { "type": "compact-not-compiled", "files": ["$ROOT/a.compact", "$ROOT/b.compact"] }
  ],
  "unchecked_from_previous_session": []
}
JSON

# a.compact and b.compact were both unexcluded when Stop.sh queued this
# entry. b.compact is excluded AFTER the fact, before the drain runs.
mkdir -p "$ROOT/.claude"
cat > "$ROOT/.claude/compact-check.json" << JSON
{"exclude": ["b.compact"]}
JSON

PAYLOAD=$(hook_payload "$ROOT" "$SID")
run_hook_at "$MIDNIGHT_EXPERT_HOOKS_DIR/UserPromptSubmit.sh" "$PAYLOAD" OUT ERR RC

chk_eq       "UserPromptSubmit exits 0"   "0" "$RC"
chk_eq       "UserPromptSubmit no stderr" "" "$ERR"
chk_contains "stdout surfaces a.compact (still unexcluded)" "$OUT" "$ROOT/a.compact"
chk_eq "stdout omits b.compact (excluded after queueing)" "0" \
  "$(printf '%s' "$OUT" | grep -cF "$ROOT/b.compact" || true)"
chk_contains "stdout has heads-up heading" "$OUT" "Heads up"
chk_jq       "queue still drained" "$STATE_FILE" \
  '.on_next_user_prompt // "absent"' "absent"

summary
