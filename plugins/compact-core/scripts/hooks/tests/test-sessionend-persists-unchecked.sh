#!/usr/bin/env bash
# SessionEnd.sh runs the same compile-found check as Stop.sh, persists any
# unchecked .compact files as structured {path, sha256, flagged_at} entries
# into its OWN state file's unchecked_from_previous_session, and keeps
# compact_files (GC reaps the file later).

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT=$(mk_project_root)
trap 'rm -rf "$ROOT"' EXIT

write_compact "$ROOT" "a.compact" "contract a v1"
SID="sess-1"
STATE_FILE=$(state_path "$ROOT" "$SID")

PAYLOAD=$(hook_payload "$ROOT" "$SID")
run_hook "SessionStart-compact-check.sh" "$PAYLOAD" _ _ _

write_compact "$ROOT" "a.compact" "contract a v2 -- modified"
EXPECTED_HASH=$(sha256sum "$ROOT/a.compact" | awk '{print $1}')
TRANSCRIPT="$ROOT/transcript.jsonl"
transcript_no_compile "$TRANSCRIPT"

PAYLOAD=$(hook_payload "$ROOT" "$SID" \
  "$(jq -cn --arg t "$TRANSCRIPT" '{transcript_path: $t}')")
run_hook "SessionEnd.sh" "$PAYLOAD" OUT ERR RC

chk_eq "SessionEnd exits 0" "0" "$RC"
chk_jq "unchecked list contains a.compact" "$STATE_FILE" \
  '.unchecked_from_previous_session | length' "1"
chk_jq "unchecked entry path matches" "$STATE_FILE" \
  ".unchecked_from_previous_session[0].path" "$ROOT/a.compact"
chk_jq "unchecked entry sha256 is current hash" "$STATE_FILE" \
  ".unchecked_from_previous_session[0].sha256" "$EXPECTED_HASH"
chk_jq "unchecked entry has flagged_at timestamp" "$STATE_FILE" \
  ".unchecked_from_previous_session[0].flagged_at | type" "string"
chk_jq "compact_files baseline is kept" "$STATE_FILE" \
  '.compact_files | has("'"$ROOT"'/a.compact")' "true"

# --- Clean run: writes [] ---
write_compact "$ROOT" "a.compact" "contract a v2 -- modified"
COMPILE_TS=$(date -u "+%Y-%m-%dT%H:%M:%SZ")
sleep 1
TRANSCRIPT2="$ROOT/transcript2.jsonl"
transcript_with_compile "$TRANSCRIPT2" "$COMPILE_TS" "a.compact"

# Re-baseline so the check is clean against the current file content.
jq --arg h "$EXPECTED_HASH" '.compact_files["'"$ROOT"'/a.compact"] = $h' \
  "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

PAYLOAD2=$(hook_payload "$ROOT" "$SID" \
  "$(jq -cn --arg t "$TRANSCRIPT2" '{transcript_path: $t}')")
run_hook "SessionEnd.sh" "$PAYLOAD2" OUT2 ERR2 RC2

chk_eq "SessionEnd (clean) exits 0" "0" "$RC2"
chk_jq "clean run writes empty list" "$STATE_FILE" \
  '.unchecked_from_previous_session' "[]"

# --- Missing state file: exit 0, no-op ---
MISSING_SID="never-started"
MISSING_PAYLOAD=$(hook_payload "$ROOT" "$MISSING_SID" \
  "$(jq -cn --arg t "$TRANSCRIPT2" '{transcript_path: $t}')")
run_hook "SessionEnd.sh" "$MISSING_PAYLOAD" OUT3 ERR3 RC3
chk_eq "missing state file: exits 0" "0" "$RC3"
chk_eq "missing state file: not created" "no" \
  "$([ -f "$(state_path "$ROOT" "$MISSING_SID")" ] && echo yes || echo no)"

summary
