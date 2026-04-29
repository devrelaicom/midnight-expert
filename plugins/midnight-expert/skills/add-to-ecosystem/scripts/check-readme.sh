#!/usr/bin/env bash
# Inspect ./README.md and emit JSON describing its current state and where
# to insert the EC attribution alert. Output: single JSON object on stdout.
set -u

if ! command -v jq >/dev/null 2>&1; then
  echo "check-readme.sh: jq is required" >&2
  exit 2
fi

README="README.md"

# --- shared helpers ---

# Convert "" / number to JSON ("null" or the number)
or_null() {
  if [ -z "$1" ]; then echo "null"; else echo "$1"; fi
}

EXISTS="false"
[ -f "$README" ] && EXISTS="true"

# Sentences to look for (case-insensitive, whitespace-collapsed match)
SENT_BUILT='this project is built on the midnight network.'
SENT_INTEG='this project integrates with the midnight network.'
SENT_EXTND='this project extends the midnight network with additional developer tooling.'

PRESENT="false"
MATCHED="null"
FIRST_H1=""
FIRST_H2=""
TITLE_END=""
PLACEMENT="top-of-file"

if [ "$EXISTS" = "true" ] && [ -s "$README" ]; then
  # Normalise the file: lowercase, collapse whitespace, single line
  NORM="$(tr '[:upper:]' '[:lower:]' < "$README" | tr '\n\t' '  ' | tr -s ' ')"
  if echo "$NORM" | grep -qF "$SENT_BUILT"; then PRESENT="true"; MATCHED='"built-on"'; fi
  if [ "$PRESENT" = "false" ] && echo "$NORM" | grep -qF "$SENT_INTEG"; then PRESENT="true"; MATCHED='"integrates"'; fi
  if [ "$PRESENT" = "false" ] && echo "$NORM" | grep -qF "$SENT_EXTND"; then PRESENT="true"; MATCHED='"extends"'; fi

  # Line numbers
  FIRST_H1="$(grep -nE '^# ' "$README" | head -n1 | cut -d: -f1 || true)"
  FIRST_H2="$(grep -nE '^## ' "$README" | head -n1 | cut -d: -f1 || true)"

  # Count H1s
  H1_COUNT="$(grep -cE '^# ' "$README" || true)"

  if [ "${H1_COUNT:-0}" -gt 1 ]; then
    PLACEMENT="ambiguous"
  elif [ -n "$FIRST_H1" ]; then
    # Walk forward from H1 to find title-block end.
    TITLE_END="$FIRST_H1"
    line_no=0
    tagline_seen=0
    while IFS= read -r line; do
      line="${line%$'\r'}"
      line_no=$((line_no+1))
      [ "$line_no" -le "$FIRST_H1" ] && continue
      # Block-end signals
      if echo "$line" | grep -qE '^## '; then break; fi
      if echo "$line" | grep -qE '^---\s*$'; then break; fi
      if echo "$line" | grep -qE '^[[:space:]]*[-*+] '; then break; fi
      if echo "$line" | grep -qE '^[[:space:]]*[0-9]+\.[[:space:]]'; then break; fi
      # Title-block continuation
      if [ -z "$line" ]; then TITLE_END=$line_no; continue; fi
      if echo "$line" | grep -qE '^[[:space:]]*(\[!\[|<a |<img |<p align|</p>|<div align|</div>)'; then
        TITLE_END=$line_no; continue
      fi
      # Tagline (≤ 200 chars, prose, only one allowed)
      len=${#line}
      if [ "$tagline_seen" -eq 0 ] && [ "$len" -le 200 ]; then
        tagline_seen=1
        TITLE_END=$line_no
        continue
      fi
      break
    done < "$README"
    PLACEMENT="after-title-block"
  else
    # No H1 — look for top-of-file HTML banner
    FIRST_LINE="$(head -n1 "$README")"
    if echo "$FIRST_LINE" | grep -qE '^[[:space:]]*<(p|div) align="center"'; then
      # Find the closing tag
      CLOSE_LINE="$(grep -nE '^[[:space:]]*</(p|div)>' "$README" | head -n1 | cut -d: -f1 || true)"
      if [ -n "$CLOSE_LINE" ]; then
        TITLE_END="$CLOSE_LINE"
        # Also include subsequent banner blocks (a tagline-in-<p> block)
        next_start=$((CLOSE_LINE+1))
        # peek next non-blank line
        peek="$(awk -v s="$next_start" 'NR>=s && NF{print; exit}' "$README")"
        if echo "$peek" | grep -qE '^[[:space:]]*<(p|div) align="center"'; then
          NEXT_CLOSE="$(awk -v s="$next_start" 'NR>=s && /<\/(p|div)>/{print NR; exit}' "$README" || true)"
          [ -n "$NEXT_CLOSE" ] && TITLE_END="$NEXT_CLOSE"
        fi
        PLACEMENT="after-title-block"
      else
        PLACEMENT="top-of-file"
      fi
    else
      PLACEMENT="top-of-file"
    fi
  fi
fi

jq -n \
  --argjson exists "$EXISTS" \
  --argjson present "$PRESENT" \
  --argjson matched "$MATCHED" \
  --argjson first_h1_line "$(or_null "$FIRST_H1")" \
  --argjson first_h2_line "$(or_null "$FIRST_H2")" \
  --argjson title_block_end_line "$(or_null "$TITLE_END")" \
  --arg placement "$PLACEMENT" \
  '{
     exists: $exists,
     present: $present,
     matched_sentence: $matched,
     first_h1_line: $first_h1_line,
     first_h2_line: $first_h2_line,
     title_block_end_line: $title_block_end_line,
     placement: $placement
   }'
