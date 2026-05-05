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

# fenced code block: lines starting with # inside a fence must NOT be treated
# as heading boundaries. Section must include the in-fence content verbatim
# and must not leak into the next sibling section.
out=$("$RESOLVER" --extract "$FIXTURE" section-with-fenced-code-block)
assert_contains "extract: fenced section keeps '# comment' verbatim" "# this is a comment, not a heading" "$out"
assert_contains "extract: fenced section keeps closing fence" '```' "$out"
[[ "$out" != *"Body of section after fenced"* ]] && { echo "PASS: extract: fence does not leak into next ## section"; PASS=$((PASS+1)); } || { echo "FAIL: fenced extract leaked into next ## section"; FAIL=$((FAIL+1)); }

# fence-state machine resets between extractions: the section after the fenced
# section must extract cleanly (i.e. not still be "inside a fence").
out=$("$RESOLVER" --extract "$FIXTURE" section-after-fenced)
assert_contains "extract: post-fence section body" "Body of section after fenced." "$out"

echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
