#!/usr/bin/env bash
# Exercises the exclusion-matching helpers in _compact-check.sh directly:
# compact_exclusions, compact_is_excluded, compact_filter_excluded, and the
# way compact_snapshot_files / compact_state_file / compact_state_init /
# compact_block_reason_for_files honor them (or their own contracts).

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

# shellcheck source=../_compact-check.sh
source "$HOOKS_DIR/_compact-check.sh"

TMP_HOME=$(mktemp -d)
export HOME="$TMP_HOME"
trap 'rm -rf "$TMP_HOME"' EXIT

ROOT=$(mk_project_root)

is_excluded() {
  if compact_is_excluded "$1" "$2"; then echo "excluded"; else echo "not-excluded"; fi
}

# --- no config file: nothing is excluded, compact_exclusions is empty -----
chk_eq "no config: file not excluded" "not-excluded" "$(is_excluded "$ROOT" "$ROOT/foo.compact")"
chk_eq "no config: compact_exclusions empty" "" "$(compact_exclusions "$ROOT")"

# --- write an exclusion config: one file, one dir ---
mkdir -p "$ROOT/.claude" "$ROOT/vendor"
cat > "$ROOT/.claude/compact-check.json" << 'JSON'
{"exclude": ["secret.compact", "vendor/"]}
JSON

chk_eq "compact_exclusions lists both entries" "$(printf 'secret.compact\nvendor/')" "$(compact_exclusions "$ROOT")"

# --- file exact match ---
chk_eq "exact file match excluded" "excluded" "$(is_excluded "$ROOT" "$ROOT/secret.compact")"
chk_eq "different file not excluded" "not-excluded" "$(is_excluded "$ROOT" "$ROOT/public.compact")"

# --- dir prefix match ---
chk_eq "file under excluded dir is excluded" "excluded" "$(is_excluded "$ROOT" "$ROOT/vendor/lib.compact")"
chk_eq "nested file under excluded dir is excluded" "excluded" "$(is_excluded "$ROOT" "$ROOT/vendor/nested/lib.compact")"
chk_eq "dir name as a substring elsewhere is not excluded" "not-excluded" "$(is_excluded "$ROOT" "$ROOT/vendorish.compact")"

# --- outside project root: never excluded, even if it matches by name ---
OUTSIDE=$(mktemp -d)
touch "$OUTSIDE/secret.compact"
chk_eq "path outside project root is never excluded" "not-excluded" "$(is_excluded "$ROOT" "$OUTSIDE/secret.compact")"
rm -rf "$OUTSIDE"

# --- invalid config JSON: treated as no exclusions, no crash ---
BADCFG_ROOT=$(mk_project_root)
mkdir -p "$BADCFG_ROOT/.claude"
printf 'not valid json{{{' > "$BADCFG_ROOT/.claude/compact-check.json"
chk_eq "invalid config: compact_exclusions empty" "" "$(compact_exclusions "$BADCFG_ROOT")"
chk_eq "invalid config: file not excluded" "not-excluded" "$(is_excluded "$BADCFG_ROOT" "$BADCFG_ROOT/foo.compact")"
rm -rf "$BADCFG_ROOT"

# --- compact_filter_excluded: stdin paths -> only non-excluded printed ---
FILTERED=$(printf '%s\n%s\n%s\n' "$ROOT/secret.compact" "$ROOT/public.compact" "$ROOT/vendor/lib.compact" \
  | compact_filter_excluded "$ROOT")
chk_eq "compact_filter_excluded keeps only non-excluded" "$ROOT/public.compact" "$FILTERED"

# --- compact_snapshot_files respects exclusions ---
write_compact "$ROOT" "public.compact" "contract public v1"
write_compact "$ROOT" "secret.compact" "contract secret v1"
write_compact "$ROOT" "vendor/lib.compact" "contract vendor v1"

SNAPSHOT=$(compact_snapshot_files "$ROOT")
chk_contains "snapshot includes non-excluded file" "$SNAPSHOT" "$ROOT/public.compact"
NOT_SECRET=$(echo "$SNAPSHOT" | jq -r --arg f "$ROOT/secret.compact" 'has($f) | tostring')
chk_eq "snapshot excludes secret.compact" "false" "$NOT_SECRET"
NOT_VENDOR=$(echo "$SNAPSHOT" | jq -r --arg f "$ROOT/vendor/lib.compact" 'has($f) | tostring')
chk_eq "snapshot excludes vendor/lib.compact" "false" "$NOT_VENDOR"

# --- compact_state_file: path scheme, empty session_id, mkdir -p ---
HASH16=$(printf '%s' "$ROOT" | sha256sum | awk '{print $1}' | cut -c1-16)
STATE_FILE=$(compact_state_file "$ROOT" "sess-123")
chk_eq "compact_state_file path matches scheme" "$HOME/.midnight-expert/state/$HASH16/sess-123.json" "$STATE_FILE"
chk_eq "compact_state_file created the state dir" "yes" "$([ -d "$HOME/.midnight-expert/state/$HASH16" ] && echo yes || echo no)"
chk_eq "compact_state_file empty session_id prints nothing" "" "$(compact_state_file "$ROOT" "")"

# --- compact_state_init: creates schema skeleton respecting exclusions ---
compact_state_init "$STATE_FILE" "$ROOT" "sess-123"
chk_eq "state file created" "yes" "$([ -f "$STATE_FILE" ] && echo yes || echo no)"
chk_jq "state schema_version" "$STATE_FILE" ".schema_version" "1"
chk_jq "state project_root" "$STATE_FILE" ".project_root" "$ROOT"
chk_jq "state session_id" "$STATE_FILE" ".session_id" "sess-123"
chk_jq "state triggers_since_last_block" "$STATE_FILE" ".triggers_since_last_block" "0"
chk_jq "state last_block_timestamp" "$STATE_FILE" ".last_block_timestamp // \"null\"" "null"
chk_jq "state flag_events" "$STATE_FILE" ".flag_events" "[]"
chk_jq "state on_next_user_prompt" "$STATE_FILE" ".on_next_user_prompt" "[]"
chk_jq "state unchecked_from_previous_session" "$STATE_FILE" ".unchecked_from_previous_session" "[]"
chk_jq "state compact_files excludes secret.compact" "$STATE_FILE" \
  ".compact_files | has(\"$ROOT/secret.compact\")" "false"
chk_jq "state compact_files includes public.compact" "$STATE_FILE" \
  ".compact_files | has(\"$ROOT/public.compact\")" "true"

# --- compact_state_init is a no-op when the file already exists ---
jq '.triggers_since_last_block = 99' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
compact_state_init "$STATE_FILE" "$ROOT" "sess-123"
chk_jq "state_init no-ops when file exists" "$STATE_FILE" ".triggers_since_last_block" "99"

# --- compact_block_reason_for_files: extra_text arg ---
BLOCK_JSON=$(printf '%s\n' "$ROOT/public.compact" | compact_block_reason_for_files "Extra note here.")
chk_contains "block reason includes extra_text" "$BLOCK_JSON" "Extra note here."
chk_contains "block reason still includes file" "$BLOCK_JSON" "public.compact"

BLOCK_JSON_NO_EXTRA=$(printf '%s\n' "$ROOT/public.compact" | compact_block_reason_for_files)
chk_eq "block reason with no extra_text has no trailing note" "0" \
  "$(printf '%s' "$BLOCK_JSON_NO_EXTRA" | grep -cF "Extra note here." || true)"

# --- compact_transcript_compile_ts: main transcript + subagent transcripts ---
TRANSCRIPT="$ROOT/transcript.jsonl"
transcript_with_compile "$TRANSCRIPT" "2026-07-15T10:00:00Z" "public.compact"

SUBAGENT_DIR="$ROOT/transcript/subagents"
mkdir -p "$SUBAGENT_DIR"
transcript_with_compile "$SUBAGENT_DIR/sub1.jsonl" "2026-07-15T12:00:00Z" "public.compact"

LATEST_TS=$(compact_transcript_compile_ts "$TRANSCRIPT" "public.compact")
chk_eq "compact_transcript_compile_ts picks the later subagent timestamp" "2026-07-15T12:00:00Z" "$LATEST_TS"

# main transcript alone (no subagent dir) still works
TRANSCRIPT2="$ROOT/transcript2.jsonl"
transcript_with_compile "$TRANSCRIPT2" "2026-07-15T09:00:00Z" "public.compact"
LATEST_TS2=$(compact_transcript_compile_ts "$TRANSCRIPT2" "public.compact")
chk_eq "compact_transcript_compile_ts works with no subagent dir" "2026-07-15T09:00:00Z" "$LATEST_TS2"

rm -rf "$ROOT"
summary
