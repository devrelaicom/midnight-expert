#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
CODES_FILE="$SCRIPT_DIR/codes.json"

# --- Dependency checks ---
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed. Install it with: brew install jq" >&2
  exit 1
fi

if [[ ! -f "$CODES_FILE" ]]; then
  echo "ERROR: codes.json not found at $CODES_FILE" >&2
  exit 1
fi

# --- Usage ---
usage() {
  cat <<'USAGE'
Usage: lookup.sh [global flags] <mode> [value]

Modes:
  --code <value>       Exact match on code, name, or aliases (case-insensitive)
  --search <regex>     Regex search across name, description, aliases, code, category
  --source <name>      List all codes for a source
  --sources            List all available sources with counts
  --category <name>    List all codes in a category

Global flags (any mode):
  --json                  Emit a JSON array of matched entries (verbatim from codes.json)
                          instead of the human/agent-friendly === MATCH === format.
  --status <value>        Filter by entry .status. One of: active | retired | all (default).
                          Entries with no .status field are treated as "active".
USAGE
  exit 1
}

# --- Argument parsing ---
JSON=0
STATUS_FILTER="all"
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)   JSON=1; shift ;;
    --status)
      [[ $# -ge 2 ]] || { echo "ERROR: --status requires a value (active|retired|all)" >&2; exit 1; }
      case "$2" in
        active|retired|all) STATUS_FILTER="$2" ;;
        *) echo "ERROR: --status must be one of: active, retired, all (got: $2)" >&2; exit 1 ;;
      esac
      shift 2
      ;;
    -h|--help) usage ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

set -- "${ARGS[@]:-}"

if [[ $# -lt 1 ]]; then
  usage
fi

MODE="$1"
VALUE="${2:-}"

# --- Status filter helper ---
# Reads a JSON array from stdin and filters entries by their .status field
# (treating absent .status as "active") according to $STATUS_FILTER.
apply_status_filter() {
  jq --arg mode "$STATUS_FILTER" '
    if $mode == "all" then .
    else
      [ .[] | select(((.status // "active")) == $mode) ]
    end
  '
}

# --- Output helpers ---
emit_results() {
  # Reads JSON array from stdin and either prints --json verbatim or the
  # === MATCH === detail block via print_detailed.
  local input
  input=$(cat)
  if [[ "$JSON" -eq 1 ]]; then
    echo "$input" | jq '.'
  else
    echo "$input" | print_detailed
  fi
}

emit_compact_or_json() {
  # Used by list-style modes (--source, --category). With --json, emit the
  # filtered array verbatim; otherwise render the existing compact table.
  local header="$1"
  local input
  input=$(cat)
  if [[ "$JSON" -eq 1 ]]; then
    echo "$input" | jq '.'
  else
    echo "$input" | print_compact "$header"
  fi
}

print_detailed() {
  # Reads JSON array from stdin, prints detailed blocks per entry, then resolves
  # any reference_anchor to verbatim markdown via resolve-anchor.sh.
  local resolver="$SCRIPT_DIR/resolve-anchor.sh"
  local plugin_root
  plugin_root="$(cd "$SCRIPT_DIR/../../.." && pwd)"
  local input
  input=$(cat)

  local count
  count=$(jq 'length' <<<"$input")
  local i=0
  while [[ "$i" -lt "$count" ]]; do
    local entry
    entry=$(jq ".[$i]" <<<"$input")
    jq -r '
      "=== MATCH: \(.source) / \(.code) ===",
      "Code: \(.code)",
      "Name: \(.name)",
      "Source: \(.source)",
      (if .phase then "Phase: \(.phase)" else empty end),
      (if .id then "ID: \(.id)" else empty end),
      "Category: \(.group.name)",
      "Category Description: \(.group.description)",
      "Severity: \(.severity)",
      (if .status then "Status: \(.status)" else empty end),
      (if .superseded_by and (.superseded_by | length) > 0 then "Superseded by: \(.superseded_by | join(", "))" else empty end),
      (if .class then "Class: \(.class)" else empty end),
      "Description: \(.description)",
      "Fixes:",
      (.fixes // [] | map("  - " + .) | .[]),
      "Aliases: \((.aliases // []) | join(", "))",
      "See Also: \((.see_also // []) | join(", "))",
      "Verified: \(.verified_against.source_repo // "?")@\(.verified_against.ref // "?") · anchor: \(.verified_against.anchor // "?") (modified \(.verified_against.anchor_modified // "?")) · audit \(.verified_against.verified_at // "?")"
    ' <<<"$entry"

    local ra
    ra=$(jq -r '.reference_anchor // empty' <<<"$entry")
    if [[ -n "$ra" ]]; then
      local md_path="${ra%%#*}"
      local slug="${ra#*#}"
      local target_file
      if [[ -f "$plugin_root/$md_path" ]]; then
        target_file="$plugin_root/$md_path"
      elif [[ -f "$SCRIPT_DIR/$md_path" ]]; then
        target_file="$SCRIPT_DIR/$md_path"
      else
        echo "Reference: BROKEN ($ra) — file not found"
        echo "==="
        i=$((i+1))
        continue
      fi
      echo "Reference: $ra"
      echo "--- Begin reference section ---"
      if ! "$resolver" --extract "$target_file" "$slug"; then
        echo "(anchor resolution failed: $slug)"
      fi
      echo "--- End reference section ---"
    fi
    echo "==="
    i=$((i+1))
  done
}

print_compact() {
  local header="$1"
  echo "$header"
  echo "Code | Name | Category | Severity"
  echo "---- | ---- | -------- | --------"
  jq -r '.[] | "\(.code) | \(.name) | \(.category) | \(.severity)"'
  echo "==="
}

case "$MODE" in
  --code)
    [[ -z "$VALUE" ]] && { echo "ERROR: --code requires a value" >&2; exit 1; }
    LOWER_VALUE=$(echo "$VALUE" | tr '[:upper:]' '[:lower:]')
    RESULTS=$(jq --arg val "$LOWER_VALUE" '[.entries[] | select(
      (.code | ascii_downcase) == $val or
      (.name | ascii_downcase) == $val or
      (.aliases | map(ascii_downcase) | any(. == $val))
    )]' "$CODES_FILE")
    RESULTS=$(echo "$RESULTS" | apply_status_filter)
    COUNT=$(echo "$RESULTS" | jq 'length')
    if [[ "$COUNT" -eq 0 ]]; then
      if [[ "$JSON" -eq 1 ]]; then
        echo "[]"
      else
        echo "No match found for code: $VALUE"
      fi
      exit 0
    fi
    echo "$RESULTS" | emit_results
    ;;

  --search)
    [[ -z "$VALUE" ]] && { echo "ERROR: --search requires a value" >&2; exit 1; }
    RESULTS=$(jq --arg pat "$VALUE" '[.entries[] | select(
      (.name | test($pat; "i")) or
      (.description | test($pat; "i")) or
      (.code | test($pat; "i")) or
      (.category | test($pat; "i")) or
      (.aliases | any(test($pat; "i")))
    )]' "$CODES_FILE")
    RESULTS=$(echo "$RESULTS" | apply_status_filter)
    COUNT=$(echo "$RESULTS" | jq 'length')
    if [[ "$COUNT" -eq 0 ]]; then
      if [[ "$JSON" -eq 1 ]]; then
        echo "[]"
      else
        echo "No matches found for search: $VALUE"
      fi
      exit 0
    fi
    if [[ "$JSON" -eq 1 ]]; then
      echo "$RESULTS" | jq '.'
    elif [[ "$COUNT" -le 5 ]]; then
      echo "$RESULTS" | print_detailed
    else
      echo "$RESULTS" | print_compact "=== SEARCH: \"$VALUE\" ($COUNT entries) ==="
    fi
    ;;

  --source)
    [[ -z "$VALUE" ]] && { echo "ERROR: --source requires a value" >&2; exit 1; }
    RESULTS=$(jq --arg src "$VALUE" '[.entries[] | select(.source == $src)]' "$CODES_FILE")
    RESULTS=$(echo "$RESULTS" | apply_status_filter)
    COUNT=$(echo "$RESULTS" | jq 'length')
    if [[ "$COUNT" -eq 0 ]]; then
      if [[ "$JSON" -eq 1 ]]; then
        echo "[]"
      else
        echo "No entries found for source: $VALUE"
      fi
      exit 0
    fi
    echo "$RESULTS" | emit_compact_or_json "=== SOURCE: $VALUE ($COUNT entries) ==="
    ;;

  --sources)
    if [[ "$JSON" -eq 1 ]]; then
      jq --arg mode "$STATUS_FILTER" '
        [ .entries[]
          | select($mode == "all" or ((.status // "active") == $mode))
          | .source ]
        | group_by(.)
        | map({source: .[0], count: length})
        | sort_by(.source)
      ' "$CODES_FILE"
    else
      jq --arg mode "$STATUS_FILTER" -r '
        [ .entries[]
          | select($mode == "all" or ((.status // "active") == $mode))
          | .source ]
        | group_by(.)
        | map({source: .[0], count: length})
        | sort_by(.source)
        | .[]
        | "\(.source): \(.count) entries"
      ' "$CODES_FILE"
    fi
    ;;

  --category)
    [[ -z "$VALUE" ]] && { echo "ERROR: --category requires a value" >&2; exit 1; }
    RESULTS=$(jq --arg cat "$VALUE" '[.entries[] | select(.category == $cat)]' "$CODES_FILE")
    RESULTS=$(echo "$RESULTS" | apply_status_filter)
    COUNT=$(echo "$RESULTS" | jq 'length')
    if [[ "$COUNT" -eq 0 ]]; then
      if [[ "$JSON" -eq 1 ]]; then
        echo "[]"
      else
        echo "No entries found for category: $VALUE"
      fi
      exit 0
    fi
    echo "$RESULTS" | emit_compact_or_json "=== CATEGORY: $VALUE ($COUNT entries) ==="
    ;;

  *)
    echo "ERROR: Unknown argument: $MODE" >&2
    usage
    ;;
esac
