#!/usr/bin/env bash
# A `compact compile` invocation recorded ONLY in a subagent transcript
# (<transcript_dir>/<session-id>/subagents/agent-*.jsonl, where <session-id>
# is the main transcript's basename minus .jsonl) satisfies Stop.sh's
# compile check -- the main transcript itself never mentions the file.

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
sleep 1
COMPILE_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

TRANSCRIPT="$ROOT/transcript.jsonl"
transcript_no_compile "$TRANSCRIPT"    # main transcript never mentions a.compact

SUBAGENT_DIR="$ROOT/transcript/subagents"
mkdir -p "$SUBAGENT_DIR"
transcript_with_compile "$SUBAGENT_DIR/agent-review.jsonl" "$COMPILE_TS" "a.compact"

# Force the block gate open -- if the subagent transcript were NOT honored,
# this would visibly BLOCK rather than silently pass for an unrelated
# reason (e.g. cooldown).
jq '.triggers_since_last_block = 4 | .last_block_timestamp = null' \
   "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

PAYLOAD=$(hook_payload "$ROOT" "$SID" \
  "$(jq -cn --arg t "$TRANSCRIPT" '{transcript_path: $t, stop_hook_active: false}')")
run_hook "Stop.sh" "$PAYLOAD" OUT ERR RC

chk_eq "Stop exits 0 (satisfied by subagent transcript)" "0" "$RC"
chk_eq "no block reason emitted"                          "" "$ERR"
chk_jq "no compact-not-compiled queue entry" "$STATE_FILE" \
  '[.on_next_user_prompt[]? | select(.type == "compact-not-compiled")] | length' "0"

summary
