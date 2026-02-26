#!/usr/bin/env bash
set -u

emit() {
  local name="$1"
  local status="$2"
  local detail="$3"
  detail="$(printf '%s' "$detail" | tr '\n' ';' | sed 's/  */ /g; s/; */; /g; s/; $//')"
  printf '%s | %s | %s\n' "$name" "$status" "$detail"
}

compact_path=""
if compact_path="$(command -v compact 2>/dev/null)"; then
  emit "CLI binary found" "pass" "$compact_path"
else
  emit "CLI binary found" "critical" "not found"
fi

cli_version="$(compact --version 2>&1)" || cli_version=""
if [ -n "$cli_version" ] && printf '%s' "$cli_version" | grep -qi 'compact'; then
  emit "CLI version" "info" "$cli_version"
else
  emit "CLI version" "critical" "not installed"
fi

compiler_version="$(compact compile --version 2>&1)" || compiler_version=""
if [ -n "$compiler_version" ] && printf '%s' "$compiler_version" | grep -qi '[0-9]'; then
  emit "Compiler version" "info" "$compiler_version"
else
  emit "Compiler installed" "critical" "no compiler installed"
fi

installed_versions="$(compact list --installed 2>&1)" || installed_versions=""
if [ -n "$installed_versions" ]; then
  emit "Installed versions" "info" "$installed_versions"
else
  emit "Installed versions" "info" "no installed versions found"
fi

compiler_check_out="$(compact check 2>&1)" || compiler_check_out=""
if [ -z "$compiler_check_out" ]; then
  emit "Compiler update" "warn" "check failed"
elif printf '%s' "$compiler_check_out" | grep -qi "update available"; then
  emit "Compiler update" "warn" "$compiler_check_out"
else
  emit "Compiler update" "pass" "up to date"
fi

cli_check_out="$(compact self check 2>&1)" || cli_check_out=""
if [ -z "$cli_check_out" ]; then
  emit "CLI update" "warn" "check failed"
elif printf '%s' "$cli_check_out" | grep -qi "update available"; then
  emit "CLI update" "warn" "$cli_check_out"
else
  emit "CLI update" "pass" "up to date"
fi

formatter_version="$(compact format --version 2>&1)" || formatter_version=""
if [ -n "$formatter_version" ] && printf '%s' "$formatter_version" | grep -qi '[0-9]'; then
  emit "Formatter" "pass" "$formatter_version"
else
  emit "Formatter" "warn" "not available"
fi
