#!/usr/bin/env bash
# Fixture-based tests for check-readme.sh.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$SCRIPT_DIR/check-readme.sh"

PASS=0
FAIL=0
CASE_JSON=""

assert_eq() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf '  [PASS] %s\n' "$label"
    PASS=$((PASS+1))
  else
    printf '  [FAIL] %s — expected %q, got %q\n' "$label" "$expected" "$actual" >&2
    FAIL=$((FAIL+1))
  fi
}

run_case() {
  local name="$1"
  local fixture_dir="$2"
  printf '\nCase: %s (%s)\n' "$name" "$fixture_dir"
  CASE_JSON="$(cd "$fixture_dir" && bash "$CHECK")"
  echo "$CASE_JSON" | jq . >/dev/null 2>&1 || {
    printf '  [FAIL] output is not valid JSON\n' >&2
    FAIL=$((FAIL+1))
    return
  }
}

field() { echo "$CASE_JSON" | jq -r "$1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Fixture 1: missing README
F1="$TMP/no-readme"
mkdir -p "$F1"
run_case "no README" "$F1"
assert_eq "exists" "false" "$(field '.exists')"
assert_eq "present" "false" "$(field '.present')"
assert_eq "placement" "top-of-file" "$(field '.placement')"

# Fixture 2: empty README
F2="$TMP/empty-readme"
mkdir -p "$F2"
: > "$F2/README.md"
run_case "empty README" "$F2"
assert_eq "exists" "true" "$(field '.exists')"
assert_eq "present" "false" "$(field '.present')"
assert_eq "placement" "top-of-file" "$(field '.placement')"

# Fixture 3: H1 + badges + tagline + H2
F3="$TMP/h1-badges"
mkdir -p "$F3"
cat > "$F3/README.md" <<'EOF'
# My Project

[![CI](https://example.com/badge)](https://example.com)

A short tagline that describes the project.

## Installation
EOF
run_case "H1 + badges + tagline + H2" "$F3"
assert_eq "exists" "true" "$(field '.exists')"
assert_eq "first_h1_line" "1" "$(field '.first_h1_line')"
assert_eq "first_h2_line" "7" "$(field '.first_h2_line')"
assert_eq "title_block_end_line" "6" "$(field '.title_block_end_line')"
assert_eq "placement" "after-title-block" "$(field '.placement')"

# Fixture 4: HTML banner, no H1
F4="$TMP/banner-only"
mkdir -p "$F4"
cat > "$F4/README.md" <<'EOF'
<p align="center">
  <img src="logo.png" />
</p>

## What is this?

Body text.
EOF
run_case "banner only, no H1" "$F4"
assert_eq "first_h1_line" "null" "$(field '.first_h1_line')"
assert_eq "placement" "after-title-block" "$(field '.placement')"

# Fixture 5: prose-only, no title
F5="$TMP/prose"
mkdir -p "$F5"
cat > "$F5/README.md" <<'EOF'
This is a small utility for X. It does Y by Z.

To install, run npm install.
EOF
run_case "prose-only" "$F5"
assert_eq "first_h1_line" "null" "$(field '.first_h1_line')"
assert_eq "placement" "top-of-file" "$(field '.placement')"

# Fixture 6: already attributed
F6="$TMP/attributed"
mkdir -p "$F6"
cat > "$F6/README.md" <<'EOF'
# Project

> [!NOTE]
> This project integrates with the Midnight Network.

Body.
EOF
run_case "already attributed" "$F6"
assert_eq "present" "true" "$(field '.present')"
assert_eq "matched_sentence" "integrates" "$(field '.matched_sentence')"

# Fixture 7: ambiguous (multiple H1s)
F7="$TMP/multi-h1"
mkdir -p "$F7"
cat > "$F7/README.md" <<'EOF'
# Part A

Stuff.

# Part B

More stuff.
EOF
run_case "multiple H1s" "$F7"
assert_eq "placement" "ambiguous" "$(field '.placement')"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
