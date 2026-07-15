#!/usr/bin/env bash
# Exercises plugins/compact-core/scripts/compact-check-reset.sh directly.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

SCRIPTS_DIR="$(cd "$HOOKS_DIR/.." && pwd)"
RESET_SCRIPT="$SCRIPTS_DIR/compact-check-reset.sh"

TMP_HOME=$(mktemp -d)
export HOME="$TMP_HOME"
trap 'rm -rf "$TMP_HOME"' EXIT

ROOT=$(mk_project_root)
write_compact "$ROOT" "a.compact" "contract a v1"
write_compact "$ROOT" "b.compact" "contract b v1"

HASH16=$(printf '%s' "$ROOT" | sha256sum | awk '{print $1}' | cut -c1-16)
STATE_DIR="$HOME/.midnight-expert/state/$HASH16"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/sess-1.json"

cat > "$STATE_FILE" << JSON
{
  "schema_version": 1,
  "project_root": "$ROOT",
  "session_id": "sess-1",
  "created_at": "2026-07-14T00:00:00Z",
  "compact_files": {"$ROOT/a.compact": "stale-hash-1", "$ROOT/gone.compact": "stale-hash-2"},
  "triggers_since_last_block": 7,
  "last_block_timestamp": "2026-07-14T12:00:00Z",
  "flag_events": [{"at": "2026-07-14T11:00:00Z"}],
  "on_next_user_prompt": [{"type": "compact-not-compiled", "files": ["x"]}],
  "unchecked_from_previous_session": [{"path": "$ROOT/a.compact", "sha256": "stale-hash-1", "flagged_at": "2026-07-14T11:00:00Z"}]
}
JSON

EXPECTED_A=$(sha256sum "$ROOT/a.compact" | awk '{print $1}')
EXPECTED_B=$(sha256sum "$ROOT/b.compact" | awk '{print $1}')

# --- missing --state-file arg: exit 1 ---
set +e
OUT=$(bash "$RESET_SCRIPT" 2>&1)
RC=$?
set -e
chk_eq "missing --state-file exits 1" "1" "$RC"

# --- path not under state dir: exit 1 ---
BAD_PATH="$TMP_HOME/not-state/file.json"
mkdir -p "$(dirname "$BAD_PATH")"
echo '{"project_root": "'"$ROOT"'"}' > "$BAD_PATH"
set +e
OUT=$(bash "$RESET_SCRIPT" --state-file "$BAD_PATH" 2>&1)
RC=$?
set -e
chk_eq "path outside state dir exits 1" "1" "$RC"

# --- file does not exist: exit 1 ---
set +e
OUT=$(bash "$RESET_SCRIPT" --state-file "$STATE_DIR/does-not-exist.json" 2>&1)
RC=$?
set -e
chk_eq "nonexistent state file exits 1" "1" "$RC"

# --- invalid JSON: exit 1 ---
BAD_JSON="$STATE_DIR/bad.json"
printf 'not json' > "$BAD_JSON"
set +e
OUT=$(bash "$RESET_SCRIPT" --state-file "$BAD_JSON" 2>&1)
RC=$?
set -e
chk_eq "invalid JSON exits 1" "1" "$RC"

# --- valid JSON but no .project_root: exit 1 ---
NO_ROOT="$STATE_DIR/no-root.json"
echo '{"schema_version": 1}' > "$NO_ROOT"
set +e
OUT=$(bash "$RESET_SCRIPT" --state-file "$NO_ROOT" 2>&1)
RC=$?
set -e
chk_eq "missing project_root exits 1" "1" "$RC"

# --- happy path: resets a populated state file, re-snapshots ---
set +e
OUT=$(bash "$RESET_SCRIPT" --state-file "$STATE_FILE" 2>&1)
RC=$?
set -e
chk_eq "reset exits 0" "0" "$RC"
chk_contains "reset output names the state file" "$OUT" "$STATE_FILE"

chk_jq "triggers_since_last_block reset to 0" "$STATE_FILE" ".triggers_since_last_block" "0"
chk_jq "last_block_timestamp reset to null" "$STATE_FILE" ".last_block_timestamp // \"null\"" "null"
chk_jq "flag_events reset to []" "$STATE_FILE" ".flag_events" "[]"
chk_jq "on_next_user_prompt reset to []" "$STATE_FILE" ".on_next_user_prompt" "[]"
chk_jq "unchecked_from_previous_session reset to []" "$STATE_FILE" ".unchecked_from_previous_session" "[]"
chk_jq "compact_files re-snapshotted for a.compact" "$STATE_FILE" ".compact_files[\"$ROOT/a.compact\"]" "$EXPECTED_A"
chk_jq "compact_files re-snapshotted for b.compact" "$STATE_FILE" ".compact_files[\"$ROOT/b.compact\"]" "$EXPECTED_B"
chk_jq "stale gone.compact entry dropped" "$STATE_FILE" ".compact_files | has(\"$ROOT/gone.compact\")" "false"
chk_jq "project_root untouched" "$STATE_FILE" ".project_root" "$ROOT"
chk_jq "session_id untouched" "$STATE_FILE" ".session_id" "sess-1"

rm -rf "$ROOT"
summary
