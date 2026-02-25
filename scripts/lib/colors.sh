#!/usr/bin/env bash
# colors.sh - Color definitions and output helpers

# Color constants
RED='\033[0;31m'
GREEN='\033[0;32m'
DIM_GREEN='\033[2;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print error message in red
print_error() {
    echo -e "${RED}ERROR: $*${NC}" >&2
}

# Print success message in green
print_success() {
    echo -e "${GREEN}✓ $*${NC}"
}

# Print sub-success message in dim green (for nested/detail items)
print_success_dim() {
    echo -e "${DIM_GREEN}✓ $*${NC}"
}

# Print warning message in yellow
print_warning() {
    echo -e "${YELLOW}WARNING: $*${NC}" >&2
}

# Print info message in blue
print_info() {
    echo -e "${BLUE}INFO: $*${NC}"
}

# Print section header in cyan
print_section() {
    echo -e "\n${CYAN}=== $* ===${NC}"
}
