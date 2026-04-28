#!/usr/bin/env bash
# Compare each package version pinned in versions.lock.json with the
# latest version on npm. Print a drift table; exit 0 if all none/patch,
# 1 if any minor/major drift detected.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK="${SCRIPT_DIR}/../versions.lock.json"

if [[ ! -f "$LOCK" ]]; then
  echo "ERROR: versions.lock.json not found at $LOCK" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 2
fi
if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: npm is required" >&2
  exit 2
fi

VERIFIED="$(jq -r '.verified' "$LOCK")"
PACKAGES_JSON="$(jq -c '.packages' "$LOCK")"

drift_class() {
  local pinned="$1" latest="$2"
  if [[ "$pinned" == "$latest" ]]; then echo "none"; return; fi
  local pm; pm="$(echo "$pinned" | cut -d. -f1)"
  local lm; lm="$(echo "$latest" | cut -d. -f1)"
  if [[ "$pm" != "$lm" ]]; then echo "MAJOR"; return; fi
  local pn; pn="$(echo "$pinned" | cut -d. -f2)"
  local ln; ln="$(echo "$latest" | cut -d. -f2)"
  if [[ "$pn" != "$ln" ]]; then echo "minor"; return; fi
  echo "patch"
}

echo "Verified: $VERIFIED"
echo
printf '%-50s %-12s %-12s %s\n' "PACKAGE" "PINNED" "LATEST" "DRIFT"
printf '%-50s %-12s %-12s %s\n' "-------" "------" "------" "-----"

drift_total=0
while IFS= read -r line; do
  pkg="$(echo "$line" | jq -r '.key')"
  pinned="$(echo "$line" | jq -r '.value')"
  latest="$(npm view "$pkg" version 2>/dev/null || echo "ERR")"
  if [[ "$latest" == "ERR" ]]; then
    printf '%-50s %-12s %-12s %s\n' "$pkg" "$pinned" "?" "npm-error"
    continue
  fi
  d="$(drift_class "$pinned" "$latest")"
  printf '%-50s %-12s %-12s %s\n' "$pkg" "$pinned" "$latest" "$d"
  if [[ "$d" == "minor" || "$d" == "MAJOR" ]]; then
    drift_total=$((drift_total + 1))
  fi
done < <(echo "$PACKAGES_JSON" | jq -c 'to_entries[]')

echo
if [[ $drift_total -gt 0 ]]; then
  echo "Drift detected in $drift_total package(s). Run smoke-test.sh to verify whether the documented patterns still work."
  exit 1
fi
echo "No drift."
exit 0
