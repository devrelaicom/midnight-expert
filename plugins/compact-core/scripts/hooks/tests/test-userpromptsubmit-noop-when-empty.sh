#!/usr/bin/env bash
# UserPromptSubmit hook: with an absent or empty queue, emit no stdout and
# exit 0 without modifying settings.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT=$(mk_project_root)
trap 'rm -rf "$ROOT"' EXIT

SETTINGS=$(settings_path "$ROOT")

# --- Case 1: settings file does not exist at all ---
PAYLOAD=$(jq -cn --arg cwd "$ROOT" '{cwd: $cwd}')
run_hook_at "$MIDNIGHT_EXPERT_HOOKS_DIR/UserPromptSubmit.sh" "$PAYLOAD" OUT ERR RC

chk_eq "no settings file: exits 0"  "0" "$RC"
chk_eq "no settings file: no stdout" "" "$OUT"
chk_eq "no settings file: no stderr" "" "$ERR"

# --- Case 2: settings exists, queue absent ---
write_settings "$SETTINGS" '{"compact_compilation_check_hook": {}}'
run_hook_at "$MIDNIGHT_EXPERT_HOOKS_DIR/UserPromptSubmit.sh" "$PAYLOAD" OUT ERR RC

chk_eq "no queue key: exits 0"   "0" "$RC"
chk_eq "no queue key: no stdout" "" "$OUT"

# --- Case 3: settings exists, queue is empty array ---
write_settings "$SETTINGS" '{"on_next_user_prompt": []}'
run_hook_at "$MIDNIGHT_EXPERT_HOOKS_DIR/UserPromptSubmit.sh" "$PAYLOAD" OUT ERR RC

chk_eq "empty queue: exits 0"   "0" "$RC"
chk_eq "empty queue: no stdout" "" "$OUT"

summary
