#!/usr/bin/env bash
# atomic.sh - Atomic update helpers for safe file modifications

# Source dependencies
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/colors.sh"

# Create timestamped backup of a file
# Usage: backup_file file
# Returns: Path to backup file
backup_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        print_error "Cannot backup non-existent file: $file"
        return 1
    fi

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup="${file}.backup_${timestamp}"

    if cp "$file" "$backup"; then
        echo "$backup"
        return 0
    else
        print_error "Failed to create backup: $backup"
        return 1
    fi
}

# Restore file from backup
# Usage: restore_backup backup_file
restore_backup() {
    local backup="$1"

    if [[ ! -f "$backup" ]]; then
        print_error "Backup file does not exist: $backup"
        return 1
    fi

    local original="${backup%.backup_*}"

    if cp "$backup" "$original"; then
        print_success "Restored from backup: $original"
        return 0
    else
        print_error "Failed to restore from backup: $backup"
        return 1
    fi
}

# Remove backup file
# Usage: remove_backup backup_file
remove_backup() {
    local backup="$1"

    if [[ ! -f "$backup" ]]; then
        return 0
    fi

    if rm "$backup"; then
        return 0
    else
        print_warning "Failed to remove backup: $backup"
        return 1
    fi
}

# Add plugin to marketplace.json using jq
# Usage: add_plugin_to_marketplace marketplace_json source name keywords
add_plugin_to_marketplace() {
    local marketplace="$1"
    local source="$2"
    local name="$3"
    local keywords="${4:-[]}"

    if [[ ! -f "$marketplace" ]]; then
        print_error "Marketplace file does not exist: $marketplace"
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        print_error "jq is required but not installed"
        return 1
    fi

    # Create plugin entry matching existing marketplace schema
    local plugin_entry
    plugin_entry=$(jq -n \
        --arg name "$name" \
        --arg source "$source" \
        --argjson tags "$keywords" \
        '{
            name: $name,
            source: $source,
            tags: $tags
        }')

    # Add to marketplace
    local temp_file="${marketplace}.tmp"
    if jq --argjson plugin "$plugin_entry" '.plugins += [$plugin]' "$marketplace" > "$temp_file"; then
        mv "$temp_file" "$marketplace"
        return 0
    else
        print_error "Failed to add plugin to marketplace"
        rm -f "$temp_file"
        return 1
    fi
}

# Bump marketplace minor version (0.1.0 -> 0.2.0)
# Usage: bump_marketplace_minor_version marketplace_json
bump_marketplace_minor_version() {
    local marketplace="$1"

    if [[ ! -f "$marketplace" ]]; then
        print_error "Marketplace file does not exist: $marketplace"
        return 1
    fi

    local temp_file="${marketplace}.tmp"
    if jq '.version |= (split(".") | .[1] = (.[1] | tonumber + 1 | tostring) | .[2] = "0" | join("."))' "$marketplace" > "$temp_file"; then
        mv "$temp_file" "$marketplace"
        return 0
    else
        print_error "Failed to bump marketplace version"
        rm -f "$temp_file"
        return 1
    fi
}

# Check if plugin exists in marketplace by name
# Usage: plugin_exists_in_marketplace marketplace_json name
# Returns: 0 if exists, 1 if not
plugin_exists_in_marketplace() {
    local marketplace="$1"
    local name="$2"

    if [[ ! -f "$marketplace" ]]; then
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        return 1
    fi

    local count
    count=$(jq --arg name "$name" '[.plugins[] | select(.name == $name)] | length' "$marketplace")

    if [[ "$count" -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Generate unique plugin name if conflict exists
# Usage: generate_unique_plugin_name marketplace_json base_name
# Returns: Unique plugin name
generate_unique_plugin_name() {
    local marketplace="$1"
    local base_name="$2"

    if ! plugin_exists_in_marketplace "$marketplace" "$base_name"; then
        echo "$base_name"
        return 0
    fi

    local counter=1
    while true; do
        local candidate="${base_name}-${counter}"
        if ! plugin_exists_in_marketplace "$marketplace" "$candidate"; then
            echo "$candidate"
            return 0
        fi
        ((counter++))
    done
}
