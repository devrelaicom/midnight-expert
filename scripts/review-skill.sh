#!/usr/bin/env bash
# review-skill.sh - Deep review of skill(s) within a plugin using Claude CLI with plugin-dev skills

set -euo pipefail

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/marketplace.sh"

# Default values
OUTPUT_DIR=""
INCLUDE_JSON=false
FORMAT="markdown"
MARKETPLACE_JSON="./.claude-plugin/marketplace.json"

# Usage information
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <PLUGIN> [SKILL[,SKILL,...]]

Deep review of skill(s) within a plugin using Claude CLI with plugin-dev skills

Arguments:
  PLUGIN (required)   Plugin name, directory name, or path
  SKILL  (optional)   Skill name(s), directory name(s), or path(s)
                      Multiple skills can be comma-separated

If SKILL is omitted, an interactive menu of available skills is shown.

Plugin resolution (tried in order):
  1. Direct path (absolute or relative directory)
  2. Directory name under ./plugins/
  3. Plugin name from marketplace.json plugins array

Skill resolution (tried in order):
  1. Direct path (absolute or relative directory containing SKILL.md)
  2. Directory name under <plugin>/skills/
  3. Skill name from SKILL.md frontmatter

Options:
  --output PATH       Output directory for reports (default: ./reviews/{plugin}/{skill})
  --json              Include JSON output alongside markdown
  --format FORMAT     Report format: markdown, html, pdf (default: markdown)
  --help              Show this help message

Examples:
  $(basename "$0") midnight-tooling troubleshooting
  $(basename "$0") compact-dev compact-core,contract-patterns
  $(basename "$0") midnight-tooling                          # interactive menu
  $(basename "$0") /path/to/plugin proof-server
  $(basename "$0") midnight-tooling troubleshooting --json

EOF
    exit 0
}

# --- Resolution helpers ---

# Initialize marketplace configuration (resolves pluginRoot)
init_marketplace_config "$MARKETPLACE_JSON" 2>/dev/null || true

# Resolve a plugin argument to a directory path.
# Tries: direct path, pluginRoot/<name>, marketplace.json name lookup.
resolve_plugin() {
    local arg="$1"

    # 1. Direct path
    if [[ -d "$arg" && -f "$arg/.claude-plugin/plugin.json" ]]; then
        echo "$arg"
        return 0
    fi

    # 2. Directory name under pluginRoot
    if [[ -d "$PLUGIN_ROOT_ABS/$arg" && -f "$PLUGIN_ROOT_ABS/$arg/.claude-plugin/plugin.json" ]]; then
        echo "$PLUGIN_ROOT_ABS/$arg"
        return 0
    fi

    # 3. Marketplace.json lookup by plugin name
    if [[ -f "$MARKETPLACE_JSON" ]]; then
        local entry
        entry=$(jq -r --arg name "$arg" '
            .plugins[]
            | if type == "string" then . else .name // empty end
            | select(. == $name)
        ' "$MARKETPLACE_JSON" 2>/dev/null | head -1)

        if [[ -n "$entry" ]]; then
            # The marketplace name might differ from the directory name.
            # Search pluginRoot for a plugin whose plugin.json "name" matches.
            local dir
            for dir in "$PLUGIN_ROOT_ABS"/*/; do
                if [[ -f "$dir/.claude-plugin/plugin.json" ]]; then
                    local pname
                    pname=$(jq -r '.name // empty' "$dir/.claude-plugin/plugin.json" 2>/dev/null)
                    if [[ "$pname" == "$arg" ]]; then
                        echo "$dir"
                        return 0
                    fi
                fi
            done
        fi
    fi

    return 1
}

# Resolve a skill argument to a directory path within a plugin.
# Tries: direct path, <plugin>/skills/<name>, SKILL.md frontmatter name match.
resolve_skill() {
    local plugin_path="$1"
    local arg="$2"

    # 1. Direct path
    if [[ -d "$arg" && -f "$arg/SKILL.md" ]]; then
        echo "$arg"
        return 0
    fi

    # 2. Directory name under <plugin>/skills/
    if [[ -d "$plugin_path/skills/$arg" && -f "$plugin_path/skills/$arg/SKILL.md" ]]; then
        echo "$plugin_path/skills/$arg"
        return 0
    fi

    # 3. Match by frontmatter name in any SKILL.md under the plugin
    local skill_dir
    for skill_dir in "$plugin_path"/skills/*/; do
        if [[ -f "$skill_dir/SKILL.md" ]]; then
            local fname
            fname=$(awk '/^---$/{if(f){exit}else{f=1;next}} f && /^name:/{sub(/^name:[[:space:]]*/, ""); print; exit}' "$skill_dir/SKILL.md")
            if [[ "$fname" == "$arg" ]]; then
                echo "$skill_dir"
                return 0
            fi
        fi
    done

    return 1
}

# List all skills in a plugin and return an array of (dir, name) pairs.
# Prints a numbered menu to stdout.
list_skills() {
    local plugin_path="$1"
    local i=1

    SKILL_DIRS=()
    SKILL_NAMES=()

    for skill_dir in "$plugin_path"/skills/*/; do
        [[ -f "$skill_dir/SKILL.md" ]] || continue
        local dname fname
        dname=$(basename "$skill_dir")
        fname=$(awk '/^---$/{if(f){exit}else{f=1;next}} f && /^name:/{sub(/^name:[[:space:]]*/, ""); print; exit}' "$skill_dir/SKILL.md")
        local display_name="${fname:-$dname}"

        SKILL_DIRS+=("$skill_dir")
        SKILL_NAMES+=("$display_name")
        printf "  %d) %s\n" "$i" "$display_name"
        ((i++))
    done

    if [[ ${#SKILL_DIRS[@]} -eq 0 ]]; then
        print_error "No skills found in plugin at: $plugin_path"
        exit 1
    fi

    printf "  %d) all\n" "$i"
}

# Parse a selection string like "1,2,3,9" or "1-3,9" into indices (0-based).
# Validates that indices are in range.
parse_selection() {
    local input="$1"
    local max="$2"
    SELECTED_INDICES=()

    # Split on commas
    IFS=',' read -ra parts <<< "$input"
    for part in "${parts[@]}"; do
        part=$(echo "$part" | tr -d '[:space:]')
        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local start="${BASH_REMATCH[1]}"
            local end="${BASH_REMATCH[2]}"
            if (( start < 1 || end > max || start > end )); then
                print_error "Invalid range: $part (valid: 1-$max)"
                return 1
            fi
            for (( j=start; j<=end; j++ )); do
                SELECTED_INDICES+=($((j - 1)))
            done
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            local num="$part"
            if (( num < 1 || num > max + 1 )); then
                print_error "Invalid number: $num (valid: 1-$((max + 1)))"
                return 1
            fi
            if (( num == max + 1 )); then
                # "all" option
                SELECTED_INDICES=()
                for (( j=0; j<max; j++ )); do
                    SELECTED_INDICES+=("$j")
                done
                return 0
            fi
            SELECTED_INDICES+=($((num - 1)))
        else
            print_error "Invalid selection: $part"
            return 1
        fi
    done

    # Deduplicate
    SELECTED_INDICES=($(printf '%s\n' "${SELECTED_INDICES[@]}" | sort -un))
}

# --- Review a single skill ---
review_skill() {
    local skill_path="$1"
    local plugin_name="$2"
    local output_base="$3"

    local skill_path_abs
    skill_path_abs=$(cd "$skill_path" && pwd)
    local skill_name
    skill_name=$(basename "$skill_path_abs")

    local skill_output_dir="$output_base/$skill_name"
    mkdir -p "$skill_output_dir"
    local skill_output_dir_abs
    skill_output_dir_abs=$(cd "$skill_output_dir" && pwd)

    print_section "Reviewing skill: $plugin_name/$skill_name"
    print_info "Skill path: $skill_path_abs"
    print_info "Output: $skill_output_dir_abs"

    # Build review prompt
    local review_prompt
    review_prompt="Conduct a comprehensive review of the Claude Code skill located at: $skill_path_abs

Use the plugin-dev:skill-reviewer agent to perform a thorough analysis. Output ONLY the review report in markdown format with no preamble or explanatory text. Include these sections:

## Executive Summary
Brief overview of the skill, its purpose, and overall assessment.

## Skill Metadata
Assessment of SKILL.md frontmatter:
- Name: clarity, accuracy, and naming conventions
- Description: quality as a trigger for AI invocation (keywords, patterns, specificity)

## Content Quality
Review of the skill content:
- Completeness and accuracy of information
- Organization and structure
- Clarity of instructions and guidance
- Use of examples and references

## Reference Materials
Assessment of any files in references/ directory:
- Relevance and accuracy
- Organization and discoverability
- Coverage of the topic

## Recommendations
Specific, actionable recommendations organized by priority:
- Critical issues
- Suggested improvements
- Optional enhancements

Output the review now:"

    # Run Claude CLI
    print_info "Running Claude CLI review (this may take a few minutes)..."

    local temp_prompt temp_output
    temp_prompt=$(mktemp)
    temp_output=$(mktemp)
    echo "$review_prompt" > "$temp_prompt"

    if (cd "$skill_path_abs" && claude -p "$(cat "$temp_prompt")" > "$temp_output" 2>&1); then
        cp "$temp_output" "$skill_output_dir_abs/review-report.md"
        print_success "Review completed: $skill_output_dir_abs/review-report.md"
    else
        print_error "Review failed for skill: $skill_name"
        print_info "Output was:"
        cat "$temp_output"
        rm -f "$temp_prompt" "$temp_output"
        return 1
    fi

    rm -f "$temp_prompt" "$temp_output"

    # Generate JSON metadata if requested
    if [[ "$INCLUDE_JSON" == "true" ]]; then
        local json_output="$skill_output_dir_abs/review-metadata.json"
        cat > "$json_output" << EOJSON
{
  "plugin_name": "$plugin_name",
  "skill_name": "$skill_name",
  "skill_path": "$skill_path_abs",
  "review_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "report_format": "$FORMAT",
  "report_file": "$skill_output_dir_abs/review-report.md"
}
EOJSON
        print_success "Metadata saved: $json_output"
    fi
}

# --- Main ---

# Parse command line arguments
PLUGIN_ARG=""
SKILL_ARG=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --json)
            INCLUDE_JSON=true
            shift
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        -*)
            print_error "Unknown option: $1"
            exit 1
            ;;
        *)
            if [[ -z "$PLUGIN_ARG" ]]; then
                PLUGIN_ARG="$1"
            elif [[ -z "$SKILL_ARG" ]]; then
                SKILL_ARG="$1"
            else
                print_error "Unexpected argument: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate: plugin is required
if [[ -z "$PLUGIN_ARG" ]]; then
    print_error "Plugin argument is required"
    echo "" >&2
    echo "Usage: $(basename "$0") <PLUGIN> [SKILL[,SKILL,...]]" >&2
    echo "Run '$(basename "$0") --help' for more information." >&2
    exit 1
fi

# Resolve plugin
PLUGIN_PATH=""
if resolve_plugin "$PLUGIN_ARG" > /dev/null 2>&1; then
    PLUGIN_PATH=$(resolve_plugin "$PLUGIN_ARG")
else
    print_error "Plugin not found: $PLUGIN_ARG"
    exit 1
fi

PLUGIN_PATH_ABS=$(cd "$PLUGIN_PATH" && pwd)
PLUGIN_NAME=$(basename "$PLUGIN_PATH_ABS")

# Set default output directory
if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="./reviews/$PLUGIN_NAME"
fi

# Collect skill paths to review
SKILLS_TO_REVIEW=()

if [[ -z "$SKILL_ARG" ]]; then
    # Interactive mode: show menu and wait for selection
    print_section "Skills in plugin: $PLUGIN_NAME"
    list_skills "$PLUGIN_PATH_ABS"

    echo ""
    printf "Select skills to review (e.g. 1,3 or 1-3,5 or all): "
    read -r selection

    if [[ -z "$selection" ]]; then
        print_error "No selection made"
        exit 1
    fi

    # Handle "all" typed as text
    if [[ "$selection" == "all" ]]; then
        for dir in "${SKILL_DIRS[@]}"; do
            SKILLS_TO_REVIEW+=("$dir")
        done
    else
        if ! parse_selection "$selection" "${#SKILL_DIRS[@]}"; then
            exit 1
        fi
        for idx in "${SELECTED_INDICES[@]}"; do
            SKILLS_TO_REVIEW+=("${SKILL_DIRS[$idx]}")
        done
    fi
else
    # Resolve comma-separated skill arguments
    IFS=',' read -ra skill_parts <<< "$SKILL_ARG"
    for part in "${skill_parts[@]}"; do
        part=$(echo "$part" | tr -d '[:space:]')
        [[ -z "$part" ]] && continue
        local_skill_path=""
        if resolve_skill "$PLUGIN_PATH_ABS" "$part" > /dev/null 2>&1; then
            local_skill_path=$(resolve_skill "$PLUGIN_PATH_ABS" "$part")
            SKILLS_TO_REVIEW+=("$local_skill_path")
        else
            print_error "Skill not found: $part (in plugin $PLUGIN_NAME)"
            exit 1
        fi
    done
fi

if [[ ${#SKILLS_TO_REVIEW[@]} -eq 0 ]]; then
    print_error "No skills selected for review"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR_ABS=$(cd "$OUTPUT_DIR" && pwd)

print_section "Reviewing ${#SKILLS_TO_REVIEW[@]} skill(s) in plugin: $PLUGIN_NAME"
print_info "Plugin path: $PLUGIN_PATH_ABS"
print_info "Output directory: $OUTPUT_DIR_ABS"

# Review each skill
FAILED=0
SUCCEEDED=0
for skill_path in "${SKILLS_TO_REVIEW[@]}"; do
    if review_skill "$skill_path" "$PLUGIN_NAME" "$OUTPUT_DIR_ABS"; then
        ((++SUCCEEDED))
    else
        ((++FAILED))
    fi
done

# Summary
print_section "Review Complete"
echo "Results: $SUCCEEDED succeeded, $FAILED failed"
echo "Output saved to: $OUTPUT_DIR_ABS"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
