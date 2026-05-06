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
PAYLOAD=$(jq -cn --arg cwd "$ROOT" '{cwd: $cwd}')
run_hook "SessionStart-compact-check.sh" "$PAYLOAD" _ _ _

# Pre-populate a stale queue entry from a prior turn.
SETTINGS=$(settings_path "$ROOT")
jq '.on_next_user_prompt = [
      { type: "compact-not-compiled", files: ["stale.compact"] },
      { type: "some-other-thing", payload: "keep me" }
    ]' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"

# No file modifications => check is clean.
TRANSCRIPT="$ROOT/transcript.jsonl"
transcript_no_compile "$TRANSCRIPT"

PAYLOAD=$(jq -cn --arg cwd "$ROOT" --arg t "$TRANSCRIPT" \
  '{cwd: $cwd, transcript_path: $t, stop_hook_active: false}')
run_hook "Stop.sh" "$PAYLOAD" OUT ERR RC

chk_eq "Stop exits 0 when clean" "0" "$RC"
chk_jq "compact-not-compiled entry removed" "$SETTINGS" \
  '[.on_next_user_prompt[]? | select(.type == "compact-not-compiled")] | length' "0"
chk_jq "unrelated queue entry preserved" "$SETTINGS" \
  '[.on_next_user_prompt[]? | select(.type == "some-other-thing")] | length' "1"

summary
