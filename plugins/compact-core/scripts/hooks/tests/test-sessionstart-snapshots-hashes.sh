#!/usr/bin/env bash
# SessionStart-compact-check.sh hashes every .compact file under the project
# root and persists them at compact_compilation_check_hook.compact_files.

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

PAYLOAD=$(jq -cn --arg cwd "$ROOT" '{cwd: $cwd}')
run_hook "SessionStart-compact-check.sh" "$PAYLOAD" OUT ERR RC

chk_eq "SessionStart exits 0" "0" "$RC"
chk_jq "a.compact hash recorded"        "$(settings_path "$ROOT")" \
  ".compact_compilation_check_hook.compact_files[\"$ROOT/a.compact\"]" "$EXPECTED_A"
chk_jq "b.compact hash recorded"        "$(settings_path "$ROOT")" \
  ".compact_compilation_check_hook.compact_files[\"$ROOT/b.compact\"]" "$EXPECTED_B"
chk_jq "no previous-session list left"  "$(settings_path "$ROOT")" \
  '.compact_compilation_check_hook.unchecked_from_previous_session // "absent"' "absent"

summary
