#!/usr/bin/env bash
# json.sh - JSON output utilities

# Global variable to track if JSON mode is enabled
JSON_MODE=false
JSON_RESULTS=()

# Enable JSON output mode
enable_json_mode() {
    JSON_MODE=true
}

# Add a result entry to JSON output
# Usage: add_json_result type message [details]
add_json_result() {
    local type="$1"
    local message="$2"
    local details="${3:-}"

    # Escape special characters for JSON
    message=$(echo "$message" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')
    details=$(echo "$details" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//')

    local entry="{\"type\":\"$type\",\"message\":\"$message\""
    if [[ -n "$details" ]]; then
        entry="$entry,\"details\":\"$details\""
    fi
    entry="$entry}"

    JSON_RESULTS+=("$entry")
}

# Print collected JSON results
print_json_output() {
    if [[ "$JSON_MODE" != "true" ]]; then
        return
    fi

    echo "{"
    echo "  \"results\": ["

    local first=true
    for result in "${JSON_RESULTS[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi
        echo -n "    $result"
    done

    echo ""
    echo "  ]"
    echo "}"
}
