#!/usr/bin/env bash
# Handoff pipeline staleness rules exercised in isolation from exclusion and
# malformed-entry concerns (covered separately by
# test-sessionstart-surfaces-prev-and-clears.sh and
# test-handoff-respects-exclusions.sh): an entry naming a file that no
# longer exists is dropped; an entry whose recorded sha256 no longer matches
# the file's current content is dropped; when two siblings hand off the same
# path, only the entry with the newest flagged_at survives; entries are
# dropped once flagged_at crosses the 72h TTL (boundary-tested to the
# minute); a surviving entry is surfaced in additionalContext; every
# consumed sibling ends with an empty handoff list.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT=$(mk_project_root)
trap 'rm -rf "$ROOT"' EXIT

ago() {
  local n="$1" unit="$2"
  date -u -d "$n $unit ago" "+%Y-%m-%dT%H:%M:%SZ"
}

write_compact "$ROOT" "survive.compact" "contract survive v1"
write_compact "$ROOT" "changed.compact" "contract changed v1 -- original"
write_compact "$ROOT" "dup.compact" "contract dup v1"
write_compact "$ROOT" "within-ttl.compact" "contract within v1"
write_compact "$ROOT" "expired.compact" "contract expired v1"
# deleted.compact is referenced by a handoff entry but never created on disk.

HASH_SURVIVE=$(sha256sum "$ROOT/survive.compact" | awk '{print $1}')
HASH_CHANGED_ORIGINAL=$(sha256sum "$ROOT/changed.compact" | awk '{print $1}')
HASH_DUP=$(sha256sum "$ROOT/dup.compact" | awk '{print $1}')
HASH_WITHIN=$(sha256sum "$ROOT/within-ttl.compact" | awk '{print $1}')
HASH_EXPIRED=$(sha256sum "$ROOT/expired.compact" | awk '{print $1}')

# Content diverges from the handoff's recorded hash AFTER the handoff was
# written -- this entry must be dropped as stale-hash, not stale-TTL.
write_compact "$ROOT" "changed.compact" "contract changed v2 -- diverged"

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ONE_HOUR_AGO=$(ago 1 hours)
JUST_WITHIN_TTL=$(ago 4319 minutes)   # 71h59m ago: < 72h -- survives
JUST_OUTSIDE_TTL=$(ago 4321 minutes)  # 72h01m ago: > 72h -- dropped

SIB1=$(state_path "$ROOT" "sess-old-1")
mkdir -p "$(dirname "$SIB1")"
cat > "$SIB1" << JSON
{
  "schema_version": 1, "project_root": "$ROOT", "session_id": "sess-old-1",
  "created_at": "$NOW", "compact_files": {}, "triggers_since_last_block": 0,
  "last_block_timestamp": null, "flag_events": [], "on_next_user_prompt": [],
  "unchecked_from_previous_session": [
    {"path": "$ROOT/survive.compact", "sha256": "$HASH_SURVIVE", "flagged_at": "$NOW"},
    {"path": "$ROOT/deleted.compact", "sha256": "1111111111111111111111111111111111111111111111111111111111111111", "flagged_at": "$NOW"},
    {"path": "$ROOT/changed.compact", "sha256": "$HASH_CHANGED_ORIGINAL", "flagged_at": "$NOW"},
    {"path": "$ROOT/dup.compact", "sha256": "$HASH_DUP", "flagged_at": "$ONE_HOUR_AGO"}
  ]
}
JSON

SIB2=$(state_path "$ROOT" "sess-old-2")
mkdir -p "$(dirname "$SIB2")"
cat > "$SIB2" << JSON
{
  "schema_version": 1, "project_root": "$ROOT", "session_id": "sess-old-2",
  "created_at": "$NOW", "compact_files": {}, "triggers_since_last_block": 0,
  "last_block_timestamp": null, "flag_events": [], "on_next_user_prompt": [],
  "unchecked_from_previous_session": [
    {"path": "$ROOT/dup.compact", "sha256": "$HASH_DUP", "flagged_at": "$NOW"},
    {"path": "$ROOT/within-ttl.compact", "sha256": "$HASH_WITHIN", "flagged_at": "$JUST_WITHIN_TTL"},
    {"path": "$ROOT/expired.compact", "sha256": "$HASH_EXPIRED", "flagged_at": "$JUST_OUTSIDE_TTL"}
  ]
}
JSON

NEW_SID="new-sess"
PAYLOAD=$(hook_payload "$ROOT" "$NEW_SID")
run_hook "SessionStart-compact-check.sh" "$PAYLOAD" OUT ERR RC

chk_eq "SessionStart exits 0" "0" "$RC"

chk_contains "additionalContext surfaces survive.compact"    "$OUT" "$ROOT/survive.compact"
chk_contains "additionalContext surfaces dup.compact"        "$OUT" "$ROOT/dup.compact"
chk_contains "additionalContext surfaces within-ttl.compact" "$OUT" "$ROOT/within-ttl.compact"

for f in deleted.compact changed.compact expired.compact; do
  chk_eq "additionalContext omits $f (dropped)" "0" \
    "$(printf '%s' "$OUT" | grep -cF "$ROOT/$f" || true)"
done

chk_eq "dup.compact (newest-wins dedupe) appears exactly once" "1" \
  "$(printf '%s' "$OUT" | grep -cF "$ROOT/dup.compact")"

chk_jq "sibling 1 handoff list cleared" "$SIB1" '.unchecked_from_previous_session' "[]"
chk_jq "sibling 2 handoff list cleared" "$SIB2" '.unchecked_from_previous_session' "[]"

summary
