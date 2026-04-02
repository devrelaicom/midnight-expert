#!/usr/bin/env bash
set -euo pipefail

# Wallet alias manager: nickname → address mappings
# Commands: get, reverse, set, list, remove, path, random-name
# Exit codes: 0=found/success, 1=not found, 2=invalid args

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not installed" >&2
  exit 2
fi

LOCAL_FILE=".claude/midnight-wallet/wallets.local.json"
GLOBAL_FILE="$HOME/.claude/midnight-wallet/wallets.json"

ADJECTIVES=(
  swift agile bright calm clever cool crisp daring deep divine
  eager early fair fierce fiery firm fleet fresh glad golden
  grand grave green hardy keen lithe lofty loyal lucky mellow
  mild noble pious plain proud pure quiet rare robust serene
  sharp sleek slim sly smart solid stern stone strong sturdy
  brisk tall tame tidy tough true vast vivid warm wise
)

NOUNS=(
  falcon eagle hawk raven crane heron wren dove lark owl
  bear wolf fox deer boar lynx moose bison otter seal
  pine oak ash elm birch cedar maple rowan willow beech
  river brook lake pond creek ridge cliff mesa vale glen
  forge anvil blade shield arrow lance spear torch helm quill
  comet star moon dawn dusk frost bloom ember stone pearl
)

EMPTY_JSON='{"_warning":"Test wallet addresses only. Do NOT store secrets here.","wallets":{}}'

_ensure_file() {
  local file="$1"
  local dir
  dir="$(dirname "$file")"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
  fi
  if [[ ! -f "$file" ]]; then
    printf '%s\n' "$EMPTY_JSON" > "$file"
  fi
}

_read_wallets() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo '{}'
    return
  fi
  jq '.wallets // {}' "$file"
}

cmd_get() {
  local name=""
  local network=""
  local file_arg=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --network) network="$2"; shift 2 ;;
      --file) file_arg="$2"; shift 2 ;;
      -*) echo "Unknown option: $1" >&2; exit 2 ;;
      *) name="$1"; shift ;;
    esac
  done

  if [[ -z "$name" ]]; then
    echo "Usage: wallet-aliases.sh get <name> [--network <net>] [--file <path>]" >&2
    exit 2
  fi

  local files=()
  if [[ -n "$file_arg" ]]; then
    files=("$file_arg")
  else
    [[ -f "$LOCAL_FILE" ]] && files+=("$LOCAL_FILE")
    [[ -f "$GLOBAL_FILE" ]] && files+=("$GLOBAL_FILE")
  fi

  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    local entry
    entry=$(jq -r --arg name "$name" '.wallets[$name] // empty' "$f")
    if [[ -n "$entry" ]]; then
      if [[ -n "$network" ]]; then
        local addr
        addr=$(echo "$entry" | jq -r --arg net "$network" '.[$net] // empty')
        if [[ -n "$addr" ]]; then
          echo "$addr"
          return 0
        fi
      else
        echo "$entry"
        return 0
      fi
    fi
  done

  exit 1
}

cmd_reverse() {
  local address=""
  local file_arg=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) file_arg="$2"; shift 2 ;;
      -*) echo "Unknown option: $1" >&2; exit 2 ;;
      *) address="$1"; shift ;;
    esac
  done

  if [[ -z "$address" ]]; then
    echo "Usage: wallet-aliases.sh reverse <address> [--file <path>]" >&2
    exit 2
  fi

  local files=()
  if [[ -n "$file_arg" ]]; then
    files=("$file_arg")
  else
    [[ -f "$LOCAL_FILE" ]] && files+=("$LOCAL_FILE")
    [[ -f "$GLOBAL_FILE" ]] && files+=("$GLOBAL_FILE")
  fi

  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    local found
    found=$(jq -r --arg addr "$address" '
      .wallets // {} |
      to_entries[] |
      select(.value | to_entries[] | .value == $addr) |
      .key
    ' "$f" | head -1)
    if [[ -n "$found" ]]; then
      echo "$found"
      return 0
    fi
  done

  exit 1
}

cmd_set() {
  local name=""
  local network=""
  local address=""
  local addresses_json=""
  local file_arg=""
  local use_global=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --network) network="$2"; shift 2 ;;
      --address) address="$2"; shift 2 ;;
      --addresses) addresses_json="$2"; shift 2 ;;
      --file) file_arg="$2"; shift 2 ;;
      --global) use_global=true; shift ;;
      -*) echo "Unknown option: $1" >&2; exit 2 ;;
      *) name="$1"; shift ;;
    esac
  done

  if [[ -z "$name" ]]; then
    echo "Usage: wallet-aliases.sh set <name> --network <net> --address <addr> [--file <path>] [--global]" >&2
    echo "   or: wallet-aliases.sh set <name> --addresses '<json>' [--file <path>] [--global]" >&2
    exit 2
  fi

  # Determine target file
  local target_file
  if [[ -n "$file_arg" ]]; then
    target_file="$file_arg"
  elif [[ "$use_global" == true ]]; then
    target_file="$GLOBAL_FILE"
  else
    target_file="$LOCAL_FILE"
  fi

  _ensure_file "$target_file"

  if [[ -n "$addresses_json" ]]; then
    # Bulk set all networks
    local updated
    updated=$(jq --arg name "$name" --argjson addrs "$addresses_json" \
      '.wallets[$name] = $addrs' "$target_file")
    printf '%s\n' "$updated" > "$target_file"
  elif [[ -n "$network" && -n "$address" ]]; then
    # Single network set
    local updated
    updated=$(jq --arg name "$name" --arg net "$network" --arg addr "$address" \
      '.wallets[$name][$net] = $addr' "$target_file")
    printf '%s\n' "$updated" > "$target_file"
  else
    echo "set requires either (--network and --address) or --addresses" >&2
    exit 2
  fi
}

cmd_list() {
  local file_arg=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) file_arg="$2"; shift 2 ;;
      -*) echo "Unknown option: $1" >&2; exit 2 ;;
      *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
  done

  local files=()
  if [[ -n "$file_arg" ]]; then
    files=("$file_arg")
  else
    [[ -f "$GLOBAL_FILE" ]] && files+=("$GLOBAL_FILE")
    [[ -f "$LOCAL_FILE" ]] && files+=("$LOCAL_FILE")
  fi

  local merged='{}'
  for f in "${files[@]}"; do
    [[ -f "$f" ]] || continue
    local wallets
    wallets=$(_read_wallets "$f")
    merged=$(jq -n --argjson a "$merged" --argjson b "$wallets" '$a * $b')
  done

  echo "$merged"
}

cmd_remove() {
  local name=""
  local file_arg=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) file_arg="$2"; shift 2 ;;
      -*) echo "Unknown option: $1" >&2; exit 2 ;;
      *) name="$1"; shift ;;
    esac
  done

  if [[ -z "$name" ]]; then
    echo "Usage: wallet-aliases.sh remove <name> [--file <path>]" >&2
    exit 2
  fi

  local target_file
  if [[ -n "$file_arg" ]]; then
    target_file="$file_arg"
  else
    target_file="$LOCAL_FILE"
  fi

  if [[ ! -f "$target_file" ]]; then
    exit 1
  fi

  local updated
  updated=$(jq --arg name "$name" 'del(.wallets[$name])' "$target_file")
  printf '%s\n' "$updated" > "$target_file"
}

cmd_path() {
  local use_global=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --global) use_global=true; shift ;;
      -*) echo "Unknown option: $1" >&2; exit 2 ;;
      *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
  done

  if [[ "$use_global" == true ]]; then
    echo "$GLOBAL_FILE"
  else
    echo "$LOCAL_FILE"
  fi
}

cmd_random_name() {
  local file_arg=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) file_arg="$2"; shift 2 ;;
      -*) echo "Unknown option: $1" >&2; exit 2 ;;
      *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
  done

  # Get existing aliases to avoid collisions
  local existing
  existing=$(cmd_list ${file_arg:+--file "$file_arg"} 2>/dev/null | jq -r 'keys[]' 2>/dev/null || true)

  local adj_count=${#ADJECTIVES[@]}
  local noun_count=${#NOUNS[@]}
  local max_attempts=100

  for ((i = 0; i < max_attempts; i++)); do
    local adj="${ADJECTIVES[$((RANDOM % adj_count))]}"
    local noun="${NOUNS[$((RANDOM % noun_count))]}"
    local candidate="${adj}-${noun}"

    if ! echo "$existing" | grep -qx "$candidate" 2>/dev/null; then
      echo "$candidate"
      return 0
    fi
  done

  # Fallback with timestamp suffix
  local adj="${ADJECTIVES[$((RANDOM % adj_count))]}"
  local noun="${NOUNS[$((RANDOM % noun_count))]}"
  echo "${adj}-${noun}-$$"
}

# Main dispatch
if [[ $# -eq 0 ]]; then
  echo "Usage: wallet-aliases.sh <command> [options]" >&2
  echo "Commands: get, reverse, set, list, remove, path, random-name" >&2
  exit 2
fi

COMMAND="$1"
shift

case "$COMMAND" in
  get)         cmd_get "$@" ;;
  reverse)     cmd_reverse "$@" ;;
  set)         cmd_set "$@" ;;
  list)        cmd_list "$@" ;;
  remove)      cmd_remove "$@" ;;
  path)        cmd_path "$@" ;;
  random-name) cmd_random_name "$@" ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    echo "Commands: get, reverse, set, list, remove, path, random-name" >&2
    exit 2
    ;;
esac
