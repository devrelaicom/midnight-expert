#!/usr/bin/env bash
# When the previous SessionEnd left an unchecked-contracts list,
# SessionStart-compact-check.sh surfaces it as additionalContext AND
# atomically clears the key from settings.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

ROOT=$(mk_project_root)
trap 'rm -rf "$ROOT"' EXIT

SETTINGS=$(settings_path "$ROOT")
write_settings "$SETTINGS" '{
  "compact_compilation_check_hook": {
    "last_block_line_count": 0,
    "last_block_timestamp": null,
    "triggers_since_last_block": 0,
    "compact_files": {},
    "unchecked_from_previous_session": ["foo.compact", "bar/baz.compact"]
  }
}'

PAYLOAD=$(jq -cn --arg cwd "$ROOT" '{cwd: $cwd}')
run_hook "SessionStart-compact-check.sh" "$PAYLOAD" OUT ERR RC

chk_eq        "SessionStart exits 0"               "0" "$RC"
chk_contains  "additionalContext names foo.compact"     "$OUT" "foo.compact"
chk_contains  "additionalContext names bar/baz.compact" "$OUT" "bar/baz.compact"
chk_jq        "unchecked_from_previous_session cleared" "$SETTINGS" \
  '.compact_compilation_check_hook.unchecked_from_previous_session // "absent"' "absent"

summary
