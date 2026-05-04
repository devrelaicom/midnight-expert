#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODES_FILE="$SCRIPT_DIR/codes.json"

if ! command -v jq >/dev/null; then
  echo "ERROR: jq required" >&2; exit 1
fi

PHASE_ENUM='lexer parser frontend name-res type-check witness purity zkir exit runtime external'

ERRORS=0

# Required-on-all-entries fields
MISSING_REQ=$(jq -r '
  .entries[]
  | select((.code // null) == null or (.name // null) == null or (.source // null) == null or (.severity // null) == null)
  | "\(.source // "?")::\(.code // "?")"
' "$CODES_FILE")
if [[ -n "$MISSING_REQ" ]]; then
  echo "ERROR: entries missing required fields:"
  echo "$MISSING_REQ" | sed 's/^/  /'
  ERRORS=$((ERRORS+1))
fi

# compact-compiler entries must have phase, and phase must be in enum
BAD_PHASE=$(jq --arg enum "$PHASE_ENUM" -r '
  .entries[]
  | select(.source == "compact-compiler")
  | select((.phase // null) == null or ((.phase as $p | $enum | split(" ") | index($p)) == null))
  | "\(.code) (phase=\(.phase // "MISSING"))"
' "$CODES_FILE")
if [[ -n "$BAD_PHASE" ]]; then
  echo "ERROR: compact-compiler entries with missing or invalid phase:"
  echo "$BAD_PHASE" | sed 's/^/  /'
  ERRORS=$((ERRORS+1))
fi

# reference_anchor, when present, must point to a file under the plugin
BAD_ANCHOR=$(jq -r '
  .entries[]
  | select((.reference_anchor // null) != null)
  | select((.reference_anchor | startswith("skills/")) | not)
  | "\(.code): \(.reference_anchor)"
' "$CODES_FILE")
if [[ -n "$BAD_ANCHOR" ]]; then
  echo "ERROR: reference_anchor must be plugin-relative (skills/...):"
  echo "$BAD_ANCHOR" | sed 's/^/  /'
  ERRORS=$((ERRORS+1))
fi

# id, when present on a compact-compiler entry, must match compiler.<phase>.<slug>
BAD_ID=$(jq -r '
  .entries[]
  | select(.source == "compact-compiler" and (.id // null) != null)
  | select(.id | test("^compiler\\.[a-z\\-]+\\.[a-z0-9\\-]+$") | not)
  | "\(.code): id=\(.id)"
' "$CODES_FILE")
if [[ -n "$BAD_ID" ]]; then
  echo "ERROR: malformed id slugs (expected compiler.<phase>.<slug>):"
  echo "$BAD_ID" | sed 's/^/  /'
  ERRORS=$((ERRORS+1))
fi

# Duplicate id detection
DUP_IDS=$(jq -r '[.entries[] | .id] | map(select(. != null)) | group_by(.) | map(select(length > 1) | .[0])' "$CODES_FILE")
if [[ "$DUP_IDS" != "[]" ]]; then
  echo "ERROR: duplicate ids:"
  echo "$DUP_IDS" | jq -r '.[]' | sed 's/^/  /'
  ERRORS=$((ERRORS+1))
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo
  echo "Schema check FAILED: $ERRORS error group(s)"
  exit 1
fi
echo "Schema check PASSED"
