#!/usr/bin/env bash
set -euo pipefail

# check-staleness.sh
# Parses the "# Generated:" timestamp from a devnet.yml file header.
# Output: Two lines:
#   age_days=<N>
#   stale=<true|false>
# Threshold: 5 days.
# If no timestamp is found, outputs age_days=-1 and stale=unknown.
# Always exits 0 — the caller decides what to do with the result.

if [ $# -lt 1 ]; then
  echo "Usage: $0 <path-to-devnet.yml>" >&2
  exit 1
fi

FILE="$1"
THRESHOLD_DAYS=5

if [ ! -f "$FILE" ]; then
  echo "age_days=-1"
  echo "stale=unknown"
  echo "error=file_not_found"
  exit 0
fi

# Extract the ISO timestamp from the "# Generated: " comment line
TIMESTAMP=$(grep -m1 '^# Generated:' "$FILE" 2>/dev/null | sed 's/^# Generated: *//' | tr -d '[:space:]' || true)

if [ -z "$TIMESTAMP" ]; then
  echo "age_days=-1"
  echo "stale=unknown"
  echo "error=no_timestamp"
  exit 0
fi

# Parse the timestamp to epoch seconds (cross-platform)
if date --version >/dev/null 2>&1; then
  # GNU date (Linux)
  GENERATED_EPOCH=$(date -d "$TIMESTAMP" +%s 2>/dev/null) || {
    echo "age_days=-1"
    echo "stale=unknown"
    echo "error=parse_failed"
    exit 0
  }
else
  # BSD date (macOS)
  GENERATED_EPOCH=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$TIMESTAMP" +%s 2>/dev/null) || {
    echo "age_days=-1"
    echo "stale=unknown"
    echo "error=parse_failed"
    exit 0
  }
fi

NOW_EPOCH=$(date +%s)
AGE_SECONDS=$((NOW_EPOCH - GENERATED_EPOCH))
AGE_DAYS=$((AGE_SECONDS / 86400))

if [ "$AGE_DAYS" -ge "$THRESHOLD_DAYS" ]; then
  STALE="true"
else
  STALE="false"
fi

echo "age_days=${AGE_DAYS}"
echo "stale=${STALE}"
