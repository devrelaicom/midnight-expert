#!/usr/bin/env bash
# commit.sh - Pre-commit validation for changed plugins

set -euo pipefail

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"

# Check if array contains element
contains_element() {
    local element="$1"
    shift
    local item
    for item in "$@"; do
        [[ "$item" == "$element" ]] && return 0
    done
    return 1
}

print_section "Pre-commit validation"

# Get staged files
STAGED_FILES=$(git diff --cached --name-only)

if [[ -z "$STAGED_FILES" ]]; then
    print_info "No staged changes detected"
    exit 0
fi

# Extract unique plugin names from staged files
PLUGINS=()
while IFS= read -r file; do
    if [[ "$file" =~ ^plugins/([^/]+)/ ]]; then
        plugin="${BASH_REMATCH[1]}"
        # Add to array if not already present
        if ! contains_element "$plugin" "${PLUGINS[@]:-}"; then
            PLUGINS+=("$plugin")
        fi
    fi
done <<< "$STAGED_FILES"

# Validate changed plugins
VALIDATION_FAILED=false

if [[ ${#PLUGINS[@]} -gt 0 ]]; then
    print_info "Validating ${#PLUGINS[@]} plugin(s) with changes: ${PLUGINS[*]}"

    for plugin in "${PLUGINS[@]}"; do
        print_info "Validating plugin: $plugin"
        if ! "$SCRIPT_DIR/../validate-plugin.sh" "$plugin" --quiet; then
            print_error "Validation failed for plugin: $plugin"
            VALIDATION_FAILED=true
        fi
    done
else
    print_info "No plugin changes detected"
fi

# Check if marketplace.json is staged
if echo "$STAGED_FILES" | grep -q "^\.claude-plugin/marketplace\.json$"; then
    print_info "Validating marketplace.json"
    if ! "$SCRIPT_DIR/../validate-marketplace.sh" --skip-plugins; then
        print_error "Marketplace validation failed"
        VALIDATION_FAILED=true
    fi
fi

# Exit with appropriate code
if [[ "$VALIDATION_FAILED" == "true" ]]; then
    echo ""
    print_error "Pre-commit validation failed"
    print_info "Fix the issues above or use 'git commit --no-verify' to bypass"
    exit 1
fi

print_success "Pre-commit validation passed"
exit 0
