#!/usr/bin/env bash
# Single-entry-point test runner for the status-codes-lookup scripts.
#
# Runs the cheap, fast checks that should pass on every PR:
#   1. check-schema.sh           — codes.json schema + slug round-trip
#   2. test_lookup.sh            — lookup.sh end-to-end (code/search/source/etc.)
#   3. tests/test-resolve-anchor.sh        — resolver slug + extract semantics
#   4. tests/test-lookup-renders-anchor.sh — lookup.sh stitches resolved anchors
#
# Skipped by default (network + multi-MB clone):
#   tests/test-coverage.sh — opt in with `run.sh --with-coverage`.

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$(cd "$TESTS_DIR/.." && pwd)"

WITH_COVERAGE=0
for arg in "$@"; do
  case "$arg" in
    --with-coverage) WITH_COVERAGE=1 ;;
    -h|--help)
      sed -n '2,16p' "$0"
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

FAILED=()

run_step() {
  local label="$1"; shift
  echo
  echo "==> $label"
  if "$@"; then
    echo "    OK: $label"
  else
    echo "    FAIL: $label"
    FAILED+=("$label")
  fi
}

run_step "check-schema.sh"                 bash "$SCRIPTS_DIR/check-schema.sh"
run_step "test_lookup.sh"                  bash "$SCRIPTS_DIR/test_lookup.sh"
run_step "tests/test-resolve-anchor.sh"    bash "$TESTS_DIR/test-resolve-anchor.sh"
run_step "tests/test-lookup-renders-anchor.sh" bash "$TESTS_DIR/test-lookup-renders-anchor.sh"

if [[ "$WITH_COVERAGE" -eq 1 ]]; then
  run_step "tests/test-coverage.sh (opt-in)" bash "$TESTS_DIR/test-coverage.sh"
fi

echo
if [[ "${#FAILED[@]}" -gt 0 ]]; then
  echo "FAILED steps: ${#FAILED[@]}"
  printf '  - %s\n' "${FAILED[@]}"
  exit 1
fi
echo "All checks passed."
