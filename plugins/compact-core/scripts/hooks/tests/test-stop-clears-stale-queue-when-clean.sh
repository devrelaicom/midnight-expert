#!/usr/bin/env bash
# When the compile-check finds nothing unchecked, Stop.sh removes any stale
# compact-not-compiled queue entry left from a previous turn.

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

# Pre-populate a stale queue entry from a prior turn.
jq '.on_next_user_prompt = [
      { type: "compact-not-compiled", files: ["stale.compact"] },
      { type: "some-other-thing", payload: "keep me" }
    ]' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

# No file modifications => check is clean.
TRANSCRIPT="$ROOT/transcript.jsonl"
transcript_no_compile "$TRANSCRIPT"

PAYLOAD=$(hook_payload "$ROOT" "$SID" \
  "$(jq -cn --arg t "$TRANSCRIPT" '{transcript_path: $t, stop_hook_active: false}')")
run_hook "Stop.sh" "$PAYLOAD" OUT ERR RC

chk_eq "Stop exits 0 when clean" "0" "$RC"
chk_jq "compact-not-compiled entry removed" "$STATE_FILE" \
  '[.on_next_user_prompt[]? | select(.type == "compact-not-compiled")] | length' "0"
chk_jq "unrelated queue entry preserved" "$STATE_FILE" \
  '[.on_next_user_prompt[]? | select(.type == "some-other-thing")] | length' "1"

summary
