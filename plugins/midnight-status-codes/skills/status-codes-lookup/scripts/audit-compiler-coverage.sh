#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODES_FILE="$SCRIPT_DIR/codes.json"
ALLOWLIST="$SCRIPT_DIR/coverage-allowlist.txt"
DEFAULT_CLONE_DIR="${COMPACT_CLONE_DIR:-/tmp/compact-stable}"

if ! command -v jq >/dev/null; then
  echo "ERROR: jq required" >&2; exit 1
fi
if [[ ! -f "$CODES_FILE" ]]; then
  echo "ERROR: codes.json not found at $CODES_FILE" >&2; exit 1
fi

REF=$(jq -r '[.entries[] | select(.source == "compact-compiler") | .verified_against.ref] | map(select(. != null)) | unique | .[0] // empty' "$CODES_FILE")
if [[ -z "$REF" ]]; then
  echo "ERROR: no compact-compiler entry has verified_against.ref set" >&2; exit 1
fi

# Locate or fetch the source tree
if [[ -d "$DEFAULT_CLONE_DIR/compiler" ]]; then
  CLONE_DIR="$DEFAULT_CLONE_DIR"
else
  CLONE_DIR="/tmp/compact-stable-$REF"
  if [[ ! -d "$CLONE_DIR/compiler" ]]; then
    echo "Cloning $REF into $CLONE_DIR ..." >&2
    git clone --depth 1 --branch "$REF" https://github.com/LFDT-Minokawa/compact "$CLONE_DIR" >&2
  fi
fi

# Shared normalisation: collapse format placeholders to "__" and squeeze runs of
# horizontal whitespace to a single space. Used by both the extractor and the
# JSON haystack; drift between the two would silently cause match failures.
normalize() {
  sed -E 's/~[asd@%]/__/g; s/~\*?[a-zA-Z]/__/g' \
    | sed -E 's/[[:blank:]]+/ /g; s/^ //; s/ $//'
}

extract_templates() {
  local files
  files=$(find "$CLONE_DIR/compiler" "$CLONE_DIR/runtime" -type f \( -name '*.ss' -o -name '*.ts' \) 2>/dev/null)
  for f in $files; do
    # Join continuation lines so each macro invocation lives on a single
    # logical line. We look forward up to 3 lines after a target macro name
    # and stop once we have seen a quoted string — that captures the common
    # case where the macro name and the format string sit on adjacent lines
    # (e.g. fixup.ss:83 source-warningf with the format string on the next
    # physical line).
    awk '
      /\((source-errorf|pending-errorf|external-errorf|source-warningf|error-accessing-file)([^[:alnum:]_-]|$)/ {
        buf = $0
        for (i = 1; i <= 3; i++) {
          if ((getline next_line) <= 0) break
          buf = buf " " next_line
          if (next_line ~ /"[^"]*"/) break
        }
        print buf
        next
      }
      { print }
    ' "$f"
  done \
    | grep -Eo '\((source-errorf|pending-errorf|external-errorf|source-warningf|error-accessing-file)[^"]*"[^"]*"' \
    | sed -E 's/^[^"]*"([^"]*)".*$/\1/' \
    | normalize \
    | sort -u \
    || true
}

TEMPLATES_FILE=$(mktemp)
extract_templates > "$TEMPLATES_FILE"

# Build a normalised lookup haystack from JSON entry code + aliases
HAYSTACK=$(jq -r '
  .entries[]
  | select(.source == "compact-compiler")
  | [(.code // ""), (.aliases // [] | .[])]
  | .[]
' "$CODES_FILE" \
  | normalize)

# Build allowlist regex array
ALLOW_PATTERNS=()
if [[ -f "$ALLOWLIST" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    ALLOW_PATTERNS+=("$line")
  done < "$ALLOWLIST"
fi

UNCOVERED=()
ALLOWLISTED=0

while IFS= read -r template; do
  [[ -z "$template" ]] && continue
  norm=$(echo "$template" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
  [[ -z "$norm" ]] && continue

  if grep -qF -- "$norm" <<<"$HAYSTACK"; then
    continue
  fi
  matched_allow=0
  for pat in "${ALLOW_PATTERNS[@]:-}"; do
    [[ -z "$pat" ]] && continue
    if echo "$norm" | grep -qE -- "$pat"; then
      matched_allow=1; break
    fi
  done
  if [[ "$matched_allow" -eq 1 ]]; then
    ALLOWLISTED=$((ALLOWLISTED+1))
    continue
  fi
  UNCOVERED+=("$norm")
done < "$TEMPLATES_FILE"

rm -f "$TEMPLATES_FILE"

echo "=== Coverage report (ref: $REF) ==="
echo "Allowlisted templates: $ALLOWLISTED"
echo "Uncovered templates:   ${#UNCOVERED[@]}"
if [[ "${#UNCOVERED[@]}" -gt 0 ]]; then
  echo
  echo "--- Uncovered ---"
  for t in "${UNCOVERED[@]}"; do
    echo "  $t"
  done
fi

# Stale check: entries whose code does not appear as any template substring
echo
echo "--- Stale entries (no template match) ---"
STALE=$(jq -r '
  .entries[]
  | select(.source == "compact-compiler" and (.category != "exit-code"))
  | .code
' "$CODES_FILE")
TPL_BLOB=$(extract_templates)
STALE_FOUND=0
while IFS= read -r code; do
  [[ -z "$code" ]] && continue
  if ! grep -qF -- "$code" <<<"$TPL_BLOB"; then
    echo "  $code"
    STALE_FOUND=$((STALE_FOUND+1))
  fi
done <<< "$STALE"
echo "Stale entries: $STALE_FOUND"

if [[ "${#UNCOVERED[@]}" -gt 0 ]]; then
  exit 1
fi
