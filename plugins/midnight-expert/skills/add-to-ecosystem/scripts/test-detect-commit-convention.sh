#!/usr/bin/env bash
# Fixture-based tests for detect-commit-convention.sh.
# Each test creates a temp git repo, makes commits with various message styles,
# runs detect-commit-convention.sh against it, and asserts specific JSON fields.
# Exits 0 on full pass, 1 on any failure.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECT="$SCRIPT_DIR/detect-commit-convention.sh"

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
  local out
  out="$(cd "$fixture_dir" && bash "$DETECT")"
  echo "$out" | jq . >/dev/null 2>&1 || {
    printf '  [FAIL] output is not valid JSON\n' >&2
    FAIL=$((FAIL+1))
    return
  }
  CASE_JSON="$out"
}

field() { echo "$CASE_JSON" | jq -r "$1"; }

# Helper: init a bare git repo in $1
init_repo() {
  local dir="$1"
  git -c init.defaultBranch=main init -q "$dir"
  git -C "$dir" config user.email t@t
  git -C "$dir" config user.name Test
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- Fixture 1: empty repo (no commits) ---
F="$TMP/empty-repo"
init_repo "$F"
run_case "empty repo (no commits)" "$F"
assert_eq "convention" "freeform"    "$(field '.convention')"
assert_eq "total"      "0"           "$(field '.total')"
assert_eq "matches"    "0"           "$(field '.matches')"
assert_eq "threshold"  "0.6"         "$(field '.threshold')"

# --- Fixture 2: all conventional (5/5 = 1.0 >= 0.6) ---
F="$TMP/all-conventional"
init_repo "$F"
git -C "$F" commit --allow-empty -m "feat: a"
git -C "$F" commit --allow-empty -m "fix: b"
git -C "$F" commit --allow-empty -m "chore: c"
git -C "$F" commit --allow-empty -m "docs: d"
git -C "$F" commit --allow-empty -m "refactor: e"
run_case "all conventional (5/5)" "$F"
assert_eq "convention" "conventional" "$(field '.convention')"
assert_eq "total"      "5"            "$(field '.total')"
assert_eq "matches"    "5"            "$(field '.matches')"

# --- Fixture 3: all freeform (0/5 = 0.0 < 0.6) ---
F="$TMP/all-freeform"
init_repo "$F"
git -C "$F" commit --allow-empty -m "Initial commit"
git -C "$F" commit --allow-empty -m "Add some stuff"
git -C "$F" commit --allow-empty -m "Update README with details"
git -C "$F" commit --allow-empty -m "Fix the broken thing"
git -C "$F" commit --allow-empty -m "Miscellaneous cleanup"
run_case "all freeform (0/5)" "$F"
assert_eq "convention" "freeform" "$(field '.convention')"
assert_eq "total"      "5"        "$(field '.total')"
assert_eq "matches"    "0"        "$(field '.matches')"

# --- Fixture 4: mixed below threshold (5/10 = 0.5 < 0.6) ---
F="$TMP/mixed-below"
init_repo "$F"
git -C "$F" commit --allow-empty -m "feat: one"
git -C "$F" commit --allow-empty -m "Initial work"
git -C "$F" commit --allow-empty -m "fix: two"
git -C "$F" commit --allow-empty -m "Add something"
git -C "$F" commit --allow-empty -m "chore: three"
git -C "$F" commit --allow-empty -m "Update stuff"
git -C "$F" commit --allow-empty -m "docs: four"
git -C "$F" commit --allow-empty -m "Random change"
git -C "$F" commit --allow-empty -m "test: five"
git -C "$F" commit --allow-empty -m "More work done"
run_case "mixed below threshold (5/10 = 0.5)" "$F"
assert_eq "convention" "freeform" "$(field '.convention')"
assert_eq "total"      "10"       "$(field '.total')"
assert_eq "matches"    "5"        "$(field '.matches')"

# --- Fixture 5: mixed above threshold (6/10 = 0.6 >= 0.6) ---
F="$TMP/mixed-above"
init_repo "$F"
git -C "$F" commit --allow-empty -m "feat: one"
git -C "$F" commit --allow-empty -m "Initial work"
git -C "$F" commit --allow-empty -m "fix: two"
git -C "$F" commit --allow-empty -m "Add something"
git -C "$F" commit --allow-empty -m "chore: three"
git -C "$F" commit --allow-empty -m "docs: four"
git -C "$F" commit --allow-empty -m "Update stuff"
git -C "$F" commit --allow-empty -m "test: five"
git -C "$F" commit --allow-empty -m "ci: six"
git -C "$F" commit --allow-empty -m "Random stray message"
run_case "mixed above threshold (6/10 = 0.6)" "$F"
assert_eq "convention" "conventional" "$(field '.convention')"
assert_eq "total"      "10"           "$(field '.total')"
assert_eq "matches"    "6"            "$(field '.matches')"

# --- Fixture 6: conventional with scope ---
F="$TMP/scoped"
init_repo "$F"
git -C "$F" commit --allow-empty -m "feat(api): x"
git -C "$F" commit --allow-empty -m "fix(ui): y"
git -C "$F" commit --allow-empty -m "chore(deps): z"
run_case "conventional with scope (3/3)" "$F"
assert_eq "convention" "conventional" "$(field '.convention')"
assert_eq "total"      "3"            "$(field '.total')"
assert_eq "matches"    "3"            "$(field '.matches')"

# --- summary ---
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
