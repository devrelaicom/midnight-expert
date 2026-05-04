#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
LOOKUP="$SCRIPT_DIR/lookup.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Fixture: a single retired umbrella entry with superseded_by, plus an active entry
cat > "$TMP/codes.json" <<'JSON'
{
  "version": "test",
  "generated": "2026-05-04",
  "entries": [
    {
      "code": "186",
      "name": "EffectsCheckFailure",
      "source": "midnight-node",
      "category": "transaction_malformed",
      "group": { "name": "Transaction Malformed", "description": "..." },
      "description": "Retired umbrella",
      "fixes": ["See sub-codes"],
      "aliases": ["RETIRED"],
      "severity": "error",
      "see_also": [],
      "verified_against": {
        "source_repo": "midnightntwrk/midnight-node",
        "ref": "main",
        "anchor": "x",
        "anchor_modified": "2026-05-04",
        "verified_at": "2026-05-04"
      },
      "status": "retired",
      "superseded_by": ["212", "213", "214"]
    },
    {
      "code": "1",
      "name": "Active",
      "source": "midnight-node",
      "category": "deserialization",
      "group": { "name": "Deserialization", "description": "..." },
      "description": "Active entry without status",
      "fixes": ["fix it"],
      "aliases": [],
      "severity": "error",
      "see_also": [],
      "verified_against": {
        "source_repo": "x",
        "ref": "main",
        "anchor": "x",
        "anchor_modified": "2026-05-04",
        "verified_at": "2026-05-04"
      }
    },
    {
      "code": "JsTest",
      "name": "JsTestError",
      "source": "midnight-js",
      "category": "sdk",
      "group": { "name": "SDK", "description": "..." },
      "description": "Entry that carries a class field",
      "fixes": ["fix it"],
      "aliases": [],
      "severity": "error",
      "see_also": [],
      "verified_against": {
        "source_repo": "x",
        "ref": "main",
        "anchor": "x",
        "anchor_modified": "2026-05-04",
        "verified_at": "2026-05-04"
      },
      "class": "Error"
    }
  ]
}
JSON

# Copy lookup.sh next to the fixture so its SCRIPT_DIR resolves to $TMP
TEST_LOOKUP="$TMP/lookup.sh"
cp "$LOOKUP" "$TEST_LOOKUP"
chmod +x "$TEST_LOOKUP"

fail() { echo "FAIL: $1" >&2; exit 1; }

# Test 1: retired entry prints Status: retired
out=$(bash "$TEST_LOOKUP" --code 186)
echo "$out" | grep -Eq '^Status: retired$' || fail "expected 'Status: retired' for code 186"

# Test 2: retired entry prints Superseded by: 212, 213, 214
echo "$out" | grep -Eq '^Superseded by: 212, 213, 214$' || fail "expected 'Superseded by: ...' for code 186"

# Test 3: active entry without status field does NOT print Status: line
out_active=$(bash "$TEST_LOOKUP" --code 1)
if echo "$out_active" | grep -Eq '^Status:'; then
  fail "active entry without status field should not print Status: line"
fi
if echo "$out_active" | grep -Eq '^Superseded by:'; then
  fail "entry without superseded_by should not print Superseded by: line"
fi

# Test 4: entry with class field prints Class: <value>
out_class=$(bash "$TEST_LOOKUP" --code JsTest)
echo "$out_class" | grep -Eq '^Class: Error$' || fail "expected 'Class: Error' for code JsTest"

# Test 5: entry without class field does NOT print Class: line
if echo "$out" | grep -Eq '^Class:'; then
  fail "entry without class field (code 186) should not print Class: line"
fi

echo "OK: all lookup.sh status/superseded_by/class tests passed"
