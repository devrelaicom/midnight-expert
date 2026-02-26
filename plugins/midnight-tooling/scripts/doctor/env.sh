#!/usr/bin/env bash
set -u

emit() {
  local name="$1"
  local status="$2"
  local detail="$3"
  detail="$(printf '%s' "$detail" | tr '\n' ';' | sed 's/  */ /g; s/; */; /g; s/; $//')"
  printf '%s | %s | %s\n' "$name" "$status" "$detail"
}

compact_dir="${COMPACT_DIRECTORY:-}"
if [ -n "$compact_dir" ]; then
  emit "COMPACT_DIRECTORY" "info" "$compact_dir"
  if [ -d "$compact_dir" ]; then
    emit "COMPACT_DIRECTORY exists" "pass" "directory found"
  else
    emit "COMPACT_DIRECTORY exists" "critical" "directory does not exist"
  fi
else
  if [ -d ".compact/" ]; then
    emit "COMPACT_DIRECTORY" "warn" "not set but .compact/ found in project — run /midnight-tooling:install-cli install for this project"
  else
    emit "COMPACT_DIRECTORY" "info" "not set (using default)"
  fi
fi

path_entries="$(echo "$PATH" | tr ':' '\n' | grep -i compact 2>/dev/null)" || path_entries=""
if [ -n "$path_entries" ]; then
  emit "PATH configured" "pass" "$path_entries"
else
  emit "PATH configured" "warn" "no compact entries in PATH"
fi
