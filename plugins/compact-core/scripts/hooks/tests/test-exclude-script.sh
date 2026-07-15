#!/usr/bin/env bash
# Exercises plugins/compact-core/scripts/compact-check-exclude.sh directly.

set -euo pipefail
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
source "$SELF_DIR/_lib.sh"

SCRIPTS_DIR="$(cd "$HOOKS_DIR/.." && pwd)"
EXCLUDE_SCRIPT="$SCRIPTS_DIR/compact-check-exclude.sh"

TMP_HOME=$(mktemp -d)
export HOME="$TMP_HOME"
trap 'rm -rf "$TMP_HOME"' EXIT

ROOT=$(mk_project_root)
mkdir -p "$ROOT/vendor"
write_compact "$ROOT" "secret.compact" "contract secret v1"
write_compact "$ROOT" "vendor/lib.compact" "contract vendor v1"
CONFIG_FILE="$ROOT/.claude/compact-check.json"

# --- creates config file, records a file exclusion ---
set +e
OUT=$(bash "$EXCLUDE_SCRIPT" --project-root "$ROOT" "$ROOT/secret.compact" 2>&1)
RC=$?
set -e
chk_eq "exclude file exits 0" "0" "$RC"
chk_eq "config file created" "yes" "$([ -f "$CONFIG_FILE" ] && echo yes || echo no)"
chk_jq "secret.compact recorded" "$CONFIG_FILE" '.exclude | index("secret.compact") != null' "true"
chk_contains "output lists secret.compact" "$OUT" "secret.compact"

# --- directories get a trailing slash ---
set +e
OUT=$(bash "$EXCLUDE_SCRIPT" --project-root "$ROOT" "$ROOT/vendor" 2>&1)
RC=$?
set -e
chk_eq "exclude dir exits 0" "0" "$RC"
chk_jq "vendor/ recorded with trailing slash" "$CONFIG_FILE" '.exclude | index("vendor/") != null' "true"

# --- dedupes on repeat calls ---
bash "$EXCLUDE_SCRIPT" --project-root "$ROOT" "$ROOT/secret.compact" > /dev/null 2>&1
COUNT=$(jq '[.exclude[] | select(. == "secret.compact")] | length' "$CONFIG_FILE")
chk_eq "secret.compact not duplicated" "1" "$COUNT"

# --- rejects outside-root paths ---
OUTSIDE=$(mktemp -d)
touch "$OUTSIDE/other.compact"
set +e
OUT=$(bash "$EXCLUDE_SCRIPT" --project-root "$ROOT" "$OUTSIDE/other.compact" 2>&1)
RC=$?
set -e
chk_eq "outside-root path exits 1" "1" "$RC"
rm -rf "$OUTSIDE"

# --- rejects nonexistent paths ---
set +e
OUT=$(bash "$EXCLUDE_SCRIPT" --project-root "$ROOT" "$ROOT/does-not-exist.compact" 2>&1)
RC=$?
set -e
chk_eq "nonexistent path exits 1" "1" "$RC"

# --- no paths given: exit 1 ---
set +e
OUT=$(bash "$EXCLUDE_SCRIPT" --project-root "$ROOT" 2>&1)
RC=$?
set -e
chk_eq "no paths exits 1" "1" "$RC"

# --- project root defaults to $CLAUDE_PROJECT_DIR ---
ROOT2=$(mk_project_root)
write_compact "$ROOT2" "priv.compact" "contract priv v1"
set +e
OUT=$(CLAUDE_PROJECT_DIR="$ROOT2" bash "$EXCLUDE_SCRIPT" "$ROOT2/priv.compact" 2>&1)
RC=$?
set -e
chk_eq "CLAUDE_PROJECT_DIR default exits 0" "0" "$RC"
chk_jq "priv.compact recorded under CLAUDE_PROJECT_DIR config" "$ROOT2/.claude/compact-check.json" \
  '.exclude | index("priv.compact") != null' "true"

# --- final sorted, deduped exclude list for ROOT ---
chk_jq "exclude list is sorted" "$CONFIG_FILE" '.exclude == (.exclude | sort)' "true"

rm -rf "$ROOT" "$ROOT2"
summary
