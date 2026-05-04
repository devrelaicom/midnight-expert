#!/usr/bin/env bash
# Convenience wrapper for hand-authoring reference_anchor values.
#
# The slug algorithm in resolve-anchor.sh diverges from GitHub's slugger
# (drops underscores, em-dashes, slashes; collapses runs of hyphens).
# Authors who paste a heading title and guess at the slug usually get it
# wrong; use this wrapper instead.
#
# Usage:
#   bin/anchor-for-heading.sh "Heading text"
#       -> heading-text   (slug only)
#
#   bin/anchor-for-heading.sh skills/status-codes/references/foo.md "Heading text"
#       -> skills/status-codes/references/foo.md#heading-text
#       (full reference_anchor value, ready to drop into codes.json)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESOLVER="$SCRIPT_DIR/../resolve-anchor.sh"

usage() {
  sed -n '2,16p' "$0" >&2
  exit 2
}

case "$#" in
  1)
    "$RESOLVER" --slug "$1"
    ;;
  2)
    md_path="$1"
    heading="$2"
    slug=$("$RESOLVER" --slug "$heading")
    printf '%s#%s\n' "$md_path" "$slug"
    ;;
  *)
    usage
    ;;
esac
