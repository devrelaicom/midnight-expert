#!/usr/bin/env bash
# Sourced helper. Defines compact_changed_check() used by Stop and SubagentStop
# hooks. Compares every *.compact file in the project against the SessionStart
# baseline. For each new or modified file, looks for a Bash tool_use whose
# command runs `compact compile` or `compactc` and contains the file's
# basename, with timestamp >= the file's mtime. Writes a {decision:"block"...}
# JSON object to stdout iff one or more files are unverified; otherwise writes
# nothing. Always returns 0 -- callers branch on whether stdout is empty.
#
# Args: $1 = project root, $2 = transcript path, $3 = settings file

compact_changed_check() {
  local project_root="$1"
  local transcript_path="$2"
  local settings_file="$3"

  if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
    return 0
  fi
  if [ -z "$project_root" ] || [ ! -d "$project_root" ]; then
    return 0
  fi
  if [ ! -f "$settings_file" ]; then
    return 0
  fi

  local file current_hash stored_hash filename file_mtime latest_compile_ts compile_epoch ts
  local -a unchecked=()

  while IFS= read -r -d '' file; do
    current_hash=$(sha256sum "$file" | awk '{print $1}')
    stored_hash=$(jq -r --arg f "$file" '.verify_stop_hook.compact_files[$f] // empty' \
                  "$settings_file")

    if [ -n "$stored_hash" ] && [ "$current_hash" = "$stored_hash" ]; then
      continue
    fi

    filename=$(basename "$file")
    file_mtime=$(stat -c "%Y" "$file" 2>/dev/null \
              || stat -f "%m" "$file" 2>/dev/null \
              || echo 0)

    latest_compile_ts=$(jq -r --arg fn "$filename" '
      select((.message.content // []) | type == "array")
      | select(any(.message.content[]?;
          .type? == "tool_use"
          and .name? == "Bash"
          and ((.input.command? // "") | test("compact[[:space:]]+compile|compactc"))
          and ((.input.command? // "") | contains($fn))
        ))
      | .timestamp // empty
    ' "$transcript_path" 2>/dev/null | tail -1)

    if [ -n "$latest_compile_ts" ]; then
      ts="${latest_compile_ts%Z}"
      ts="${ts%%.*}"
      compile_epoch=$(date -d "$ts" "+%s" 2>/dev/null \
                   || date -j -f "%Y-%m-%dT%H:%M:%S" "$ts" "+%s" 2>/dev/null \
                   || echo 0)
      if [ "$compile_epoch" -ge "$file_mtime" ]; then
        continue
      fi
    fi

    unchecked+=("$file")
  done < <(find "$project_root" -type f -name '*.compact' -print0 2>/dev/null)

  if [ ${#unchecked[@]} -eq 0 ]; then
    return 0
  fi

  local list=""
  local f
  for f in "${unchecked[@]}"; do
    list+="- ${f}"$'\n'
  done

  local reason="The following Compact contracts were created or modified in this session but were not compiled (no \`compact compile\` or \`compactc\` invocation including the file name was found in the transcript after the file's last modification):

${list}
Run /verify on these contracts -- or invoke \`compact compile\` / \`compactc\` against them -- before finishing. This is a reminder; you decide whether verification is needed here."

  jq -n --arg r "$reason" '{decision: "block", reason: $r}'
  return 0
}
