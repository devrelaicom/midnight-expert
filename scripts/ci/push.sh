#!/usr/bin/env bash
# push.sh - Pre-push comprehensive validation

set -euo pipefail

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/colors.sh"

print_section "Pre-push validation"
print_info "Validating all plugins and marketplace..."

# Run comprehensive validation
if ! "$SCRIPT_DIR/../validate-marketplace.sh"; then
    echo ""
    print_error "Pre-push validation failed"
    print_info "Fix the issues above or use 'git push --no-verify' to bypass"
    exit 1
fi

print_success "Pre-push validation passed"
exit 0
