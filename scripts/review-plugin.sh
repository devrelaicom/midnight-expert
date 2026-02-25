#!/usr/bin/env bash
# review-plugin.sh - Deep review of a plugin using Claude CLI with plugin-dev skills

set -euo pipefail

# Get script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"

# Default values
OUTPUT_DIR=""
INCLUDE_JSON=false
FORMAT="markdown"
PLUGINS_DIR="./plugins"

# Usage information
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <PLUGIN>

Deep review of a single plugin using Claude CLI with plugin-dev skills

Arguments:
  PLUGIN (required)   Plugin name or path

Options:
  --output PATH       Output directory for report (default: ./reviews/{plugin-name})
  --json             Include JSON output alongside markdown
  --format FORMAT    Report format: markdown, html, pdf (default: markdown)
  --help             Show this help message

Examples:
  $(basename "$0") dev                    # Review dev plugin
  $(basename "$0") /path/to/plugin        # Review plugin at path
  $(basename "$0") dev --output ./my-reviews
  $(basename "$0") dev --json --format html

EOF
    exit 0
}

# Parse command line arguments
PLUGIN_ARG=""
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
        *)
            if [[ -z "$PLUGIN_ARG" ]]; then
                PLUGIN_ARG="$1"
            else
                print_error "Only one plugin can be reviewed at a time"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required argument
if [[ -z "$PLUGIN_ARG" ]]; then
    print_error "Plugin argument is required"
    usage
fi

# Resolve plugin path
PLUGIN_PATH=""
if [[ -d "$PLUGIN_ARG" ]]; then
    PLUGIN_PATH="$PLUGIN_ARG"
elif [[ -d "$PLUGINS_DIR/$PLUGIN_ARG" ]]; then
    PLUGIN_PATH="$PLUGINS_DIR/$PLUGIN_ARG"
else
    print_error "Plugin not found: $PLUGIN_ARG"
    exit 1
fi

# Validate plugin directory
if [[ ! -f "$PLUGIN_PATH/.claude-plugin/plugin.json" ]]; then
    print_error "Invalid plugin directory (missing plugin.json): $PLUGIN_PATH"
    exit 1
fi

# Get plugin name
PLUGIN_NAME=$(basename "$PLUGIN_PATH")

# Set output directory if not specified
if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="./reviews/$PLUGIN_NAME"
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
print_info "Output directory: $OUTPUT_DIR"

# Determine absolute paths
PLUGIN_PATH_ABS=$(cd "$PLUGIN_PATH" && pwd)
OUTPUT_DIR_ABS=$(cd "$OUTPUT_DIR" && pwd)

print_section "Reviewing plugin: $PLUGIN_NAME"
print_info "Plugin path: $PLUGIN_PATH_ABS"

# Create review prompt
REVIEW_PROMPT="Conduct a comprehensive review of the Claude Code plugin located at: $PLUGIN_PATH_ABS

Use the plugin-dev:plugin-validator agent to perform a thorough analysis. Output ONLY the review report in markdown format with no preamble or explanatory text. Include these sections:

## Executive Summary
Brief overview of the plugin, its purpose, and overall assessment.

## Validation Results
Results from validation checks.

## Component Analysis
Detailed analysis of:
- Agents (if any): Purpose, structure, and quality
- Skills (if any): Functionality and documentation
- Commands (if any): Usage and implementation
- Hooks (if any): Event handling and integration
- MCP Servers (if any): Configuration and integration

## Code Quality
Review of any scripts or code:
- Code organization and structure
- Error handling
- Best practices adherence
- Security considerations

## Documentation Review
Assessment of:
- plugin.json completeness and accuracy
- README and documentation files
- Inline documentation and comments
- Usage examples

## Recommendations
Specific, actionable recommendations organized by priority:
- Critical issues
- Suggested improvements
- Optional enhancements

Output the review now:"

# Run Claude CLI for the review
print_section "Running Claude CLI review"
print_info "This may take a few minutes..."

# Create a temporary file for the prompt
TEMP_PROMPT=$(mktemp)
echo "$REVIEW_PROMPT" > "$TEMP_PROMPT"

# Capture Claude CLI output
TEMP_OUTPUT=$(mktemp)
if (cd "$PLUGIN_PATH_ABS" && claude -p "$(cat "$TEMP_PROMPT")" > "$TEMP_OUTPUT" 2>&1); then
    # Save the output to the report file
    cp "$TEMP_OUTPUT" "$OUTPUT_DIR_ABS/review-report.md"
    print_success "Review completed successfully"
    print_success "Report saved to: $OUTPUT_DIR_ABS/review-report.md"
else
    print_error "Review failed"
    print_info "Output was:"
    cat "$TEMP_OUTPUT"
    rm -f "$TEMP_PROMPT" "$TEMP_OUTPUT"
    exit 1
fi

# Cleanup temp output
rm -f "$TEMP_OUTPUT"

# Generate JSON output if requested
if [[ "$INCLUDE_JSON" == "true" ]]; then
    print_info "Generating JSON metadata..."

    JSON_OUTPUT="$OUTPUT_DIR_ABS/review-metadata.json"
    cat > "$JSON_OUTPUT" << EOF
{
  "plugin_name": "$PLUGIN_NAME",
  "plugin_path": "$PLUGIN_PATH_ABS",
  "review_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "report_format": "$FORMAT",
  "report_file": "$OUTPUT_DIR_ABS/review-report.md"
}
EOF
    print_success "Metadata saved to: $JSON_OUTPUT"
fi

# Cleanup
rm -f "$TEMP_PROMPT"

print_section "Review Complete"
echo "Review output saved to: $OUTPUT_DIR_ABS"

exit 0
