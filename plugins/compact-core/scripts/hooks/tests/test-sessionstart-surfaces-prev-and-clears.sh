#!/usr/bin/env bash
# SessionStart-compact-check.sh collects unchecked_from_previous_session
# entries from SIBLING session state files (not its own), runs them through
# the handoff pipeline (exclusion filter -> existence -> hash match ->
# newest-wins dedupe by path -> 72h TTL), surfaces survivors as
# additionalContext (paths only), and atomically clears every sibling file
# that contributed an entry -- whether that entry survived or was dropped.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT=$(mk_project_root)
trap 'rm -rf "$ROOT"' EXIT

write_compact "$ROOT" "survive.compact" "contract survive v1"
write_compact "$ROOT" "excluded.compact" "contract excluded v1"
write_compact "$ROOT" "stale.compact" "contract stale v1"
write_compact "$ROOT" "expired.compact" "contract expired v1"
write_compact "$ROOT" "dedupe.compact" "contract dedupe v1"
# deleted.compact is referenced by a handoff entry but never created on disk.

mkdir -p "$ROOT/.claude"
cat > "$ROOT/.claude/compact-check.json" << JSON
{"exclude": ["excluded.compact"]}
JSON

HASH_SURVIVE=$(sha256sum "$ROOT/survive.compact" | awk '{print $1}')
HASH_EXCLUDED=$(sha256sum "$ROOT/excluded.compact" | awk '{print $1}')
HASH_EXPIRED=$(sha256sum "$ROOT/expired.compact" | awk '{print $1}')
HASH_DEDUPE=$(sha256sum "$ROOT/dedupe.compact" | awk '{print $1}')

NOW_ISO=$(date -u "+%Y-%m-%dT%H:%M:%SZ")
ONE_HOUR_AGO=$(date -u -d "1 hour ago" "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
            || date -u -v-1H "+%Y-%m-%dT%H:%M:%SZ")
SEVENTY_THREE_HOURS_AGO=$(date -u -d "73 hours ago" "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
                       || date -u -v-73H "+%Y-%m-%dT%H:%M:%SZ")

SIB1=$(state_path "$ROOT" "sess-old-1")
mkdir -p "$(dirname "$SIB1")"
cat > "$SIB1" << JSON
{
  "schema_version": 1,
  "project_root": "$ROOT",
  "session_id": "sess-old-1",
  "created_at": "$ONE_HOUR_AGO",
  "compact_files": {},
  "triggers_since_last_block": 0,
  "last_block_timestamp": null,
  "flag_events": [],
  "on_next_user_prompt": [],
  "unchecked_from_previous_session": [
    {"path": "$ROOT/survive.compact", "sha256": "$HASH_SURVIVE", "flagged_at": "$NOW_ISO"},
    {"path": "$ROOT/excluded.compact", "sha256": "$HASH_EXCLUDED", "flagged_at": "$NOW_ISO"},
    {"path": "$ROOT/stale.compact", "sha256": "0000000000000000000000000000000000000000000000000000000000000000", "flagged_at": "$NOW_ISO"},
    {"path": "$ROOT/deleted.compact", "sha256": "1111111111111111111111111111111111111111111111111111111111111111", "flagged_at": "$NOW_ISO"},
    {"path": "$ROOT/dedupe.compact", "sha256": "$HASH_DEDUPE", "flagged_at": "$ONE_HOUR_AGO"}
  ]
}
JSON

SIB2=$(state_path "$ROOT" "sess-old-2")
mkdir -p "$(dirname "$SIB2")"
cat > "$SIB2" << JSON
{
  "schema_version": 1,
  "project_root": "$ROOT",
  "session_id": "sess-old-2",
  "created_at": "$SEVENTY_THREE_HOURS_AGO",
  "compact_files": {},
  "triggers_since_last_block": 0,
  "last_block_timestamp": null,
  "flag_events": [],
  "on_next_user_prompt": [],
  "unchecked_from_previous_session": [
    {"path": "$ROOT/expired.compact", "sha256": "$HASH_EXPIRED", "flagged_at": "$SEVENTY_THREE_HOURS_AGO"},
    {"path": "$ROOT/dedupe.compact", "sha256": "$HASH_DEDUPE", "flagged_at": "$NOW_ISO"}
  ]
}
JSON

# A sibling with an empty list should be left completely untouched.
SIB3=$(state_path "$ROOT" "sess-old-3")
mkdir -p "$(dirname "$SIB3")"
cat > "$SIB3" << JSON
{
  "schema_version": 1,
  "project_root": "$ROOT",
  "session_id": "sess-old-3",
  "created_at": "$NOW_ISO",
  "compact_files": {},
  "triggers_since_last_block": 3,
  "last_block_timestamp": null,
  "flag_events": [],
  "on_next_user_prompt": [],
  "unchecked_from_previous_session": []
}
JSON

NEW_SID="new-sess"
PAYLOAD=$(hook_payload "$ROOT" "$NEW_SID")
run_hook "SessionStart-compact-check.sh" "$PAYLOAD" OUT ERR RC

chk_eq        "SessionStart exits 0"                        "0" "$RC"
chk_contains  "additionalContext names survive.compact"     "$OUT" "$ROOT/survive.compact"
chk_contains  "additionalContext names dedupe.compact"      "$OUT" "$ROOT/dedupe.compact"

for f in excluded.compact stale.compact expired.compact deleted.compact; do
  chk_eq "additionalContext omits $f" "0" \
    "$(printf '%s' "$OUT" | grep -cF "$ROOT/$f" || true)"
done

# dedupe.compact should appear exactly once (newest-wins), not twice.
chk_eq "dedupe.compact appears exactly once" "1" \
  "$(printf '%s' "$OUT" | grep -cF "$ROOT/dedupe.compact")"

chk_jq "sibling 1 handoff list cleared" "$SIB1" '.unchecked_from_previous_session' "[]"
chk_jq "sibling 2 handoff list cleared" "$SIB2" '.unchecked_from_previous_session' "[]"
chk_jq "sibling 3 (already empty) untouched trigger count" "$SIB3" '.triggers_since_last_block' "3"

NEW_STATE=$(state_path "$ROOT" "$NEW_SID")
chk_jq "own state file created" "$NEW_STATE" '.session_id' "$NEW_SID"
chk_jq "own state file compact_files has survive.compact" "$NEW_STATE" \
  ".compact_files | has(\"$ROOT/survive.compact\")" "true"

summary
