#!/usr/bin/env bash
# marketplace.sh - Marketplace configuration and plugin path resolution
#
# Provides a single source of truth for resolving pluginRoot and plugin paths.
# All scripts that need to locate plugins should source this and call
# init_marketplace_config instead of hardcoding PLUGINS_DIR.

# Source dependencies
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/colors.sh"

# Globals set by init_marketplace_config
PROJECT_ROOT=""
PLUGIN_ROOT=""
PLUGIN_ROOT_ABS=""

# Initialize marketplace configuration from marketplace.json.
# Sets the following globals:
#   PROJECT_ROOT     - absolute path to the project root
#   PLUGIN_ROOT      - pluginRoot value from marketplace.json (e.g. "./plugins")
#   PLUGIN_ROOT_ABS  - absolute path to the plugin root directory
#
# Usage: init_marketplace_config [marketplace_json]
#   marketplace_json defaults to .claude-plugin/marketplace.json
# Returns: 0 on success, 1 on failure
init_marketplace_config() {
    local marketplace_json="${1:-.claude-plugin/marketplace.json}"

    if [[ ! -f "$marketplace_json" ]]; then
        print_error "Marketplace file not found: $marketplace_json"
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        print_error "jq is required but not installed"
        return 1
    fi

    PROJECT_ROOT=$(cd "$(dirname "$marketplace_json")/.." && pwd)
    PLUGIN_ROOT=$(jq -r '.pluginRoot // ""' "$marketplace_json" 2>/dev/null)

    if [[ -n "$PLUGIN_ROOT" ]]; then
        # Normalize pluginRoot to always start with ./
        if [[ "$PLUGIN_ROOT" != ./* && "$PLUGIN_ROOT" != /* ]]; then
            PLUGIN_ROOT="./$PLUGIN_ROOT"
        fi
        PLUGIN_ROOT_ABS=$(cd "$PROJECT_ROOT" && cd "$PLUGIN_ROOT" 2>/dev/null && pwd) || {
            print_error "pluginRoot directory does not exist: $PLUGIN_ROOT (from $marketplace_json)"
            return 1
        }
    else
        PLUGIN_ROOT_ABS="$PROJECT_ROOT/plugins"
        PLUGIN_ROOT="./plugins"
    fi
}

# Resolve a plugin name or path argument to an absolute filesystem path.
# Tries: direct path, then name under PLUGIN_ROOT_ABS.
# Requires init_marketplace_config to have been called.
#
# Usage: resolve_plugin_to_path <name_or_path>
# Output: absolute path to plugin directory (on stdout)
# Returns: 0 if found, 1 if not
resolve_plugin_to_path() {
    local input="$1"

    # Direct path
    if [[ -d "$input" ]]; then
        (cd "$input" && pwd)
        return 0
    fi

    # Name under plugin root
    if [[ -d "$PLUGIN_ROOT_ABS/$input" ]]; then
        echo "$PLUGIN_ROOT_ABS/$input"
        return 0
    fi

    return 1
}

# Resolve a plugin source field from marketplace.json to an absolute path.
# Handles: bare names (resolved via pluginRoot), relative paths, absolute paths.
# Requires init_marketplace_config to have been called.
#
# Usage: resolve_plugin_source <source>
# Output: absolute path to plugin directory (on stdout)
# Returns: 0 if resolved, 1 if not
resolve_plugin_source() {
    local source="$1"

    # Absolute path
    if [[ "$source" == /* ]]; then
        echo "$source"
        return 0
    fi

    # Explicit relative path (starts with ./ or ../)
    if [[ "$source" == ./* || "$source" == ../* ]]; then
        local resolved
        resolved=$(cd "$PROJECT_ROOT" && cd "$source" 2>/dev/null && pwd) || return 1
        echo "$resolved"
        return 0
    fi

    # Bare name - resolve relative to pluginRoot
    if [[ -d "$PLUGIN_ROOT_ABS/$source" ]]; then
        echo "$PLUGIN_ROOT_ABS/$source"
        return 0
    fi

    return 1
}

# Convert an absolute plugin path to the relative source value expected by
# the Claude CLI validator (e.g. "./plugins/my-plugin").
# Requires init_marketplace_config to have been called.
#
# Usage: plugin_path_to_source <absolute_path>
# Output: relative source path (on stdout)
# Returns: 0 if the path is under PLUGIN_ROOT_ABS, 1 otherwise
plugin_path_to_source() {
    local abs_path="$1"

    if [[ "$abs_path" == "$PLUGIN_ROOT_ABS/"* ]]; then
        local basename="${abs_path#"$PLUGIN_ROOT_ABS/"}"
        echo "$PLUGIN_ROOT/$basename"
        return 0
    fi

    # Not under pluginRoot — return as-is (external reference)
    echo "$abs_path"
    return 1
}
