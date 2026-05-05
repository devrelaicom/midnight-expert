#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODES_FILE="$SCRIPT_DIR/codes.json"
RESOLVER="$SCRIPT_DIR/resolve-anchor.sh"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

if ! command -v jq >/dev/null; then
  echo "ERROR: jq required" >&2; exit 1
fi
if [[ ! -x "$RESOLVER" ]]; then
  echo "ERROR: resolve-anchor.sh not found or not executable at $RESOLVER" >&2; exit 1
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

# Slug round-trip: every reference_anchor's slug must reproduce when its target
# heading is re-slugged through resolve-anchor.sh --slug. Catches hand-authored
# anchors that drift from the (intentionally non-GitHub) slug algorithm.
BAD_ROUNDTRIP=()
while IFS=$'\t' read -r code anchor; do
  [[ -z "$anchor" ]] && continue
  md_path="${anchor%%#*}"
  slug="${anchor#*#}"
  target_file=""
  if [[ -f "$PLUGIN_ROOT/$md_path" ]]; then
    target_file="$PLUGIN_ROOT/$md_path"
  elif [[ -f "$SCRIPT_DIR/$md_path" ]]; then
    target_file="$SCRIPT_DIR/$md_path"
  else
    BAD_ROUNDTRIP+=("$code: file not found ($md_path)")
    continue
  fi

  # Find the heading whose slug equals the requested slug, then round-trip its
  # raw text. We use awk to find the matching heading text using the same slug
  # rules the resolver does.
  heading=$(awk -v target="$slug" '
    function slug(text,    s) {
      s = tolower(text)
      gsub(/`/, "", s)
      gsub(/[^a-z0-9 \-]/, "", s)
      gsub(/[ \t]+/, "-", s)
      gsub(/-+/, "-", s)
      sub(/^-+/, "", s)
      sub(/-+$/, "", s)
      return s
    }
    /^[ \t]{0,3}(```|~~~)/ { in_fence = !in_fence; next }
    in_fence { next }
    /^#+[ \t]+/ {
      sub(/^#+[ \t]+/, "", $0)
      sub(/[ \t]+$/, "", $0)
      if (slug($0) == target) { print; exit }
    }
  ' "$target_file")

  if [[ -z "$heading" ]]; then
    BAD_ROUNDTRIP+=("$code: no heading slugs to '$slug' in $md_path")
    continue
  fi
  reslug=$("$RESOLVER" --slug "$heading")
  if [[ "$reslug" != "$slug" ]]; then
    BAD_ROUNDTRIP+=("$code: '$heading' slugs to '$reslug', expected '$slug'")
  fi
done < <(jq -r '.entries[] | select((.reference_anchor // null) != null) | "\(.code)\t\(.reference_anchor)"' "$CODES_FILE")

if [[ "${#BAD_ROUNDTRIP[@]}" -gt 0 ]]; then
  echo "ERROR: reference_anchor slug round-trip failures:"
  printf '  %s\n' "${BAD_ROUNDTRIP[@]}"
  ERRORS=$((ERRORS+1))
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo
  echo "Schema check FAILED: $ERRORS error group(s)"
  exit 1
fi
echo "Schema check PASSED"
