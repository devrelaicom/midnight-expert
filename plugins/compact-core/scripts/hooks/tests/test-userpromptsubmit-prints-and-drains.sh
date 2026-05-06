#!/usr/bin/env bash
# midnight-expert UserPromptSubmit hook: format queued entries to stdout,
# drain the queue from settings, exit 0.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT=$(mk_project_root)
trap 'rm -rf "$ROOT"' EXIT

SETTINGS=$(settings_path "$ROOT")
write_settings "$SETTINGS" '{
  "on_next_user_prompt": [
    {
      "type": "compact-not-compiled",
      "files": ["/proj/a.compact", "/proj/sub/b.compact"]
    },
    {
      "type": "unknown-future-type",
      "payload": "should be silently dropped"
    }
  ]
}'

PAYLOAD=$(jq -cn --arg cwd "$ROOT" '{cwd: $cwd}')
run_hook_at "$MIDNIGHT_EXPERT_HOOKS_DIR/UserPromptSubmit.sh" "$PAYLOAD" OUT ERR RC

chk_eq        "UserPromptSubmit exits 0" "0" "$RC"
chk_eq        "UserPromptSubmit no stderr" "" "$ERR"
chk_contains  "stdout names a.compact"       "$OUT" "/proj/a.compact"
chk_contains  "stdout names sub/b.compact"   "$OUT" "/proj/sub/b.compact"
chk_contains  "stdout has heads-up heading"  "$OUT" "Heads up"
chk_jq        "queue drained"                 "$SETTINGS" \
  '.on_next_user_prompt // "absent"' "absent"

summary
