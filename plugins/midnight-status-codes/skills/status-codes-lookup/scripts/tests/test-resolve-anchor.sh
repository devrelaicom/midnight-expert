#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESOLVER="$SCRIPT_DIR/resolve-anchor.sh"
FIXTURE="$SCRIPT_DIR/tests/anchor-fixture.md"

PASS=0
FAIL=0

assert_eq() {
  local label="$1"; local expected="$2"; local actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "PASS: $label"; PASS=$((PASS+1))
  else
    echo "FAIL: $label"
    echo "  expected: $(printf %q "$expected")"
    echo "  actual:   $(printf %q "$actual")"
    FAIL=$((FAIL+1))
  fi
}

assert_contains() {
  local label="$1"; local needle="$2"; local hay="$3"
  if [[ "$hay" == *"$needle"* ]]; then
    echo "PASS: $label"; PASS=$((PASS+1))
  else
    echo "FAIL: $label"
    echo "  expected to contain: $(printf %q "$needle")"
    echo "  actual:              $(printf %q "$hay")"
    FAIL=$((FAIL+1))
  fi
}

# slug correctness
assert_eq "slug: lowercase + spaces" "first-section" "$("$RESOLVER" --slug 'First section')"
assert_eq "slug: punctuation stripped" "second-section-with-punctuation" "$("$RESOLVER" --slug 'Second section: with punctuation!')"
assert_eq "slug: backticks + parens stripped" "section-with-code-and-parens" "$("$RESOLVER" --slug 'Section with `code` and (parens)')"

# extraction
out=$("$RESOLVER" --extract "$FIXTURE" first-section)
assert_contains "extract: first body line 1" "First section body line 1." "$out"
assert_contains "extract: first body line 2" "First section body line 2." "$out"
[[ "$out" != *"Second section"* ]] && { echo "PASS: extract: stops at next ##"; PASS=$((PASS+1)); } || { echo "FAIL: extract leaked into next ## section"; FAIL=$((FAIL+1)); }

# nested heading is included in parent's extraction
out=$("$RESOLVER" --extract "$FIXTURE" second-section-with-punctuation)
assert_contains "extract: includes nested ###" "Nested under second" "$out"
assert_contains "extract: includes nested body" "Nested body" "$out"
[[ "$out" != *"Third section"* ]] && { echo "PASS: extract: stops at next sibling ##"; PASS=$((PASS+1)); } || { echo "FAIL: extract leaked into Third section"; FAIL=$((FAIL+1)); }

# missing anchor: exit non-zero with descriptive message
if "$RESOLVER" --extract "$FIXTURE" no-such-anchor 2>/dev/null; then
  echo "FAIL: missing-anchor should exit non-zero"; FAIL=$((FAIL+1))
else
  echo "PASS: missing-anchor exits non-zero"; PASS=$((PASS+1))
fi

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
