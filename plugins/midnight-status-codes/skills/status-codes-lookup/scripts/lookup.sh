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
Usage: lookup.sh <mode> <value>

Modes:
  --code <value>       Exact match on code, name, or aliases (case-insensitive)
  --search <regex>     Regex search across name, description, aliases, code, category
  --source <name>      List all codes for a source
  --sources            List all available sources with counts
  --category <name>    List all codes in a category
USAGE
  exit 1
}

# --- Output helpers ---
print_detailed() {
  # Reads JSON array from stdin, prints detailed blocks
  jq -r '.[] | "=== MATCH: \(.source) / \(.code) ===\nCode: \(.code)\nName: \(.name)\nSource: \(.source)\nCategory: \(.group.name)\nCategory Description: \(.group.description)\nSeverity: \(.severity)\nDescription: \(.description)\nFixes:\n\(.fixes | map("  - " + .) | join("\n"))\nAliases: \(.aliases | join(", "))\nSee Also: \(.see_also | join(", "))\nVerified: \(.verified_against.source_repo // "?")@\(.verified_against.ref // "?") · anchor: \(.verified_against.anchor // "?") (modified \(.verified_against.anchor_modified // "?")) · audit \(.verified_against.verified_at // "?")\n==="'
}

print_compact() {
  local header="$1"
  echo "$header"
  echo "Code | Name | Category | Severity"
  echo "---- | ---- | -------- | --------"
  jq -r '.[] | "\(.code) | \(.name) | \(.category) | \(.severity)"'
  echo "==="
}

# --- Argument parsing ---
if [[ $# -lt 1 ]]; then
  usage
fi

MODE="$1"
VALUE="${2:-}"

case "$MODE" in
  --code)
    [[ -z "$VALUE" ]] && { echo "ERROR: --code requires a value" >&2; exit 1; }
    LOWER_VALUE=$(echo "$VALUE" | tr '[:upper:]' '[:lower:]')
    RESULTS=$(jq --arg val "$LOWER_VALUE" '[.entries[] | select(
      (.code | ascii_downcase) == $val or
      (.name | ascii_downcase) == $val or
      (.aliases | map(ascii_downcase) | any(. == $val))
    )]' "$CODES_FILE")
    COUNT=$(echo "$RESULTS" | jq 'length')
    if [[ "$COUNT" -eq 0 ]]; then
      echo "No match found for code: $VALUE"
      exit 0
    fi
    echo "$RESULTS" | print_detailed
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
    COUNT=$(echo "$RESULTS" | jq 'length')
    if [[ "$COUNT" -eq 0 ]]; then
      echo "No matches found for search: $VALUE"
      exit 0
    fi
    if [[ "$COUNT" -le 5 ]]; then
      echo "$RESULTS" | print_detailed
    else
      echo "$RESULTS" | print_compact "=== SEARCH: \"$VALUE\" ($COUNT entries) ==="
    fi
    ;;

  --source)
    [[ -z "$VALUE" ]] && { echo "ERROR: --source requires a value" >&2; exit 1; }
    RESULTS=$(jq --arg src "$VALUE" '[.entries[] | select(.source == $src)]' "$CODES_FILE")
    COUNT=$(echo "$RESULTS" | jq 'length')
    if [[ "$COUNT" -eq 0 ]]; then
      echo "No entries found for source: $VALUE"
      exit 0
    fi
    echo "$RESULTS" | print_compact "=== SOURCE: $VALUE ($COUNT entries) ==="
    ;;

  --sources)
    jq -r '[.entries[].source] | group_by(.) | map({source: .[0], count: length}) | sort_by(.source) | .[] | "\(.source): \(.count) entries"' "$CODES_FILE"
    ;;

  --category)
    [[ -z "$VALUE" ]] && { echo "ERROR: --category requires a value" >&2; exit 1; }
    RESULTS=$(jq --arg cat "$VALUE" '[.entries[] | select(.category == $cat)]' "$CODES_FILE")
    COUNT=$(echo "$RESULTS" | jq 'length')
    if [[ "$COUNT" -eq 0 ]]; then
      echo "No entries found for category: $VALUE"
      exit 0
    fi
    echo "$RESULTS" | print_compact "=== CATEGORY: $VALUE ($COUNT entries) ==="
    ;;

  *)
    echo "ERROR: Unknown argument: $MODE" >&2
    usage
    ;;
esac
