#!/usr/bin/env bash
# A handoff entry queued by a sibling's SessionEnd BEFORE an exclusion was
# added to .claude/compact-check.json must still be dropped at the next
# SessionStart -- exclusion config is evaluated when read, not when the
# handoff entry was written (the config-add race).

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT=$(mk_project_root)
trap 'rm -rf "$ROOT"' EXIT

write_compact "$ROOT" "target.compact" "contract target v1"
HASH_TARGET=$(sha256sum "$ROOT/target.compact" | awk '{print $1}')
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# A sibling's SessionEnd queued this handoff entry while target.compact was
# NOT yet excluded -- the entry is well-formed: hash matches, file exists,
# flagged_at is fresh (well within the 72h TTL).
SIB=$(state_path "$ROOT" "sess-old")
mkdir -p "$(dirname "$SIB")"
cat > "$SIB" << JSON
{
  "schema_version": 1, "project_root": "$ROOT", "session_id": "sess-old",
  "created_at": "$NOW", "compact_files": {}, "triggers_since_last_block": 0,
  "last_block_timestamp": null, "flag_events": [], "on_next_user_prompt": [],
  "unchecked_from_previous_session": [
    {"path": "$ROOT/target.compact", "sha256": "$HASH_TARGET", "flagged_at": "$NOW"}
  ]
}
JSON

# The exclusion is added AFTER the handoff entry above was already written.
mkdir -p "$ROOT/.claude"
cat > "$ROOT/.claude/compact-check.json" << JSON
{"exclude": ["target.compact"]}
JSON

NEW_SID="new-sess"
PAYLOAD=$(hook_payload "$ROOT" "$NEW_SID")
run_hook "SessionStart-compact-check.sh" "$PAYLOAD" OUT ERR RC

chk_eq "SessionStart exits 0"                                    "0" "$RC"
chk_eq "no additionalContext emitted (only entry was excluded)"  ""  "$OUT"
chk_jq "sibling handoff list still cleared (consumed either way)" "$SIB" \
  '.unchecked_from_previous_session' "[]"

summary
