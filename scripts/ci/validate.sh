#!/usr/bin/env bash
# validate.sh - Lightweight CI validation (no Claude CLI dependency)

set -euo pipefail

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"
source "$SCRIPT_DIR/../lib/json.sh"

# Default values
MARKETPLACE_JSON=".claude-plugin/marketplace.json"
PLUGINS_DIR="./plugins"

# Check for jq dependency
if ! command -v jq >/dev/null 2>&1; then
    print_error "jq is required but not installed"
    echo "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

# Validate JSON syntax
validate_json_syntax() {
    local file="$1"
    local name="$2"

    if ! jq empty "$file" >/dev/null 2>&1; then
        print_error "Invalid JSON syntax in $name: $file"
        return 1
    fi
    return 0
}

# Check if array contains element
array_contains() {
    local needle="$1"
    shift
    local element
    for element in "$@"; do
        [[ "$element" == "$needle" ]] && return 0
    done
    return 1
}

# Validation tracking
HAS_ERRORS=false

print_section "Validating marketplace.json"

# Check marketplace.json exists
if [[ ! -f "$MARKETPLACE_JSON" ]]; then
    print_error "Marketplace file not found: $MARKETPLACE_JSON"
    exit 1
fi

# Validate JSON syntax
if ! validate_json_syntax "$MARKETPLACE_JSON" "marketplace.json"; then
    HAS_ERRORS=true
fi

# Check required fields
if ! jq -e '.plugins' "$MARKETPLACE_JSON" >/dev/null 2>&1; then
    print_error "marketplace.json missing required field: plugins"
    HAS_ERRORS=true
fi

print_section "Checking plugin completeness"

# Get plugins from filesystem
FILESYSTEM_PLUGINS=()
if [[ -d "$PLUGINS_DIR" ]]; then
    while IFS= read -r -d '' dir; do
        plugin_name=$(basename "$dir")
        FILESYSTEM_PLUGINS+=("$plugin_name")
    done < <(find "$PLUGINS_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
fi

# Get plugins from marketplace.json
MARKETPLACE_PLUGINS=()
while IFS= read -r source; do
    [[ -z "$source" ]] && continue
    plugin_name=$(basename "$source")
    MARKETPLACE_PLUGINS+=("$plugin_name")
done < <(jq -r '.plugins[]?.source // empty' "$MARKETPLACE_JSON" 2>/dev/null)

# Check for missing plugins (in filesystem but not marketplace)
if [[ ${#FILESYSTEM_PLUGINS[@]} -gt 0 ]]; then
    for plugin in "${FILESYSTEM_PLUGINS[@]}"; do
        if ! array_contains "$plugin" "${MARKETPLACE_PLUGINS[@]}"; then
            print_error "Plugin exists in filesystem but not listed in marketplace: $plugin"
            HAS_ERRORS=true
        fi
    done
fi

# Check for extra plugins (in marketplace but not filesystem)
if [[ ${#MARKETPLACE_PLUGINS[@]} -gt 0 ]]; then
    for plugin in "${MARKETPLACE_PLUGINS[@]}"; do
        if ! array_contains "$plugin" "${FILESYSTEM_PLUGINS[@]}"; then
            print_error "Plugin listed in marketplace but not found in filesystem: $plugin"
            HAS_ERRORS=true
        fi
    done
fi

print_section "Validating plugin structure"

SUCCESS_COUNT=0
FAILURE_COUNT=0

if [[ ${#FILESYSTEM_PLUGINS[@]} -gt 0 ]]; then
    for plugin_name in "${FILESYSTEM_PLUGINS[@]}"; do
        plugin_path="$PLUGINS_DIR/$plugin_name"
        plugin_json="$plugin_path/.claude-plugin/plugin.json"

        # Check .claude-plugin directory exists
        if [[ ! -d "$plugin_path/.claude-plugin" ]]; then
            print_error "Plugin missing .claude-plugin directory: $plugin_name"
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
            HAS_ERRORS=true
            continue
        fi

        # Check plugin.json exists
        if [[ ! -f "$plugin_json" ]]; then
            print_error "Plugin missing plugin.json: $plugin_name"
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
            HAS_ERRORS=true
            continue
        fi

        # Validate JSON syntax
        if ! validate_json_syntax "$plugin_json" "$plugin_name/plugin.json"; then
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
            HAS_ERRORS=true
            continue
        fi

        # Check required fields
        missing_fields=()
        if ! jq -e '.name' "$plugin_json" >/dev/null 2>&1 || [[ $(jq -r '.name' "$plugin_json") == "null" ]]; then
            missing_fields+=("name")
        fi
        if ! jq -e '.version' "$plugin_json" >/dev/null 2>&1 || [[ $(jq -r '.version' "$plugin_json") == "null" ]]; then
            missing_fields+=("version")
        fi
        if ! jq -e '.description' "$plugin_json" >/dev/null 2>&1 || [[ $(jq -r '.description' "$plugin_json") == "null" ]]; then
            missing_fields+=("description")
        fi

        if [[ ${#missing_fields[@]} -gt 0 ]]; then
            print_error "Plugin $plugin_name missing required fields: ${missing_fields[*]}"
            FAILURE_COUNT=$((FAILURE_COUNT + 1))
            HAS_ERRORS=true
            continue
        fi

        print_success "Plugin validated: $plugin_name"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    done
fi

# Print summary
echo ""
print_section "Summary"
print_info "Validated ${#FILESYSTEM_PLUGINS[@]} plugin(s): $SUCCESS_COUNT succeeded, $FAILURE_COUNT failed"

if [[ "$HAS_ERRORS" == "true" ]]; then
    print_error "Validation completed with errors"
    exit 1
else
    print_success "All validation checks passed"
    exit 0
fi
