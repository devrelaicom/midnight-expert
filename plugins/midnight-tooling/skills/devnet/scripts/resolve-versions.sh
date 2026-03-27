#!/usr/bin/env bash
set -euo pipefail

# resolve-versions.sh
# Queries Docker Hub for the latest stable (X.Y.Z) tags of Midnight devnet images.
# Output: key=value pairs, one per line
#   node=X.Y.Z
#   indexer=X.Y.Z
#   proof-server=X.Y.Z
# Exit 0 on success, 1 on failure.

# Check dependencies
for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: Required command '${cmd}' not found. Please install it." >&2
    exit 1
  fi
done

IMAGES=(
  "node|midnightntwrk/midnight-node"
  "indexer|midnightntwrk/indexer-standalone"
  "proof-server|midnightntwrk/proof-server"
)

# Fetch all tags for an image from Docker Hub, handling pagination.
# Docker Hub returns max 100 results per page.
fetch_tags() {
  local image="$1"
  local url="https://hub.docker.com/v2/repositories/${image}/tags/?page_size=100&ordering=last_updated"
  local all_tags=""

  while [ -n "$url" ] && [ "$url" != "null" ]; do
    local response
    response=$(curl -sf --max-time 15 "$url") || {
      echo "ERROR: Failed to fetch tags for ${image}. Is Docker Hub reachable?" >&2
      return 1
    }

    local page_tags
    page_tags=$(echo "$response" | jq -r '.results[].name // empty')
    all_tags="${all_tags}${all_tags:+$'\n'}${page_tags}"

    url=$(echo "$response" | jq -r '.next // "null"')
  done

  echo "$all_tags"
}

# Filter tags to pure X.Y.Z semver (no pre-release, no arch suffix, no rc/alpha/beta).
# Returns the highest version.
highest_stable() {
  local tags="$1"
  echo "$tags" \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' \
    | sort -t. -k1,1n -k2,2n -k3,3n \
    | tail -1
}

errors=0

for entry in "${IMAGES[@]}"; do
  IFS='|' read -r name image <<< "$entry"

  tags=$(fetch_tags "$image") || { errors=$((errors + 1)); continue; }

  version=$(highest_stable "$tags")
  if [ -z "$version" ]; then
    echo "ERROR: No stable version found for ${image}" >&2
    errors=$((errors + 1))
    continue
  fi

  echo "${name}=${version}"
done

if [ "$errors" -gt 0 ]; then
  exit 1
fi
