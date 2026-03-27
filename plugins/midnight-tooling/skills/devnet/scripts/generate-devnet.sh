#!/usr/bin/env bash
set -euo pipefail

# generate-devnet.sh
# Generates a devnet.yml from a template by substituting version placeholders.
#
# Required: --template <path> --node-version <X.Y.Z> --indexer-version <X.Y.Z> --proof-server-version <X.Y.Z>
# Optional: --directory <path> (default: ~/.midnight-expert/devnet)
#
# Output: Writes devnet.yml to the target directory. Prints the output path on success.

usage() {
  echo "Usage: $0 --template <path> --node-version <ver> --indexer-version <ver> --proof-server-version <ver> [--directory <path>]" >&2
  exit 1
}

TEMPLATE=""
NODE_VERSION=""
INDEXER_VERSION=""
PROOF_SERVER_VERSION=""
DIRECTORY="${HOME}/.midnight-expert/devnet"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template)        TEMPLATE="$2"; shift 2 ;;
    --node-version)    NODE_VERSION="$2"; shift 2 ;;
    --indexer-version) INDEXER_VERSION="$2"; shift 2 ;;
    --proof-server-version) PROOF_SERVER_VERSION="$2"; shift 2 ;;
    --directory)       DIRECTORY="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

# Validate required args
if [ -z "$TEMPLATE" ] || [ -z "$NODE_VERSION" ] || [ -z "$INDEXER_VERSION" ] || [ -z "$PROOF_SERVER_VERSION" ]; then
  echo "ERROR: Missing required arguments." >&2
  usage
fi

if [ ! -f "$TEMPLATE" ]; then
  echo "ERROR: Template file not found: ${TEMPLATE}" >&2
  exit 1
fi

# Create destination directory if needed
mkdir -p "$DIRECTORY"

GENERATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
OUTPUT="${DIRECTORY}/devnet.yml"

# Copy template and substitute placeholders
sed \
  -e "s|{{NODE_VERSION}}|${NODE_VERSION}|g" \
  -e "s|{{INDEXER_VERSION}}|${INDEXER_VERSION}|g" \
  -e "s|{{PROOF_SERVER_VERSION}}|${PROOF_SERVER_VERSION}|g" \
  -e "s|{{GENERATED_AT}}|${GENERATED_AT}|g" \
  "$TEMPLATE" > "$OUTPUT"

echo "$OUTPUT"
