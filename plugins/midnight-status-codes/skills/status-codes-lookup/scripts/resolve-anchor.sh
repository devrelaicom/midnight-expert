#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF' >&2
Usage:
  resolve-anchor.sh --slug <heading-text>
  resolve-anchor.sh --extract <markdown-path> <slug>

--slug      Print the GitHub-style slug for a heading text.
--extract   Print the section under <slug> in <markdown-path>, up to the next
            heading at the same or higher level. Exits non-zero if not found.
EOF
  exit 2
}

slugify() {
  awk '
    {
      s = tolower($0)
      gsub(/`/, "", s)
      gsub(/[^a-z0-9 \-]/, "", s)
      gsub(/[ \t]+/, "-", s)
      gsub(/-+/, "-", s)
      sub(/^-+/, "", s)
      sub(/-+$/, "", s)
      print s
    }
  '
}

extract_section() {
  local file="$1"
  local target_slug="$2"

  awk -v target="$target_slug" '
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
    {
      line = $0
      if (match(line, /^#+[ \t]+/)) {
        hashes = substr(line, 1, RLENGTH - 1)
        gsub(/[ \t]/, "", hashes)
        level = length(hashes)
        text = substr(line, RLENGTH + 1)
        sub(/[ \t]+$/, "", text)
        s = slug(text)
        if (capturing && level <= start_level) {
          exit
        }
        if (!capturing && s == target) {
          capturing = 1
          start_level = level
          next
        }
      }
      if (capturing) print line
    }
    END {
      if (!capturing) {
        print "ERROR: anchor not found: " target > "/dev/stderr"
        exit 1
      }
    }
  ' "$file"
}

[[ $# -lt 1 ]] && usage

case "$1" in
  --slug)
    [[ $# -ne 2 ]] && usage
    printf '%s' "$2" | slugify
    ;;
  --extract)
    [[ $# -ne 3 ]] && usage
    [[ -f "$2" ]] || { echo "ERROR: file not found: $2" >&2; exit 1; }
    extract_section "$2" "$3"
    ;;
  *)
    usage
    ;;
esac
