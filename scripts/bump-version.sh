#!/usr/bin/env bash
#
# bump-version.sh - Bump marketplace and plugin versions
#
# Usage:
#   ./scripts/bump-version.sh --patch        # 0.3.0 -> 0.3.1
#   ./scripts/bump-version.sh --minor        # 0.3.0 -> 0.4.0
#   ./scripts/bump-version.sh --major        # 0.3.0 -> 1.0.0
#   ./scripts/bump-version.sh 2.1.0          # Set exact version
#   ./scripts/bump-version.sh --major --minor # major wins: 0.3.0 -> 1.0.0
#
# All plugin versions are synchronized with the marketplace version.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MARKETPLACE_JSON="$ROOT_DIR/.claude-plugin/marketplace.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 [--major|--minor|--patch] [VERSION]"
    echo ""
    echo "Options:"
    echo "  --major    Bump major version (X.0.0)"
    echo "  --minor    Bump minor version (x.Y.0)"
    echo "  --patch    Bump patch version (x.y.Z)"
    echo "  VERSION    Set exact version (e.g., 2.1.0)"
    echo ""
    echo "If multiple flags are provided, the most significant wins:"
    echo "  --major > --minor > --patch"
    echo ""
    echo "Examples:"
    echo "  $0 --patch         # 0.3.0 -> 0.3.1"
    echo "  $0 --minor         # 0.3.0 -> 0.4.0"
    echo "  $0 --major         # 0.3.0 -> 1.0.0"
    echo "  $0 2.1.0           # Set to 2.1.0"
    echo "  $0 --major --minor # 0.3.0 -> 1.0.0 (major wins)"
    exit 1
}

# Check for jq
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}"
    echo "Install with: brew install jq"
    exit 1
fi

# Check marketplace.json exists
if [[ ! -f "$MARKETPLACE_JSON" ]]; then
    echo -e "${RED}Error: marketplace.json not found at $MARKETPLACE_JSON${NC}"
    exit 1
fi

# Parse arguments
BUMP_TYPE=""
EXACT_VERSION=""

for arg in "$@"; do
    case $arg in
        --major)
            # Major always wins
            BUMP_TYPE="major"
            ;;
        --minor)
            # Minor wins unless major is set
            if [[ "$BUMP_TYPE" != "major" ]]; then
                BUMP_TYPE="minor"
            fi
            ;;
        --patch)
            # Patch only wins if nothing else is set
            if [[ -z "$BUMP_TYPE" ]]; then
                BUMP_TYPE="patch"
            fi
            ;;
        --help|-h)
            usage
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $arg${NC}"
            usage
            ;;
        *)
            # Assume it's an exact version
            if [[ "$arg" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                EXACT_VERSION="$arg"
            else
                echo -e "${RED}Error: Invalid version format '$arg'. Expected X.Y.Z${NC}"
                exit 1
            fi
            ;;
    esac
done

# Must have either bump type or exact version
if [[ -z "$BUMP_TYPE" && -z "$EXACT_VERSION" ]]; then
    echo -e "${RED}Error: Must specify --major, --minor, --patch, or an exact version${NC}"
    usage
fi

# Get current version from marketplace.json
CURRENT_VERSION=$(jq -r '.version' "$MARKETPLACE_JSON")
echo -e "${CYAN}Current version: $CURRENT_VERSION${NC}"

# Calculate new version
if [[ -n "$EXACT_VERSION" ]]; then
    NEW_VERSION="$EXACT_VERSION"
else
    # Parse current version
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

    case $BUMP_TYPE in
        major)
            NEW_VERSION="$((MAJOR + 1)).0.0"
            ;;
        minor)
            NEW_VERSION="${MAJOR}.$((MINOR + 1)).0"
            ;;
        patch)
            NEW_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"
            ;;
    esac
fi

echo -e "${GREEN}New version: $NEW_VERSION${NC}"

# Update marketplace.json
echo -e "${CYAN}Updating marketplace.json...${NC}"
jq --arg version "$NEW_VERSION" '.version = $version' "$MARKETPLACE_JSON" > "$MARKETPLACE_JSON.tmp"
mv "$MARKETPLACE_JSON.tmp" "$MARKETPLACE_JSON"

# Update all plugin.json files
echo -e "${CYAN}Updating plugin versions...${NC}"
PLUGIN_COUNT=0

for plugin_json in "$ROOT_DIR"/plugins/*/.claude-plugin/plugin.json; do
    if [[ -f "$plugin_json" ]]; then
        plugin_name=$(jq -r '.name' "$plugin_json")
        jq --arg version "$NEW_VERSION" '.version = $version' "$plugin_json" > "$plugin_json.tmp"
        mv "$plugin_json.tmp" "$plugin_json"
        echo -e "  ${GREEN}✓${NC} $plugin_name"
        PLUGIN_COUNT=$((PLUGIN_COUNT + 1))
    fi
done

echo ""
echo -e "${GREEN}=== Version bump complete ===${NC}"
echo -e "  Marketplace: $CURRENT_VERSION -> $NEW_VERSION"
echo -e "  Plugins updated: $PLUGIN_COUNT"
