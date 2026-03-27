#!/usr/bin/env bash
set -euo pipefail

# find-devnet.sh
# Locates a devnet.yml compose file.
#
# Usage:
#   find-devnet.sh                  Search standard locations
#   find-devnet.sh --file <path>    Use explicit path (FAIL if not found, no fallback)
#
# Search order (when no --file):
#   1. ./devnet.yml
#   2. ./.midnight/devnet.yml
#   3. ~/.midnight-expert/devnet/devnet.yml
#
# Output: Prints the absolute path of the found file.
# Exit 0 on success, 1 if not found.

EXPLICIT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) EXPLICIT_FILE="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -n "$EXPLICIT_FILE" ]; then
  if [ -f "$EXPLICIT_FILE" ]; then
    # Resolve to absolute path
    cd "$(dirname "$EXPLICIT_FILE")" && echo "$(pwd)/$(basename "$EXPLICIT_FILE")"
    exit 0
  else
    echo "ERROR: Specified file not found: ${EXPLICIT_FILE}" >&2
    exit 1
  fi
fi

# Search standard locations
SEARCH_PATHS=(
  "./devnet.yml"
  "./.midnight/devnet.yml"
  "${HOME}/.midnight-expert/devnet/devnet.yml"
)

for path in "${SEARCH_PATHS[@]}"; do
  if [ -f "$path" ]; then
    # Resolve to absolute path
    cd "$(dirname "$path")" && echo "$(pwd)/$(basename "$path")"
    exit 0
  fi
done

echo "ERROR: No devnet.yml found. Searched:" >&2
for path in "${SEARCH_PATHS[@]}"; do
  echo "  - ${path}" >&2
done
echo "Run '/devnet generate' to create one, or use '--file <path>' to specify a location." >&2
exit 1
