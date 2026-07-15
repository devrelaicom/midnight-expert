#!/usr/bin/env bash
# SessionStart-compact-check.sh hashes every .compact file under the project
# root and persists them into the per-session state file's compact_files.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT=$(mk_project_root)
trap 'rm -rf "$ROOT"' EXIT

write_compact "$ROOT" "a.compact" "contract a v1"
write_compact "$ROOT" "b.compact" "contract b v1"

EXPECTED_A=$(sha256sum "$ROOT/a.compact" | awk '{print $1}')
EXPECTED_B=$(sha256sum "$ROOT/b.compact" | awk '{print $1}')

SID="sess-1"
STATE_FILE=$(state_path "$ROOT" "$SID")

PAYLOAD=$(hook_payload "$ROOT" "$SID")
run_hook "SessionStart-compact-check.sh" "$PAYLOAD" OUT ERR RC

chk_eq "SessionStart exits 0" "0" "$RC"
chk_jq "a.compact hash recorded" "$STATE_FILE" \
  ".compact_files[\"$ROOT/a.compact\"]" "$EXPECTED_A"
chk_jq "b.compact hash recorded" "$STATE_FILE" \
  ".compact_files[\"$ROOT/b.compact\"]" "$EXPECTED_B"
chk_jq "no previous-session list left" "$STATE_FILE" \
  '.unchecked_from_previous_session' "[]"
chk_jq "schema_version set" "$STATE_FILE" ".schema_version" "1"
chk_jq "project_root set" "$STATE_FILE" ".project_root" "$ROOT"
chk_jq "session_id set" "$STATE_FILE" ".session_id" "$SID"
chk_jq "triggers_since_last_block reset" "$STATE_FILE" ".triggers_since_last_block" "0"
chk_jq "last_block_timestamp null" "$STATE_FILE" ".last_block_timestamp // \"null\"" "null"
chk_jq "flag_events empty" "$STATE_FILE" ".flag_events" "[]"
chk_jq "on_next_user_prompt empty" "$STATE_FILE" ".on_next_user_prompt" "[]"

summary
