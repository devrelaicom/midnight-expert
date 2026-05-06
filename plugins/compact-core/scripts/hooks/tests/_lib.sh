#!/usr/bin/env bash
# Shared helpers for the compact-core hook tests. Sourced by each test script.
# Each test:
#   - creates a fresh tmp project root via `mk_project_root`
#   - drops .compact fixtures via `write_compact`
#   - synthesizes JSONL transcripts via `transcript_with_compile` /
#     `transcript_no_compile`
#   - drives a hook script via `run_hook` (pipes hook input on stdin)
#   - asserts via `chk_eq`, `chk_contains`, `chk_jq`

set -euo pipefail

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGINS_DIR="$(cd "$HOOKS_DIR/../../.." && pwd)"
MIDNIGHT_EXPERT_HOOKS_DIR="$PLUGINS_DIR/midnight-expert/scripts/hooks"
export HOOKS_DIR PLUGINS_DIR MIDNIGHT_EXPERT_HOOKS_DIR

# --- Test infrastructure ----------------------------------------------------

PASS=0
FAIL=0
FAIL_NAMES=()

chk_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1))
    FAIL_NAMES+=("$label")
    echo "  FAIL: $label"
    echo "    expected: $expected"
    echo "    actual:   $actual"
  fi
}

chk_contains() {
  local label="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    PASS=$((PASS + 1))
    echo "  PASS: $label"
  else
    FAIL=$((FAIL + 1))
    FAIL_NAMES+=("$label")
    echo "  FAIL: $label  (needle '$needle' not in output)"
    echo "    haystack: $haystack"
  fi
}

chk_jq() {
  local label="$1" file="$2" filter="$3" expected="$4"
  local actual
  actual=$(jq -r "$filter" "$file" 2>/dev/null || echo "<jq-error>")
  chk_eq "$label" "$expected" "$actual"
}

summary() {
  echo
  echo "  ${PASS} passed, ${FAIL} failed"
  if [ "$FAIL" -gt 0 ]; then
    printf '  failed:\n'
    printf '    - %s\n' "${FAIL_NAMES[@]}"
    exit 1
  fi
  exit 0
}

# --- Fixture helpers --------------------------------------------------------

mk_project_root() {
  local d
  d=$(mktemp -d)
  mkdir -p "$d/.midnight-expert"
  printf '%s' "$d"
}

# write_compact <project_root> <relative_name> <content>
write_compact() {
  local root="$1" name="$2" content="$3"
  printf '%s' "$content" > "$root/$name"
}

# settings_path <project_root>
settings_path() {
  printf '%s/.midnight-expert/settings.local.json' "$1"
}

# Build a JSONL transcript line representing a Bash tool_use with the given
# command and ISO-8601 timestamp.
#
# usage: transcript_line <iso_timestamp> <bash_command>
transcript_line() {
  local ts="$1" cmd="$2"
  jq -cn --arg ts "$ts" --arg cmd "$cmd" '{
    timestamp: $ts,
    message: {
      content: [
        { type: "tool_use", name: "Bash", input: { command: $cmd } }
      ]
    }
  }'
}

# transcript_no_compile <path>
transcript_no_compile() {
  local path="$1"
  : > "$path"  # empty file is a valid no-op transcript
}

# transcript_with_compile <path> <iso_timestamp> <filename>
transcript_with_compile() {
  local path="$1" ts="$2" fn="$3"
  transcript_line "$ts" "compact compile $fn" > "$path"
}

# Run a hook script, piping the given JSON object on stdin. Captures stdout,
# stderr, and exit code into the named variables (passed by name).
#
# usage: run_hook_at <full_script_path> <stdin_json> <stdout_var> <stderr_var> <rc_var>
run_hook_at() {
  local script_path="$1" payload="$2"
  local out_var="$3" err_var="$4" rc_var="$5"
  local out err rc=0

  local tmp_err
  tmp_err=$(mktemp)
  out=$(printf '%s' "$payload" | bash "$script_path" 2>"$tmp_err") || rc=$?
  err=$(cat "$tmp_err")
  rm -f "$tmp_err"

  printf -v "$out_var" '%s' "$out"
  printf -v "$err_var" '%s' "$err"
  printf -v "$rc_var" '%s' "$rc"
}

# usage: run_hook <script_basename_in_HOOKS_DIR> <stdin_json> <stdout_var> <stderr_var> <rc_var>
run_hook() {
  run_hook_at "$HOOKS_DIR/$1" "$2" "$3" "$4" "$5"
}

# Initialize a settings file with a baseline matching SessionStart's defaults
# but pre-populated by the caller. Helper for tests that want to skip running
# SessionStart first.
write_settings() {
  local file="$1" json="$2"
  printf '%s\n' "$json" > "$file"
}
