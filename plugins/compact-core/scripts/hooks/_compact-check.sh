#!/usr/bin/env bash
# Sourced helper. Exposes:
#
#   compact_unchecked_files <project_root> <transcript> <settings>
#     Prints every *.compact file that is new or has changed hash since the
#     SessionStart snapshot AND is not covered by a Bash `compact compile` /
#     `compactc` tool call (containing the file's basename, with timestamp >=
#     the file's mtime) in <transcript>. One path per line; empty if none.
#
#   compact_block_reason_for_files
#     Reads newline-separated file paths from stdin and prints a
#     {decision:"block",reason:...} JSON object built from them. Always 0.
#
#   compact_changed_check <project_root> <transcript> <settings>
#     Convenience: pipes compact_unchecked_files into
#     compact_block_reason_for_files. Prints a block JSON iff at least one
#     unchecked file exists; otherwise prints nothing. Always returns 0 --
#     callers branch on stdout being empty.
#
# CANONICAL COPY: this file lives in two plugins (compact-core and
# midnight-verify) and a CI job (.github/workflows/ci-compact-core-hooks.yml)
# enforces that both copies are byte-identical via sha256sum.

compact_unchecked_files() {
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

  while IFS= read -r -d '' file; do
    current_hash=$(sha256sum "$file" | awk '{print $1}')
    stored_hash=$(jq -r --arg f "$file" '.compact_compilation_check_hook.compact_files[$f] // empty' \
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

    printf '%s\n' "$file"
  done < <(find "$project_root" -type f -name '*.compact' -print0 2>/dev/null)
}

compact_block_reason_for_files() {
  local list="" f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    list+="- ${f}"$'\n'
  done

  if [ -z "$list" ]; then
    return 0
  fi

  local reason="The following Compact contracts were created or modified in this session but were not compiled (no \`compact compile\` or \`compactc\` invocation including the file name was found in the transcript after the file's last modification):

${list}
Run /verify on these contracts -- or invoke \`compact compile\` / \`compactc\` against them -- before finishing. This is a reminder; you decide whether verification is needed here."

  jq -n --arg r "$reason" '{decision: "block", reason: $r}'
}

compact_changed_check() {
  local files
  files=$(compact_unchecked_files "$1" "$2" "$3")

  if [ -z "$files" ]; then
    return 0
  fi

  printf '%s\n' "$files" | compact_block_reason_for_files
  return 0
}
