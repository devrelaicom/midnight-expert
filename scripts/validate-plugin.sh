#!/usr/bin/env bash
# validate-plugin.sh - Validate one or more plugins using claude CLI

set -euo pipefail

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/json.sh"
source "$SCRIPT_DIR/lib/validation.sh"

# Default values
QUIET=false
PLUGINS_DIR="./plugins"

# Usage information
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [PLUGIN...]

Validate one or more plugins using 'claude plugin validate'

Arguments:
  PLUGIN      Plugin name (searches ./plugins), path, or directory of plugins
              If no plugins specified, validates all plugins in ./plugins

Options:
  --json      Output machine-readable JSON
  --quiet     Suppress non-error output
  --help      Show this help message

Examples:
  $(basename "$0") dev                    # Validate dev plugin
  $(basename "$0") dev gh-cli             # Validate multiple plugins
  $(basename "$0") /path/to/plugin        # Validate plugin at path
  $(basename "$0")                        # Validate all plugins
  $(basename "$0") --json                 # JSON output for automation

EOF
    exit 0
}

# Parse command line arguments
PLUGIN_ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            enable_json_mode
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --help)
            usage
            ;;
        *)
            PLUGIN_ARGS+=("$1")
            shift
            ;;
    esac
done

# Resolve plugin paths
resolve_plugin_path() {
    local input="$1"

    # If it's a directory path
    if [[ -d "$input" ]]; then
        echo "$input"
        return 0
    fi

    # Try as plugin name in ./plugins
    if [[ -d "$PLUGINS_DIR/$input" ]]; then
        echo "$PLUGINS_DIR/$input"
        return 0
    fi

    return 1
}

# Collect all plugins to validate
PLUGINS_TO_VALIDATE=()

if [[ ${#PLUGIN_ARGS[@]} -eq 0 ]]; then
    # No arguments: validate all plugins in ./plugins
    if [[ ! -d "$PLUGINS_DIR" ]]; then
        print_error "Plugins directory not found: $PLUGINS_DIR"
        exit 1
    fi

    while IFS= read -r -d '' dir; do
        PLUGINS_TO_VALIDATE+=("$dir")
    done < <(find "$PLUGINS_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

    if [[ ${#PLUGINS_TO_VALIDATE[@]} -eq 0 ]]; then
        print_error "No plugins found in $PLUGINS_DIR"
        exit 1
    fi
else
    # Process provided arguments
    for arg in "${PLUGIN_ARGS[@]}"; do
        if [[ -d "$arg" ]]; then
            # Check if it's a directory of plugins or a single plugin
            if [[ -f "$arg/.claude-plugin/plugin.json" ]]; then
                # Single plugin directory
                PLUGINS_TO_VALIDATE+=("$arg")
            else
                # Directory containing plugins
                while IFS= read -r -d '' dir; do
                    if [[ -f "$dir/.claude-plugin/plugin.json" ]]; then
                        PLUGINS_TO_VALIDATE+=("$dir")
                    fi
                done < <(find "$arg" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
            fi
        else
            # Try to resolve as plugin name
            if resolved=$(resolve_plugin_path "$arg"); then
                PLUGINS_TO_VALIDATE+=("$resolved")
            else
                print_error "Plugin not found: $arg"
                exit 1
            fi
        fi
    done
fi

# Validate all collected plugins
[[ "$QUIET" != "true" ]] && [[ "$JSON_MODE" != "true" ]] && print_section "Validating ${#PLUGINS_TO_VALIDATE[@]} plugin(s)"

SUCCESS_COUNT=0
FAILURE_COUNT=0

for plugin in "${PLUGINS_TO_VALIDATE[@]}"; do
    plugin_name=$(basename "$plugin")

    if validate_plugin "$plugin" "$QUIET"; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        if [[ "$JSON_MODE" == "true" ]]; then
            add_json_result "success" "Plugin validated: $plugin_name" "path: $plugin"
        fi
    else
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        if [[ "$JSON_MODE" == "true" ]]; then
            add_json_result "error" "Plugin validation failed: $plugin_name" "path: $plugin"
        fi
    fi
done

# Print summary
if [[ "$JSON_MODE" == "true" ]]; then
    print_json_output
else
    if [[ "$QUIET" != "true" ]]; then
        echo ""
        print_section "Summary"
        print_success "$SUCCESS_COUNT plugin(s) validated successfully"
        if [[ $FAILURE_COUNT -gt 0 ]]; then
            print_error "$FAILURE_COUNT plugin(s) failed validation"
        fi
    fi
fi

# Exit with appropriate code
if [[ $FAILURE_COUNT -gt 0 ]]; then
    exit 1
fi

exit 0
