# Statusline Devnet Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the proof-server-only statusline with a devnet-aware statusline that shows all 3 node statuses via the `midnight-local-devnet` CLI, adds Compact language version, and uses tiered caching.

**Architecture:** Single-file modification to `sl.sh`. Phase 4 (status checks) is completely rewritten to call the devnet CLI instead of curl. Phase 5 (segment building) replaces the proof server segment with a devnet icon grid. All other phases remain unchanged.

**Tech Stack:** Bash, jq (with grep/sed fallbacks), `npx @aaronbassett/midnight-local-devnet` CLI

**Design doc:** `docs/plans/2026-03-02-statusline-devnet-design.md`

---

### Task 1: Add new cache file paths

**Files:**
- Modify: `plugins/midnight-tooling/scripts/sl.sh:86-88`

**Step 1: Add cache variables after existing cache declarations**

After line 88 (`CHAIN_REFRESH_CACHE=...`), add:

```bash
DEVNET_HEALTH_CACHE="/tmp/midnight-devnet-health-${DIR_HASH}"
COMPACT_VER_CACHE="/tmp/midnight-compact-ver-${DIR_HASH}"
```

These sit alongside the existing `OUR_CACHE`, `CHAIN_CONF`, and `CHAIN_REFRESH_CACHE` declarations.

**Step 2: Verify the file still parses**

Run: `bash -n plugins/midnight-tooling/scripts/sl.sh`
Expected: No output (clean parse)

**Step 3: Commit**

```bash
git add plugins/midnight-tooling/scripts/sl.sh
git commit -m "refactor(statusline): add cache path variables for devnet health and compact versions"
```

---

### Task 2: Replace proof server check with devnet status CLI call

**Files:**
- Modify: `plugins/midnight-tooling/scripts/sl.sh:246-308`

**Step 1: Delete the entire proof server check block**

Remove lines 246–308 (the `PROOF_STATUS`/`PROOF_DETAIL`/`PROOF_PORT` variables, `proof_check_url()` function, and the Docker fallback logic).

**Step 2: Write the devnet status check in its place**

```bash
# --- Devnet status (via midnight-local-devnet CLI) ---
DEVNET_NODE="unknown"
DEVNET_INDEXER="unknown"
DEVNET_PROOF="unknown"
DEVNET_ANY_RUNNING=0

if command -v npx >/dev/null 2>&1; then
  devnet_status_json="$(run_with_timeout 5 npx -y @aaronbassett/midnight-local-devnet status --json 2>/dev/null || true)"
  if [ -n "$devnet_status_json" ]; then
    # Parse per-service status
    if command -v jq >/dev/null 2>&1; then
      DEVNET_NODE="$(printf '%s' "$devnet_status_json" | jq -r '.services[]? | select(.name=="node") | .status // "unknown"' 2>/dev/null || echo "unknown")"
      DEVNET_INDEXER="$(printf '%s' "$devnet_status_json" | jq -r '.services[]? | select(.name=="indexer") | .status // "unknown"' 2>/dev/null || echo "unknown")"
      DEVNET_PROOF="$(printf '%s' "$devnet_status_json" | jq -r '.services[]? | select(.name=="proof-server") | .status // "unknown"' 2>/dev/null || echo "unknown")"
    else
      # Fallback: grep for status values by position (node first, indexer second, proof-server third)
      DEVNET_NODE="$(printf '%s' "$devnet_status_json" | grep -A3 '"name" *: *"node"' | grep -o '"status" *: *"[^"]*"' | head -1 | sed 's/.*: *"//;s/"$//' || echo "unknown")"
      DEVNET_INDEXER="$(printf '%s' "$devnet_status_json" | grep -A3 '"name" *: *"indexer"' | grep -o '"status" *: *"[^"]*"' | head -1 | sed 's/.*: *"//;s/"$//' || echo "unknown")"
      DEVNET_PROOF="$(printf '%s' "$devnet_status_json" | grep -A3 '"name" *: *"proof-server"' | grep -o '"status" *: *"[^"]*"' | head -1 | sed 's/.*: *"//;s/"$//' || echo "unknown")"
    fi

    # Check if any service is running
    if [ "$DEVNET_NODE" = "running" ] || [ "$DEVNET_INDEXER" = "running" ] || [ "$DEVNET_PROOF" = "running" ]; then
      DEVNET_ANY_RUNNING=1
    fi
  fi
fi
```

**Step 3: Verify the file still parses**

Run: `bash -n plugins/midnight-tooling/scripts/sl.sh`
Expected: No output (clean parse)

**Step 4: Commit**

```bash
git add plugins/midnight-tooling/scripts/sl.sh
git commit -m "feat(statusline): replace proof server curl with devnet CLI status check"
```

---

### Task 3: Add health check overlay with 30s cache

**Files:**
- Modify: `plugins/midnight-tooling/scripts/sl.sh` (immediately after the status check from Task 2)

**Step 1: Add health check logic after the status block**

This runs after the devnet status check. It uses a 30s cache and overrides status with health data when available.

```bash
# --- Devnet health overlay (30s cache, supplements status) ---
if [ "$DEVNET_ANY_RUNNING" -eq 1 ]; then
  devnet_health_json=""
  health_needs_refresh=1

  if [ -f "$DEVNET_HEALTH_CACHE" ]; then
    health_age="$(get_file_age "$DEVNET_HEALTH_CACHE")"
    if [ "$health_age" -lt 30 ]; then
      devnet_health_json="$(cat "$DEVNET_HEALTH_CACHE" 2>/dev/null || true)"
      health_needs_refresh=0
    fi
  fi

  if [ "$health_needs_refresh" -eq 1 ] && command -v npx >/dev/null 2>&1; then
    devnet_health_json="$(run_with_timeout 5 npx -y @aaronbassett/midnight-local-devnet health --json 2>/dev/null || true)"
    if [ -n "$devnet_health_json" ]; then
      printf '%s' "$devnet_health_json" > "$DEVNET_HEALTH_CACHE" 2>/dev/null || true
    fi
  fi

  # Override status with health data: container "running" but unhealthy → treat as down
  if [ -n "$devnet_health_json" ]; then
    local node_healthy="" indexer_healthy="" proof_healthy=""
    if command -v jq >/dev/null 2>&1; then
      node_healthy="$(printf '%s' "$devnet_health_json" | jq -r '.node.healthy // empty' 2>/dev/null || true)"
      indexer_healthy="$(printf '%s' "$devnet_health_json" | jq -r '.indexer.healthy // empty' 2>/dev/null || true)"
      proof_healthy="$(printf '%s' "$devnet_health_json" | jq -r '.proofServer.healthy // empty' 2>/dev/null || true)"
    else
      node_healthy="$(printf '%s' "$devnet_health_json" | grep -A2 '"node"' | grep -o '"healthy" *: *[a-z]*' | head -1 | sed 's/.*: *//' || true)"
      indexer_healthy="$(printf '%s' "$devnet_health_json" | grep -A2 '"indexer"' | grep -o '"healthy" *: *[a-z]*' | head -1 | sed 's/.*: *//' || true)"
      proof_healthy="$(printf '%s' "$devnet_health_json" | grep -A2 '"proofServer"' | grep -o '"healthy" *: *[a-z]*' | head -1 | sed 's/.*: *//' || true)"
    fi

    # Health overrides: if container is "running" but health says false, mark as unhealthy
    if [ "$DEVNET_NODE" = "running" ] && [ "$node_healthy" = "false" ]; then
      DEVNET_NODE="unhealthy"
    fi
    if [ "$DEVNET_INDEXER" = "running" ] && [ "$indexer_healthy" = "false" ]; then
      DEVNET_INDEXER="unhealthy"
    fi
    if [ "$DEVNET_PROOF" = "running" ] && [ "$proof_healthy" = "false" ]; then
      DEVNET_PROOF="unhealthy"
    fi
  fi
fi
```

**Important:** The `local` keyword on `node_healthy`, `indexer_healthy`, `proof_healthy` must be removed — these are in the main script body, not inside a function. Use plain variable assignments instead.

**Step 2: Verify parse**

Run: `bash -n plugins/midnight-tooling/scripts/sl.sh`
Expected: No output

**Step 3: Commit**

```bash
git add plugins/midnight-tooling/scripts/sl.sh
git commit -m "feat(statusline): add devnet health check overlay with 30s cache"
```

---

### Task 4: Add compact language version with 1hr cache

**Files:**
- Modify: `plugins/midnight-tooling/scripts/sl.sh:310-339` (the existing Compact CLI block)

**Step 1: Rewrite the compact CLI check to add language version and use version cache**

Replace the entire compact CLI block (from `COMPACT_INSTALLED=0` through the update check) with:

```bash
# --- Compact CLI ---
COMPACT_INSTALLED=0
COMPACT_VERSION=""
COMPACT_LANG_VERSION=""
COMPACT_UPDATE=""

if command -v compact >/dev/null 2>&1; then
  COMPACT_INSTALLED=1

  # Version check with 1hr cache
  compact_ver_needs_refresh=1
  if [ -f "$COMPACT_VER_CACHE" ]; then
    ver_age="$(get_file_age "$COMPACT_VER_CACHE")"
    if [ "$ver_age" -lt 3600 ]; then
      # Cache format: compiler_version|language_version
      cached_ver="$(cat "$COMPACT_VER_CACHE" 2>/dev/null || true)"
      COMPACT_VERSION="$(printf '%s' "$cached_ver" | cut -d'|' -f1)"
      COMPACT_LANG_VERSION="$(printf '%s' "$cached_ver" | cut -d'|' -f2)"
      compact_ver_needs_refresh=0
    fi
  fi

  if [ "$compact_ver_needs_refresh" -eq 1 ]; then
    # Compiler version
    raw_version="$(run_with_timeout 5 compact compile --version 2>/dev/null | head -1 || true)"
    COMPACT_VERSION="$(printf '%s' "$raw_version" | grep -o '[0-9][0-9.]*[0-9]' | head -1 || true)"

    # Language version
    raw_lang="$(run_with_timeout 5 compact compile --language-version 2>/dev/null | head -1 || true)"
    COMPACT_LANG_VERSION="$(printf '%s' "$raw_lang" | grep -o '[0-9][0-9.]*[0-9]' | head -1 || true)"

    # Cache both versions (pipe-separated)
    printf '%s' "${COMPACT_VERSION}|${COMPACT_LANG_VERSION}" > "$COMPACT_VER_CACHE" 2>/dev/null || true
  fi

  # Update check with 30min cache (unchanged logic)
  COMPACT_CHECK_CACHE="/tmp/midnight-compact-check-${DIR_HASH}"
  if [ -f "$COMPACT_CHECK_CACHE" ]; then
    check_age="$(get_file_age "$COMPACT_CHECK_CACHE")"
    if [ "$check_age" -lt 1800 ]; then
      COMPACT_UPDATE="$(cat "$COMPACT_CHECK_CACHE" 2>/dev/null || true)"
    fi
  fi

  if [ -z "$COMPACT_UPDATE" ] && { [ ! -f "$COMPACT_CHECK_CACHE" ] || [ "$(get_file_age "$COMPACT_CHECK_CACHE")" -ge 1800 ]; }; then
    check_output="$(run_with_timeout 5 compact check 2>&1 || true)"
    if printf '%s' "$check_output" | grep -qi "update available"; then
      COMPACT_UPDATE="update"
    else
      COMPACT_UPDATE="current"
    fi
    printf '%s' "$COMPACT_UPDATE" > "$COMPACT_CHECK_CACHE" 2>/dev/null || true
  fi
fi
```

**Step 2: Verify parse**

Run: `bash -n plugins/midnight-tooling/scripts/sl.sh`
Expected: No output

**Step 3: Commit**

```bash
git add plugins/midnight-tooling/scripts/sl.sh
git commit -m "feat(statusline): add compact language version with 1hr cache"
```

---

### Task 5: Replace proof server segment with devnet icon grid

**Files:**
- Modify: `plugins/midnight-tooling/scripts/sl.sh:506-532` (Segment 2: Proof server)

**Step 1: Delete the entire proof server segment block**

Remove the `case "$PROOF_STATUS"` block (lines 506–532).

**Step 2: Write the devnet segment in its place**

```bash
# Segment 2: Devnet status
if [ "$DEVNET_ANY_RUNNING" -eq 1 ]; then
  # Build icon grid: ✓ for running, ✗ for anything else
  # Order: Node, Indexer, Proof Server
  # ✓ = \xe2\x9c\x93  ✗ = \xe2\x9c\x97
  icon_node=$( [ "$DEVNET_NODE" = "running" ] && printf '\xe2\x9c\x93' || printf '\xe2\x9c\x97' )
  icon_indexer=$( [ "$DEVNET_INDEXER" = "running" ] && printf '\xe2\x9c\x93' || printf '\xe2\x9c\x97' )
  icon_proof=$( [ "$DEVNET_PROOF" = "running" ] && printf '\xe2\x9c\x93' || printf '\xe2\x9c\x97' )

  devnet_text=" Devnet ${icon_node}${icon_indexer}${icon_proof} "

  # Color: all running = SUCCESS, all down = ERROR, mixed = WARNING
  running_count=0
  [ "$DEVNET_NODE" = "running" ] && running_count=$((running_count + 1))
  [ "$DEVNET_INDEXER" = "running" ] && running_count=$((running_count + 1))
  [ "$DEVNET_PROOF" = "running" ] && running_count=$((running_count + 1))

  if [ "$running_count" -eq 3 ]; then
    add_segment "$devnet_text" "$SUCCESS_BG" "$SUCCESS_FG"
  elif [ "$running_count" -eq 0 ]; then
    add_segment "$devnet_text" "$ERROR_BG" "$ERROR_FG"
  else
    add_segment "$devnet_text" "$WARNING_BG" "$WARNING_FG"
  fi
else
  add_segment " No devnet " "$TERTIARY_BG" "$TERTIARY_FG"
fi
```

**Step 3: Verify parse**

Run: `bash -n plugins/midnight-tooling/scripts/sl.sh`
Expected: No output

**Step 4: Commit**

```bash
git add plugins/midnight-tooling/scripts/sl.sh
git commit -m "feat(statusline): replace proof server segment with devnet icon grid"
```

---

### Task 6: Update compact segment to slash-separated format

**Files:**
- Modify: `plugins/midnight-tooling/scripts/sl.sh:534-546` (Segment 3: Compact CLI)

**Step 1: Replace the compact segment block**

```bash
# Segment 3: Compact CLI
if [ "$COMPACT_INSTALLED" -eq 1 ]; then
  compact_text=" \xe2\x9a\x99 compactc"
  if [ -n "$COMPACT_VERSION" ]; then
    compact_text="${compact_text} ${COMPACT_VERSION}"
    if [ -n "$COMPACT_LANG_VERSION" ]; then
      compact_text="${compact_text}/${COMPACT_LANG_VERSION}"
    fi
  fi
  if [ "$COMPACT_UPDATE" = "update" ]; then
    compact_text="${compact_text} \xe2\x86\x91"
    add_segment "${compact_text} " "$WARNING_BG" "$WARNING_FG"
  else
    add_segment "${compact_text} " "$INFO_BG" "$INFO_FG"
  fi
fi
```

Key changes from original:
- No `v` prefix before version numbers
- Slash-separated: `compactc 0.16.0/0.29.0` instead of `compactc v0.16.0`
- Language version appended only if available

**Step 2: Verify parse**

Run: `bash -n plugins/midnight-tooling/scripts/sl.sh`
Expected: No output

**Step 3: Commit**

```bash
git add plugins/midnight-tooling/scripts/sl.sh
git commit -m "feat(statusline): update compact segment to slash-separated version format"
```

---

### Task 7: Update script header comment

**Files:**
- Modify: `plugins/midnight-tooling/scripts/sl.sh:2-3`

**Step 1: Update the header to reflect new functionality**

Change:
```bash
# Midnight Network StatusLine for Claude Code
# Displays proof server and Compact CLI status in the status bar.
```

To:
```bash
# Midnight Network StatusLine for Claude Code
# Displays local devnet node status and Compact CLI version in the status bar.
```

**Step 2: Commit**

```bash
git add plugins/midnight-tooling/scripts/sl.sh
git commit -m "docs(statusline): update script header comment"
```

---

### Task 8: Manual integration test

**Step 1: Syntax check**

Run: `bash -n plugins/midnight-tooling/scripts/sl.sh`
Expected: No output (clean parse)

**Step 2: Test with no devnet running (your current state)**

Run: `echo '{"workspace":{"project_dir":"'"$(pwd)"'"}}' | bash plugins/midnight-tooling/scripts/sl.sh`

Expected output: Powerline-styled segments showing:
- `🌙 Midnight` (primary colors)
- `No devnet` (tertiary/muted colors)
- `⚙ compactc X.Y.Z/A.B.C` (info colors, if compact is installed)

**Step 3: Test with devnet running (if you can start it)**

Run: `npx @aaronbassett/midnight-local-devnet start` then re-run the statusline.

Expected: Devnet segment changes from "No devnet" to "Devnet ✓✓✓" (or partial ✓✗ if some services are still starting).

**Step 4: Test cache behavior**

Run the statusline twice within 5 seconds — second run should return instantly from cache.

**Step 5: Test with env var override**

Run: `MIDNIGHT_TOOLING_STATUSLINE_ACTIVE=1 echo '{}' | bash plugins/midnight-tooling/scripts/sl.sh`

Expected: Should show Midnight segments even outside a Midnight project directory.

**Step 6: Final commit (squash-ready)**

If all tests pass, no additional commit needed. The feature is complete across Tasks 1–7.
