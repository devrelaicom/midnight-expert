#!/usr/bin/env bash
# Midnight Network StatusLine for Claude Code
# Displays proof server and Compact CLI status in the status bar.
# Designed to chain with any existing statusLine command.
set -euo pipefail

# =============================================================================
# Phase 0: Read stdin + configuration
# =============================================================================

STDIN_JSON=""
if ! [ -t 0 ]; then
  STDIN_JSON="$(cat)"
fi

PROJECT_DIR=""
if command -v jq >/dev/null 2>&1 && [ -n "$STDIN_JSON" ]; then
  PROJECT_DIR="$(printf '%s' "$STDIN_JSON" | jq -r '.workspace.project_dir // empty' 2>/dev/null || true)"
fi
if [ -z "$PROJECT_DIR" ]; then
  # Fallback: grep for project_dir in JSON
  PROJECT_DIR="$(printf '%s' "$STDIN_JSON" | grep -o '"project_dir" *: *"[^"]*"' 2>/dev/null | head -1 | sed 's/.*: *"//;s/"$//' || true)"
fi
if [ -z "$PROJECT_DIR" ]; then
  PROJECT_DIR="${PWD}"
fi

THEME="${MIDNIGHT_TOOLING_STATUSLINE_THEME:-marrakech}"
STYLE="${MIDNIGHT_TOOLING_STATUSLINE_STYLE:-powerline}"

# Lowercase theme and style for case-insensitive matching
THEME="$(printf '%s' "$THEME" | tr '[:upper:]' '[:lower:]')"
STYLE="$(printf '%s' "$STYLE" | tr '[:upper:]' '[:lower:]')"

# =============================================================================
# Helpers: Cross-platform compatibility
# =============================================================================

get_hash() {
  if command -v md5sum >/dev/null 2>&1; then
    printf '%s' "$1" | md5sum | cut -d' ' -f1
  elif command -v md5 >/dev/null 2>&1; then
    printf '%s' "$1" | md5
  else
    # Fallback: use cksum
    printf '%s' "$1" | cksum | cut -d' ' -f1
  fi
}

get_file_age() {
  local file="$1"
  local now
  now="$(date +%s)"
  local mtime
  if stat -f %m "$file" >/dev/null 2>&1; then
    # macOS
    mtime="$(stat -f %m "$file")"
  elif stat -c %Y "$file" >/dev/null 2>&1; then
    # Linux
    mtime="$(stat -c %Y "$file")"
  else
    # Can't determine age — treat as expired
    echo "999999"
    return
  fi
  echo "$(( now - mtime ))"
}

run_with_timeout() {
  local secs="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@" 2>/dev/null || true
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@" 2>/dev/null || true
  else
    "$@" 2>/dev/null || true
  fi
}

# =============================================================================
# Phase 1: Output cache (5s TTL) — caches ONLY our Midnight segments
# =============================================================================

DIR_HASH="$(get_hash "$PROJECT_DIR")"
OUR_CACHE="/tmp/midnight-sl-${DIR_HASH}"
CHAIN_CONF="$HOME/.midnight-expert/statusLine/chain.conf"
CHAIN_REFRESH_CACHE="/tmp/midnight-sl-chainrefresh-${DIR_HASH}"
DEVNET_HEALTH_CACHE="/tmp/midnight-devnet-health-${DIR_HASH}"
COMPACT_VER_CACHE="/tmp/midnight-compact-ver-${DIR_HASH}"

# We handle cache hit AFTER running the chained command (Phase 2),
# because the chained command must always run fresh.

# =============================================================================
# Phase 2: Discover and chain existing statusLine
# =============================================================================

discover_chain_command() {
  local cmd=""
  local settings_files=(
    "${PROJECT_DIR}/.claude/settings.local.json"
    "${PROJECT_DIR}/.claude/settings.json"
    "$HOME/.claude/settings.json"
  )

  for sf in "${settings_files[@]}"; do
    if [ -f "$sf" ]; then
      local found=""
      if command -v jq >/dev/null 2>&1; then
        found="$(jq -r '.statusLine.command // empty' "$sf" 2>/dev/null || true)"
      else
        # Fallback grep/sed for statusLine command
        found="$(grep -A1 '"statusLine"' "$sf" 2>/dev/null | grep '"command"' | sed 's/.*"command" *: *"//;s/".*$//' || true)"
      fi
      if [ -n "$found" ]; then
        # Recursion guard: skip commands that reference our own script
        case "$found" in
          *midnight-expert/statusLine*|*midnight-tooling*sl.sh*)
            continue
            ;;
        esac
        cmd="$found"
        break
      fi
    fi
  done

  echo "$cmd"
}

refresh_chain_conf() {
  # Refresh chain.conf every 5 minutes by re-scanning settings files
  local needs_refresh=1
  if [ -f "$CHAIN_REFRESH_CACHE" ]; then
    local age
    age="$(get_file_age "$CHAIN_REFRESH_CACHE")"
    if [ "$age" -lt 300 ]; then
      needs_refresh=0
    fi
  fi

  if [ "$needs_refresh" -eq 1 ]; then
    local discovered
    discovered="$(discover_chain_command)"
    if [ -n "$discovered" ]; then
      mkdir -p "$(dirname "$CHAIN_CONF")" 2>/dev/null || true
      printf '%s' "$discovered" > "$CHAIN_CONF" 2>/dev/null || true
    fi
    # Touch the refresh cache marker
    mkdir -p "$(dirname "$CHAIN_REFRESH_CACHE")" 2>/dev/null || true
    touch "$CHAIN_REFRESH_CACHE" 2>/dev/null || true
  fi
}

# Refresh chain.conf periodically
refresh_chain_conf

# Determine chain command: chain.conf first, then scan as fallback
CHAIN_CMD=""
if [ -f "$CHAIN_CONF" ]; then
  CHAIN_CMD="$(cat "$CHAIN_CONF" 2>/dev/null || true)"
fi
if [ -z "$CHAIN_CMD" ]; then
  CHAIN_CMD="$(discover_chain_command)"
fi

# Execute chained command — its output goes directly to stdout (not cached by us)
if [ -n "$CHAIN_CMD" ]; then
  printf '%s' "$STDIN_JSON" | bash -c "$CHAIN_CMD" 2>/dev/null || true
fi

# =============================================================================
# Now check OUR cache — the chained command has already run above
# =============================================================================

if [ -f "$OUR_CACHE" ]; then
  cache_age="$(get_file_age "$OUR_CACHE")"
  if [ "$cache_age" -lt 5 ]; then
    cat "$OUR_CACHE"
    exit 0
  fi
fi

# =============================================================================
# Phase 3: Midnight project detection
# =============================================================================

DETECT_CACHE="/tmp/midnight-detect-${DIR_HASH}"
IS_MIDNIGHT=0

# Fast path: env var override
if [ "${MIDNIGHT_TOOLING_STATUSLINE_ACTIVE:-}" = "1" ]; then
  IS_MIDNIGHT=1
else
  # Check detection cache (1hr TTL)
  if [ -f "$DETECT_CACHE" ]; then
    detect_age="$(get_file_age "$DETECT_CACHE")"
    if [ "$detect_age" -lt 3600 ]; then
      IS_MIDNIGHT="$(cat "$DETECT_CACHE" 2>/dev/null || echo 0)"
    fi
  fi

  if [ "$IS_MIDNIGHT" -eq 0 ] && { [ ! -f "$DETECT_CACHE" ] || [ "$(get_file_age "$DETECT_CACHE")" -ge 3600 ]; }; then
    # Detection check 1: .compact source files
    if find "$PROJECT_DIR" -maxdepth 5 -name "*.compact" -print -quit 2>/dev/null | grep -q .; then
      IS_MIDNIGHT=1
    fi

    # Detection check 2: @midnight-ntwrk in any package.json
    if [ "$IS_MIDNIGHT" -eq 0 ]; then
      if grep -r "@midnight-ntwrk" "$PROJECT_DIR" --include="package.json" -l -q 2>/dev/null; then
        IS_MIDNIGHT=1
      fi
    fi

    # Detection check 3: .compact directory
    if [ "$IS_MIDNIGHT" -eq 0 ] && [ -d "$PROJECT_DIR/.compact" ]; then
      IS_MIDNIGHT=1
    fi

    # Detection check 4: Docker files referencing midnightntwrk
    if [ "$IS_MIDNIGHT" -eq 0 ]; then
      local_docker_files="$(find "$PROJECT_DIR" -maxdepth 2 \( -name "Dockerfile*" -o -name "docker-compose*" \) 2>/dev/null || true)"
      if [ -n "$local_docker_files" ]; then
        if echo "$local_docker_files" | xargs grep -l "midnightntwrk" 2>/dev/null | grep -q .; then
          IS_MIDNIGHT=1
        fi
      fi
    fi

    # Cache the detection result
    printf '%s' "$IS_MIDNIGHT" > "$DETECT_CACHE" 2>/dev/null || true
  fi
fi

# If not a Midnight project, output nothing (chained command already printed)
if [ "$IS_MIDNIGHT" -eq 0 ]; then
  # Write empty cache so we don't re-detect for 5s
  printf '' > "$OUR_CACHE" 2>/dev/null || true
  exit 0
fi

# =============================================================================
# Phase 4: Status checks (only if Midnight project)
# =============================================================================

# --- Proof server ---
PROOF_STATUS="off"
PROOF_DETAIL=""
PROOF_PORT=6300

proof_check_url() {
  local port="$1"
  local response
  response="$(run_with_timeout 3 curl -sf --max-time 2 "http://localhost:${port}/ready" 2>/dev/null || true)"
  if [ -n "$response" ]; then
    PROOF_PORT="$port"
    local status_val=""
    local jobs_processing="" jobs_pending="" job_capacity=""
    if command -v jq >/dev/null 2>&1; then
      status_val="$(printf '%s' "$response" | jq -r '.status // empty' 2>/dev/null || true)"
      jobs_processing="$(printf '%s' "$response" | jq -r '.jobsProcessing // empty' 2>/dev/null || true)"
      jobs_pending="$(printf '%s' "$response" | jq -r '.jobsPending // empty' 2>/dev/null || true)"
      job_capacity="$(printf '%s' "$response" | jq -r '.jobCapacity // empty' 2>/dev/null || true)"
    else
      status_val="$(printf '%s' "$response" | grep -o '"status" *: *"[^"]*"' | head -1 | sed 's/.*"status" *: *"//;s/"$//' || true)"
      jobs_processing="$(printf '%s' "$response" | grep -o '"jobsProcessing" *: *[0-9]*' | head -1 | sed 's/.*: *//' || true)"
      jobs_pending="$(printf '%s' "$response" | grep -o '"jobsPending" *: *[0-9]*' | head -1 | sed 's/.*: *//' || true)"
      job_capacity="$(printf '%s' "$response" | grep -o '"jobCapacity" *: *[0-9]*' | head -1 | sed 's/.*: *//' || true)"
    fi
    case "$status_val" in
      ok|ready)
        PROOF_STATUS="ready"
        PROOF_DETAIL=""
        ;;
      busy)
        PROOF_STATUS="busy"
        if [ -n "$jobs_processing" ] && [ -n "$job_capacity" ]; then
          PROOF_DETAIL="${jobs_processing}/${job_capacity}"
        fi
        ;;
      *)
        PROOF_STATUS="ready"
        ;;
    esac
    return 0
  fi
  return 1
}

# Try default port first
if ! proof_check_url 6300; then
  # Try to find proof server via docker
  if command -v docker >/dev/null 2>&1; then
    docker_line="$(docker ps --format '{{.Names}} {{.Ports}}' 2>/dev/null | grep "proof-server" | head -1 || true)"
    if [ -n "$docker_line" ]; then
      # Extract host port mapped to 6300
      alt_port="$(printf '%s' "$docker_line" | grep -o '[0-9]*->6300' | head -1 | sed 's/->.*//' || true)"
      if [ -n "$alt_port" ] && [ "$alt_port" != "6300" ]; then
        proof_check_url "$alt_port" || true
      fi
      # Container found but not responding
      if [ "$PROOF_STATUS" = "off" ]; then
        PROOF_STATUS="starting"
        PROOF_DETAIL=""
      fi
    fi
  fi
fi

# --- Compact CLI ---
COMPACT_INSTALLED=0
COMPACT_VERSION=""
COMPACT_UPDATE=""

if command -v compact >/dev/null 2>&1; then
  COMPACT_INSTALLED=1
  COMPACT_VERSION="$(run_with_timeout 5 compact compile --version 2>/dev/null | head -1 || true)"
  # Clean up version string — extract just the version number
  COMPACT_VERSION="$(printf '%s' "$COMPACT_VERSION" | grep -o '[0-9][0-9.]*[0-9]' | head -1 || true)"

  # Update check with 30min cache
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

# =============================================================================
# Phase 5: Render with theme + style
# =============================================================================

# --- Color helpers ---
hex_to_rgb_fg() {
  local hex="$1"
  hex="${hex#\#}"
  local r=$((16#${hex:0:2}))
  local g=$((16#${hex:2:2}))
  local b=$((16#${hex:4:2}))
  printf '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
}

hex_to_rgb_bg() {
  local hex="$1"
  hex="${hex#\#}"
  local r=$((16#${hex:0:2}))
  local g=$((16#${hex:2:2}))
  local b=$((16#${hex:4:2}))
  printf '\033[48;2;%d;%d;%dm' "$r" "$g" "$b"
}

RESET='\033[0m'

# --- Themes ---
# Each theme defines: PRIMARY_BG/FG, SECONDARY_BG/FG, TERTIARY_BG/FG,
# ACCENT_BG/FG, HIGHLIGHT_BG/FG, SUCCESS_BG/FG, INFO_BG/FG,
# WARNING_BG/FG, ERROR_BG/FG, DANGER_BG/FG
load_theme() {
  case "$THEME" in
    dark)
      PRIMARY_BG="#1a1a2e" PRIMARY_FG="#e0e0e0"
      SECONDARY_BG="#16213e" SECONDARY_FG="#c8c8c8"
      TERTIARY_BG="#0f3460" TERTIARY_FG="#ffffff"
      ACCENT_BG="#533483" ACCENT_FG="#ffffff"
      HIGHLIGHT_BG="#e94560" HIGHLIGHT_FG="#ffffff"
      SUCCESS_BG="#2d6a4f" SUCCESS_FG="#d8f3dc"
      INFO_BG="#1d3557" INFO_FG="#a8dadc"
      WARNING_BG="#6b4226" WARNING_FG="#ffd166"
      ERROR_BG="#6a040f" ERROR_FG="#ffccd5"
      DANGER_BG="#9d0208" DANGER_FG="#ffffff"
      ;;
    light)
      PRIMARY_BG="#f0f0f5" PRIMARY_FG="#2d2d3f"
      SECONDARY_BG="#e0e0eb" SECONDARY_FG="#3a3a5c"
      TERTIARY_BG="#d0d0e0" TERTIARY_FG="#1a1a3e"
      ACCENT_BG="#7c3aed" ACCENT_FG="#ffffff"
      HIGHLIGHT_BG="#ec4899" HIGHLIGHT_FG="#ffffff"
      SUCCESS_BG="#059669" SUCCESS_FG="#ffffff"
      INFO_BG="#2563eb" INFO_FG="#ffffff"
      WARNING_BG="#d97706" WARNING_FG="#ffffff"
      ERROR_BG="#dc2626" ERROR_FG="#ffffff"
      DANGER_BG="#be123c" DANGER_FG="#ffffff"
      ;;
    neutral)
      PRIMARY_BG="#2d2d2d" PRIMARY_FG="#d4d4d4"
      SECONDARY_BG="#3d3d3d" SECONDARY_FG="#c0c0c0"
      TERTIARY_BG="#4d4d4d" TERTIARY_FG="#e0e0e0"
      ACCENT_BG="#6366f1" ACCENT_FG="#ffffff"
      HIGHLIGHT_BG="#8b5cf6" HIGHLIGHT_FG="#ffffff"
      SUCCESS_BG="#22c55e" SUCCESS_FG="#052e16"
      INFO_BG="#3b82f6" INFO_FG="#ffffff"
      WARNING_BG="#eab308" WARNING_FG="#422006"
      ERROR_BG="#ef4444" ERROR_FG="#ffffff"
      DANGER_BG="#dc2626" DANGER_FG="#ffffff"
      ;;
    tokyo)
      PRIMARY_BG="#1a1b26" PRIMARY_FG="#a9b1d6"
      SECONDARY_BG="#24283b" SECONDARY_FG="#c0caf5"
      TERTIARY_BG="#414868" TERTIARY_FG="#c0caf5"
      ACCENT_BG="#7aa2f7" ACCENT_FG="#1a1b26"
      HIGHLIGHT_BG="#bb9af7" HIGHLIGHT_FG="#1a1b26"
      SUCCESS_BG="#9ece6a" SUCCESS_FG="#1a1b26"
      INFO_BG="#7dcfff" INFO_FG="#1a1b26"
      WARNING_BG="#e0af68" WARNING_FG="#1a1b26"
      ERROR_BG="#f7768e" ERROR_FG="#1a1b26"
      DANGER_BG="#ff007c" DANGER_FG="#ffffff"
      ;;
    miami)
      PRIMARY_BG="#1b0a2e" PRIMARY_FG="#ff6ad5"
      SECONDARY_BG="#2d1450" SECONDARY_FG="#c774e8"
      TERTIARY_BG="#3d1e6d" TERTIARY_FG="#ad8cff"
      ACCENT_BG="#ff6ad5" ACCENT_FG="#1b0a2e"
      HIGHLIGHT_BG="#00f5d4" HIGHLIGHT_FG="#1b0a2e"
      SUCCESS_BG="#00f5d4" SUCCESS_FG="#1b0a2e"
      INFO_BG="#94b3fd" INFO_FG="#1b0a2e"
      WARNING_BG="#ffe156" WARNING_FG="#1b0a2e"
      ERROR_BG="#ff3860" ERROR_FG="#ffffff"
      DANGER_BG="#ff0055" DANGER_FG="#ffffff"
      ;;
    marrakech)
      PRIMARY_BG="#2c1810" PRIMARY_FG="#e8c39e"
      SECONDARY_BG="#3d261a" SECONDARY_FG="#d4a574"
      TERTIARY_BG="#5c3a28" TERTIARY_FG="#f0d9b5"
      ACCENT_BG="#c17f3e" ACCENT_FG="#1a0f0a"
      HIGHLIGHT_BG="#e6a64e" HIGHLIGHT_FG="#1a0f0a"
      SUCCESS_BG="#6b8e5a" SUCCESS_FG="#f0f4e8"
      INFO_BG="#4a7c8f" INFO_FG="#e8f4f8"
      WARNING_BG="#c4883e" WARNING_FG="#2c1810"
      ERROR_BG="#a63d2f" ERROR_FG="#fce8e4"
      DANGER_BG="#8b2515" DANGER_FG="#ffffff"
      ;;
    reykjavik)
      PRIMARY_BG="#0d1b2a" PRIMARY_FG="#b8d4e3"
      SECONDARY_BG="#1b2838" SECONDARY_FG="#8fb8d0"
      TERTIARY_BG="#2a3a4a" TERTIARY_FG="#c8dce8"
      ACCENT_BG="#5e81ac" ACCENT_FG="#eceff4"
      HIGHLIGHT_BG="#88c0d0" HIGHLIGHT_FG="#0d1b2a"
      SUCCESS_BG="#a3be8c" SUCCESS_FG="#0d1b2a"
      INFO_BG="#81a1c1" INFO_FG="#0d1b2a"
      WARNING_BG="#ebcb8b" WARNING_FG="#0d1b2a"
      ERROR_BG="#bf616a" ERROR_FG="#eceff4"
      DANGER_BG="#d08770" DANGER_FG="#0d1b2a"
      ;;
    cartagena)
      PRIMARY_BG="#1a1423" PRIMARY_FG="#f0e6d3"
      SECONDARY_BG="#2d1f3d" SECONDARY_FG="#e8d5b5"
      TERTIARY_BG="#402a54" TERTIARY_FG="#f5ead0"
      ACCENT_BG="#e07b4c" ACCENT_FG="#1a1423"
      HIGHLIGHT_BG="#f2a65a" HIGHLIGHT_FG="#1a1423"
      SUCCESS_BG="#4caf50" SUCCESS_FG="#e8f5e9"
      INFO_BG="#5c8a8a" INFO_FG="#e0f2f1"
      WARNING_BG="#e8963e" WARNING_FG="#1a1423"
      ERROR_BG="#c0392b" ERROR_FG="#fdecea"
      DANGER_BG="#a0261d" DANGER_FG="#ffffff"
      ;;
    berlin)
      PRIMARY_BG="#1c1c1c" PRIMARY_FG="#c8c8c8"
      SECONDARY_BG="#2a2a2a" SECONDARY_FG="#b0b0b0"
      TERTIARY_BG="#383838" TERTIARY_FG="#d8d8d8"
      ACCENT_BG="#5f87af" ACCENT_FG="#ffffff"
      HIGHLIGHT_BG="#87afd7" HIGHLIGHT_FG="#1c1c1c"
      SUCCESS_BG="#5faf5f" SUCCESS_FG="#1c1c1c"
      INFO_BG="#5f87af" INFO_FG="#ffffff"
      WARNING_BG="#d7af5f" WARNING_FG="#1c1c1c"
      ERROR_BG="#af5f5f" ERROR_FG="#ffffff"
      DANGER_BG="#d75f5f" DANGER_FG="#ffffff"
      ;;
    *)
      # Default to marrakech for unknown themes
      THEME="marrakech"
      load_theme
      return
      ;;
  esac
}

load_theme

# --- Build segments ---
# Each segment: text, bg color, fg color
SEG_COUNT=0

add_segment() {
  local text="$1" bg="$2" fg="$3"
  SEG_COUNT=$((SEG_COUNT + 1))
  eval "SEG_${SEG_COUNT}_TEXT='$text'"
  eval "SEG_${SEG_COUNT}_BG='$bg'"
  eval "SEG_${SEG_COUNT}_FG='$fg'"
}

# Segment 1: Brand
add_segment " \xf0\x9f\x8c\x99 Midnight " "$PRIMARY_BG" "$PRIMARY_FG"

# Segment 2: Proof server
case "$PROOF_STATUS" in
  ready)
    proof_text=" \xe2\xac\xa1 Proof: ready "
    if [ "$PROOF_PORT" -ne 6300 ]; then
      proof_text=" \xe2\xac\xa1 Proof: ready :${PROOF_PORT} "
    fi
    add_segment "$proof_text" "$SUCCESS_BG" "$SUCCESS_FG"
    ;;
  busy)
    proof_text=" \xe2\xac\xa1 Proof: busy"
    if [ -n "$PROOF_DETAIL" ]; then
      proof_text="${proof_text} (${PROOF_DETAIL})"
    fi
    proof_text="${proof_text} "
    if [ "$PROOF_PORT" -ne 6300 ]; then
      proof_text=" \xe2\xac\xa1 Proof: busy (${PROOF_DETAIL}) :${PROOF_PORT} "
    fi
    add_segment "$proof_text" "$WARNING_BG" "$WARNING_FG"
    ;;
  starting)
    add_segment " \xe2\xac\xa1 Proof: starting " "$WARNING_BG" "$WARNING_FG"
    ;;
  off)
    add_segment " \xe2\xac\xa1 Proof: off " "$ERROR_BG" "$ERROR_FG"
    ;;
esac

# Segment 3: Compact CLI
if [ "$COMPACT_INSTALLED" -eq 1 ]; then
  compact_text=" \xe2\x9a\x99 compactc"
  if [ -n "$COMPACT_VERSION" ]; then
    compact_text="${compact_text} v${COMPACT_VERSION}"
  fi
  if [ "$COMPACT_UPDATE" = "update" ]; then
    compact_text="${compact_text} \xe2\x86\x91"
    add_segment "${compact_text} " "$WARNING_BG" "$WARNING_FG"
  else
    add_segment "${compact_text} " "$INFO_BG" "$INFO_FG"
  fi
fi

# --- Render based on style ---
render_output() {
  local output=""
  local i

  case "$STYLE" in
    minimal)
      i=1
      while [ "$i" -le "$SEG_COUNT" ]; do
        eval "local text=\"\$SEG_${i}_TEXT\""
        eval "local bg=\"\$SEG_${i}_BG\""
        eval "local fg=\"\$SEG_${i}_FG\""
        local bg_code fg_code
        bg_code="$(hex_to_rgb_bg "$bg")"
        fg_code="$(hex_to_rgb_fg "$fg")"
        output="${output}${bg_code}${fg_code}[${text}]${RESET}"
        if [ "$i" -lt "$SEG_COUNT" ]; then
          output="${output} "
        fi
        i=$((i + 1))
      done
      ;;

    powerline)
      i=1
      while [ "$i" -le "$SEG_COUNT" ]; do
        eval "local text=\"\$SEG_${i}_TEXT\""
        eval "local bg=\"\$SEG_${i}_BG\""
        eval "local fg=\"\$SEG_${i}_FG\""
        local bg_code fg_code
        bg_code="$(hex_to_rgb_bg "$bg")"
        fg_code="$(hex_to_rgb_fg "$fg")"

        output="${output}${bg_code}${fg_code}${text}"

        # Arrow separator
        local next=$((i + 1))
        if [ "$next" -le "$SEG_COUNT" ]; then
          eval "local next_bg=\"\$SEG_${next}_BG\""
          local arrow_fg arrow_bg
          arrow_fg="$(hex_to_rgb_fg "$bg")"
          arrow_bg="$(hex_to_rgb_bg "$next_bg")"
          output="${output}${arrow_fg}${arrow_bg}\xee\x82\xb0"
        else
          # Terminal separator
          local arrow_fg
          arrow_fg="$(hex_to_rgb_fg "$bg")"
          output="${output}${RESET}${arrow_fg}\xee\x82\xb0${RESET}"
        fi
        i=$((i + 1))
      done
      ;;

    capsule)
      i=1
      while [ "$i" -le "$SEG_COUNT" ]; do
        eval "local text=\"\$SEG_${i}_TEXT\""
        eval "local bg=\"\$SEG_${i}_BG\""
        eval "local fg=\"\$SEG_${i}_FG\""
        local bg_code fg_code cap_fg
        bg_code="$(hex_to_rgb_bg "$bg")"
        fg_code="$(hex_to_rgb_fg "$fg")"
        cap_fg="$(hex_to_rgb_fg "$bg")"

        # Left cap:  (U+E0B6)
        output="${output}${cap_fg}\xee\x82\xb6${bg_code}${fg_code}${text}${RESET}${cap_fg}\xee\x82\xb4${RESET}"

        if [ "$i" -lt "$SEG_COUNT" ]; then
          output="${output} "
        fi
        i=$((i + 1))
      done
      ;;

    *)
      # Default to powerline for unknown styles
      STYLE="powerline"
      render_output
      return
      ;;
  esac

  printf '%b' "$output"
}

# =============================================================================
# Phase 6: Output
# =============================================================================

# Render our Midnight segments
OUR_OUTPUT="$(render_output)"

# Cache our output
printf '%s' "$OUR_OUTPUT" > "$OUR_CACHE" 2>/dev/null || true

# Print our output
printf '%s' "$OUR_OUTPUT"
