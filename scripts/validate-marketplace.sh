#!/usr/bin/env bash
# validate-marketplace.sh - Validate marketplace.json and check completeness

set -euo pipefail

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/json.sh"
source "$SCRIPT_DIR/lib/validation.sh"

# Default values
MARKETPLACE_JSON=".claude-plugin/marketplace.json"
PLUGINS_DIR="./plugins"
SKIP_PLUGINS=false

# Usage information
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Validate marketplace.json and check completeness

Options:
  --marketplace PATH   Path to marketplace.json (default: .claude-plugin/marketplace.json)
  --plugins PATH       Path to plugins directory (default: ./plugins)
  --json              Output machine-readable JSON
  --skip-plugins      Don't validate individual plugins
  --help              Show this help message

Examples:
  $(basename "$0")                                    # Validate marketplace
  $(basename "$0") --skip-plugins                     # Skip plugin validation
  $(basename "$0") --marketplace /path/to/marketplace.json
  $(basename "$0") --json                             # JSON output

EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --marketplace)
            MARKETPLACE_JSON="$2"
            shift 2
            ;;
        --plugins)
            PLUGINS_DIR="$2"
            shift 2
            ;;
        --json)
            enable_json_mode
            shift
            ;;
        --skip-plugins)
            SKIP_PLUGINS=true
            shift
            ;;
        --help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Validation results
HAS_ERRORS=false

# Step 1: Validate marketplace.json
[[ "$JSON_MODE" != "true" ]] && print_section "Validating marketplace.json"

if validate_marketplace "$MARKETPLACE_JSON" false; then
    [[ "$JSON_MODE" == "true" ]] && add_json_result "success" "Marketplace validated" "path: $MARKETPLACE_JSON"
else
    HAS_ERRORS=true
    [[ "$JSON_MODE" == "true" ]] && add_json_result "error" "Marketplace validation failed" "path: $MARKETPLACE_JSON"
fi

# Step 2: Check completeness
[[ "$JSON_MODE" != "true" ]] && print_section "Checking completeness"

if check_all_plugins_listed "$MARKETPLACE_JSON" "$PLUGINS_DIR" false; then
    [[ "$JSON_MODE" == "true" ]] && add_json_result "success" "All plugins listed correctly" ""
else
    HAS_ERRORS=true
    [[ "$JSON_MODE" == "true" ]] && add_json_result "warning" "Plugin listing discrepancies found" ""
fi

# Step 3: Validate individual plugins (unless skipped)
if [[ "$SKIP_PLUGINS" != "true" ]]; then
    [[ "$JSON_MODE" != "true" ]] && print_section "Validating individual plugins"

    # Get list of plugins from marketplace.json
    if ! command -v jq >/dev/null 2>&1; then
        print_error "jq is required but not installed"
        exit 1
    fi

    PLUGIN_COUNT=0
    PLUGIN_SUCCESS=0
    PLUGIN_FAILURES=0

    while IFS= read -r plugin_source; do
        [[ -z "$plugin_source" ]] && continue
        PLUGIN_COUNT=$((PLUGIN_COUNT + 1))
        plugin_path="$plugin_source"

        # Make path absolute if relative and normalize (remove ./ prefix)
        if [[ ! "$plugin_path" = /* ]]; then
            plugin_path="${plugin_path#./}"
            plugin_path="$(pwd)/$plugin_path"
        fi

        plugin_name=$(basename "$plugin_path")

        if validate_plugin "$plugin_path" false; then
            PLUGIN_SUCCESS=$((PLUGIN_SUCCESS + 1))
            [[ "$JSON_MODE" == "true" ]] && add_json_result "success" "Plugin validated: $plugin_name" "path: $plugin_path"
        else
            PLUGIN_FAILURES=$((PLUGIN_FAILURES + 1))
            HAS_ERRORS=true
            [[ "$JSON_MODE" == "true" ]] && add_json_result "error" "Plugin validation failed: $plugin_name" "path: $plugin_path"
        fi
    done < <(jq -r '.plugins[]? | .source // .path // empty' "$MARKETPLACE_JSON" 2>/dev/null)

    # Print plugin validation summary
    if [[ "$JSON_MODE" != "true" ]]; then
        echo ""
        print_info "Validated $PLUGIN_COUNT plugin(s): $PLUGIN_SUCCESS succeeded, $PLUGIN_FAILURES failed"
    fi
fi

# Print final summary
if [[ "$JSON_MODE" == "true" ]]; then
    print_json_output
else
    echo ""
    print_section "Summary"
    if [[ "$HAS_ERRORS" == "true" ]]; then
        print_error "Marketplace validation completed with errors"
        exit 1
    else
        print_success "Marketplace validation completed successfully"
        exit 0
    fi
fi

# Exit with appropriate code
if [[ "$HAS_ERRORS" == "true" ]]; then
    exit 1
fi

exit 0
