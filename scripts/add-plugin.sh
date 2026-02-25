#!/usr/bin/env bash
# add-plugin.sh - Add new plugin(s) to marketplace with validation and conflict resolution

set -euo pipefail

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/json.sh"
source "$SCRIPT_DIR/lib/validation.sh"
source "$SCRIPT_DIR/lib/atomic.sh"

# Default values
MARKETPLACE_JSON=".claude-plugin/marketplace.json"
ON_CONFLICT="abort"
SKIP_VALIDATION=false
DRY_RUN=false
COPY_EXTERNAL=true

# Usage information
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <PLUGIN...>

Add new plugin(s) to marketplace with validation and conflict resolution

Arguments:
  PLUGIN... (required)   One or more plugin paths or names

Options:
  --marketplace PATH      Path to marketplace.json (default: .claude-plugin/marketplace.json)
  --on-conflict ACTION    Conflict resolution: abort|skip|replace|rename (default: abort)
  --skip-validation      Skip validation before adding
  --dry-run              Show what would be done without changes
  --json                 Output machine-readable JSON
  --copy-external        Copy external plugins to ./plugins (default: true)
  --no-copy-external     Reference external plugins by path
  --help                 Show this help message

Conflict Resolution:
  abort    Stop if plugin name exists (default)
  skip     Skip conflicting plugins, continue with others
  replace  Replace existing plugin entry
  rename   Auto-generate unique name (plugin-1, plugin-2, ...)

Examples:
  $(basename "$0") /path/to/plugin                    # Add external plugin
  $(basename "$0") plugin1 plugin2                    # Add multiple plugins
  $(basename "$0") /path/to/plugin --dry-run          # Preview changes
  $(basename "$0") plugin --on-conflict=rename        # Rename if conflict

EOF
    exit 0
}

# Parse command line arguments
PLUGIN_ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --marketplace)
            MARKETPLACE_JSON="$2"
            shift 2
            ;;
        --marketplace=*)
            MARKETPLACE_JSON="${1#*=}"
            shift
            ;;
        --on-conflict)
            ON_CONFLICT="$2"
            shift 2
            ;;
        --on-conflict=*)
            ON_CONFLICT="${1#*=}"
            shift
            ;;
        --skip-validation)
            SKIP_VALIDATION=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --json)
            enable_json_mode
            shift
            ;;
        --copy-external)
            COPY_EXTERNAL=true
            shift
            ;;
        --no-copy-external)
            COPY_EXTERNAL=false
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

# Validate required arguments
if [[ ${#PLUGIN_ARGS[@]} -eq 0 ]]; then
    print_error "At least one plugin argument is required"
    usage
fi

# Validate marketplace.json exists
if [[ ! -f "$MARKETPLACE_JSON" ]]; then
    print_error "Marketplace file not found: $MARKETPLACE_JSON"
    exit 1
fi

# Validate on-conflict option
if [[ ! "$ON_CONFLICT" =~ ^(abort|skip|replace|rename)$ ]]; then
    print_error "Invalid --on-conflict value: $ON_CONFLICT (must be: abort, skip, replace, or rename)"
    exit 1
fi

[[ "$JSON_MODE" != "true" ]] && print_section "Pre-flight Validation"

# Array to store plugin info
declare -A PLUGIN_PATHS
declare -A PLUGIN_NAMES
declare -A PLUGIN_METADATA
VALIDATION_ERRORS=()

# Phase 1: Pre-flight Validation
for plugin_arg in "${PLUGIN_ARGS[@]}"; do
    plugin_path=""

    # Resolve plugin path
    if [[ -d "$plugin_arg" ]]; then
        plugin_path="$plugin_arg"
    elif [[ -d "./plugins/$plugin_arg" ]]; then
        plugin_path="./plugins/$plugin_arg"
    else
        VALIDATION_ERRORS+=("Plugin not found: $plugin_arg")
        continue
    fi

    # Make path absolute
    plugin_path=$(cd "$plugin_path" && pwd)

    # Verify plugin.json exists
    if [[ ! -f "$plugin_path/.claude-plugin/plugin.json" ]]; then
        VALIDATION_ERRORS+=("Invalid plugin directory (missing plugin.json): $plugin_path")
        continue
    fi

    # Read plugin metadata
    if ! command -v jq >/dev/null 2>&1; then
        print_error "jq is required but not installed"
        exit 1
    fi

    plugin_name=$(jq -r '.name' "$plugin_path/.claude-plugin/plugin.json" 2>/dev/null)
    if [[ -z "$plugin_name" || "$plugin_name" == "null" ]]; then
        VALIDATION_ERRORS+=("Plugin has no name in plugin.json: $plugin_path")
        continue
    fi

    # Store plugin info
    PLUGIN_PATHS["$plugin_name"]="$plugin_path"
    PLUGIN_NAMES["$plugin_name"]="$plugin_name"

    # Read full metadata
    plugin_version=$(jq -r '.version // "0.1.0"' "$plugin_path/.claude-plugin/plugin.json" 2>/dev/null)
    plugin_description=$(jq -r '.description // ""' "$plugin_path/.claude-plugin/plugin.json" 2>/dev/null)
    plugin_keywords=$(jq -r '.keywords // [] | @json' "$plugin_path/.claude-plugin/plugin.json" 2>/dev/null)

    PLUGIN_METADATA["$plugin_name"]="$plugin_version|$plugin_description|$plugin_keywords"

    # Validate plugin with claude CLI (unless --skip-validation)
    if [[ "$SKIP_VALIDATION" != "true" ]]; then
        if ! validate_plugin "$plugin_path" true; then
            VALIDATION_ERRORS+=("Plugin validation failed: $plugin_name ($plugin_path)")
        else
            [[ "$JSON_MODE" != "true" ]] && print_success "Pre-validated: $plugin_name"
        fi
    fi

    # Check for name conflicts
    if plugin_exists_in_marketplace "$MARKETPLACE_JSON" "$plugin_name"; then
        case "$ON_CONFLICT" in
            abort)
                VALIDATION_ERRORS+=("Plugin already exists in marketplace: $plugin_name (use --on-conflict to handle)")
                ;;
            skip)
                [[ "$JSON_MODE" != "true" ]] && print_warning "Will skip conflicting plugin: $plugin_name"
                unset PLUGIN_PATHS["$plugin_name"]
                unset PLUGIN_NAMES["$plugin_name"]
                unset PLUGIN_METADATA["$plugin_name"]
                ;;
            replace)
                [[ "$JSON_MODE" != "true" ]] && print_warning "Will replace existing plugin: $plugin_name"
                ;;
            rename)
                new_name=$(generate_unique_plugin_name "$MARKETPLACE_JSON" "$plugin_name")
                [[ "$JSON_MODE" != "true" ]] && print_warning "Will rename $plugin_name -> $new_name"
                # Update the name
                PLUGIN_NAMES["$plugin_name"]="$new_name"
                ;;
        esac
    fi
done

# Stop if ANY errors during pre-flight
ERROR_COUNT=${#VALIDATION_ERRORS[@]}
if [[ $ERROR_COUNT -gt 0 ]]; then
    [[ "$JSON_MODE" != "true" ]] && print_section "Validation Errors"
    for error in "${VALIDATION_ERRORS[@]}"; do
        if [[ "$JSON_MODE" == "true" ]]; then
            add_json_result "error" "$error" ""
        else
            print_error "$error"
        fi
    done

    if [[ "$JSON_MODE" == "true" ]]; then
        print_json_output
    fi

    exit 1
fi

# Check if any plugins remain after conflict resolution
if [[ ${#PLUGIN_PATHS[@]} -eq 0 ]]; then
    [[ "$JSON_MODE" != "true" ]] && print_warning "No plugins to add after conflict resolution"
    exit 0
fi

# Phase 2: Determine source paths and copy operations
[[ "$JSON_MODE" != "true" ]] && print_section "Planning Operations"

declare -A PLUGIN_SOURCES
PROJECT_ROOT=$(cd "$(dirname "$MARKETPLACE_JSON")/.." && pwd)

for plugin_name in "${!PLUGIN_PATHS[@]}"; do
    plugin_path="${PLUGIN_PATHS[$plugin_name]}"
    final_name="${PLUGIN_NAMES[$plugin_name]}"

    # Check if plugin is already inside project
    if [[ "$plugin_path" == "$PROJECT_ROOT/plugins/"* ]]; then
        # Internal plugin - use relative path
        rel_path="./plugins/$(basename "$plugin_path")"
        PLUGIN_SOURCES["$plugin_name"]="$rel_path"
        [[ "$JSON_MODE" != "true" ]] && print_info "Internal plugin: $final_name -> $rel_path"
    else
        # External plugin
        if [[ "$COPY_EXTERNAL" == "true" ]]; then
            # Will copy to ./plugins
            target_dir="$PROJECT_ROOT/plugins/$final_name"
            rel_path="./plugins/$final_name"
            PLUGIN_SOURCES["$plugin_name"]="$rel_path|COPY|$target_dir"
            [[ "$JSON_MODE" != "true" ]] && print_info "Will copy: $final_name -> $target_dir"
        else
            # Reference by absolute path
            PLUGIN_SOURCES["$plugin_name"]="$plugin_path"
            [[ "$JSON_MODE" != "true" ]] && print_info "External plugin: $final_name -> $plugin_path"
        fi
    fi
done

# Phase 3: Dry run report
if [[ "$DRY_RUN" == "true" ]]; then
    [[ "$JSON_MODE" != "true" ]] && print_section "Dry Run - Planned Actions"

    for plugin_name in "${!PLUGIN_PATHS[@]}"; do
        plugin_path="${PLUGIN_PATHS[$plugin_name]}"
        final_name="${PLUGIN_NAMES[$plugin_name]}"
        source_info="${PLUGIN_SOURCES[$plugin_name]}"

        if [[ "$JSON_MODE" == "true" ]]; then
            add_json_result "info" "Would add plugin: $final_name" "source: ${source_info%%|*}"
        else
            echo ""
            print_info "Plugin: $final_name"
            echo "  Original name: $plugin_name"
            echo "  Source path: $plugin_path"
            echo "  Marketplace source: ${source_info%%|*}"

            if [[ "$source_info" == *"|COPY|"* ]]; then
                echo "  Action: Copy to project"
            fi
        fi
    done

    if [[ "$JSON_MODE" == "true" ]]; then
        print_json_output
    else
        echo ""
        print_warning "Dry run mode - no changes made"
    fi
    exit 0
fi

# Phase 4: Execute copy operations
[[ "$JSON_MODE" != "true" ]] && print_section "Copying Plugins"

for plugin_name in "${!PLUGIN_SOURCES[@]}"; do
    source_info="${PLUGIN_SOURCES[$plugin_name]}"

    if [[ "$source_info" == *"|COPY|"* ]]; then
        IFS='|' read -r rel_path action target_dir <<< "$source_info"
        plugin_path="${PLUGIN_PATHS[$plugin_name]}"

        [[ "$JSON_MODE" != "true" ]] && print_info "Copying $plugin_name to $target_dir"

        if [[ -d "$target_dir" ]]; then
            print_error "Target directory already exists: $target_dir"
            exit 1
        fi

        if ! cp -r "$plugin_path" "$target_dir"; then
            print_error "Failed to copy plugin: $plugin_name"
            exit 1
        fi

        # Update source info to just the relative path
        PLUGIN_SOURCES["$plugin_name"]="$rel_path"
    fi
done

# Phase 5: Atomic marketplace updates
[[ "$JSON_MODE" != "true" ]] && print_section "Updating Marketplace"

# Create backup
backup_path=$(backup_file "$MARKETPLACE_JSON")
if [[ -z "$backup_path" ]]; then
    print_error "Failed to create backup of marketplace.json"
    exit 1
fi

[[ "$JSON_MODE" != "true" ]] && print_info "Created backup: $backup_path"

# Track success
UPDATE_FAILED=false

# Add/update each plugin
for plugin_name in "${!PLUGIN_PATHS[@]}"; do
    final_name="${PLUGIN_NAMES[$plugin_name]}"
    source_path="${PLUGIN_SOURCES[$plugin_name]}"
    metadata="${PLUGIN_METADATA[$plugin_name]}"

    IFS='|' read -r version description keywords <<< "$metadata"

    [[ "$JSON_MODE" != "true" ]] && print_info "Adding $final_name to marketplace"

    # If replacing, remove old entry first
    if [[ "$ON_CONFLICT" == "replace" ]] && plugin_exists_in_marketplace "$MARKETPLACE_JSON" "$final_name"; then
        temp_file="${MARKETPLACE_JSON}.tmp"
        if ! jq --arg name "$final_name" 'del(.plugins[] | select(.name == $name))' "$MARKETPLACE_JSON" > "$temp_file"; then
            print_error "Failed to remove existing plugin entry: $final_name"
            UPDATE_FAILED=true
            break
        fi
        mv "$temp_file" "$MARKETPLACE_JSON"
    fi

    # Add plugin entry
    if ! add_plugin_to_marketplace "$MARKETPLACE_JSON" "$source_path" "$final_name" "$description" "$version" "$keywords"; then
        print_error "Failed to add plugin to marketplace: $final_name"
        UPDATE_FAILED=true
        break
    fi

    # Validate marketplace after each addition
    if ! validate_marketplace "$MARKETPLACE_JSON" true; then
        print_error "Marketplace validation failed after adding: $final_name"
        UPDATE_FAILED=true
        break
    fi

    [[ "$JSON_MODE" != "true" ]] && print_success "Added: $final_name"
    [[ "$JSON_MODE" == "true" ]] && add_json_result "success" "Added plugin: $final_name" "source: $source_path"
done

# Handle failures with rollback
if [[ "$UPDATE_FAILED" == "true" ]]; then
    [[ "$JSON_MODE" != "true" ]] && print_section "Rolling Back Changes"

    if restore_backup "$backup_path"; then
        print_error "Marketplace update failed - changes rolled back"
        remove_backup "$backup_path"
    else
        print_error "Marketplace update failed AND rollback failed - backup at: $backup_path"
    fi

    if [[ "$JSON_MODE" == "true" ]]; then
        add_json_result "error" "Update failed - rolled back changes" ""
        print_json_output
    fi

    exit 1
fi

# Phase 6: Final validation
[[ "$JSON_MODE" != "true" ]] && print_section "Final Validation"

if ! validate_marketplace "$MARKETPLACE_JSON" true; then
    print_error "Final marketplace validation failed"
    restore_backup "$backup_path"
    remove_backup "$backup_path"
    exit 1
fi

# Remove backup on success
remove_backup "$backup_path"

# Print summary
if [[ "$JSON_MODE" == "true" ]]; then
    print_json_output
else
    print_section "Summary"
    print_success "Successfully added ${#PLUGIN_PATHS[@]} plugin(s) to marketplace"
fi

exit 0
