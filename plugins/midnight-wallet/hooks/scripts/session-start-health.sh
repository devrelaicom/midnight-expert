#!/usr/bin/env bash
set -euo pipefail

# Session-start health check for the midnight-wallet plugin.
# Runs three checks in parallel:
#   A. Wallet alias health (balances via wallet-cli)
#   B. SDK version alignment (midnight-wallet-cli vs latest @midnight-ntwrk/* deps)
#   C. Ledger version cross-check (compact compiler vs wallet-cli ledger dep)
#
# Outputs JSON to stdout:
#   { "additionalContext": "...", "systemMessage": "..." }
# systemMessage is omitted when there are no warnings.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
ALIASES_SCRIPT="${PLUGIN_ROOT}/skills/setup-test-wallets/scripts/wallet-aliases.sh"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

CHECK_A_OUT="${TMPDIR_BASE}/check_a.txt"
CHECK_B_OUT="${TMPDIR_BASE}/check_b.txt"
CHECK_C_OUT="${TMPDIR_BASE}/check_c.txt"
CHECK_B_WARN="${TMPDIR_BASE}/check_b_warn.txt"
CHECK_C_WARN="${TMPDIR_BASE}/check_c_warn.txt"

# ---------------------------------------------------------------------------
# Check A: Wallet alias health
# ---------------------------------------------------------------------------
check_a() {
  local out=""

  # Guard: aliases script must exist
  if [[ -z "$PLUGIN_ROOT" || ! -f "$ALIASES_SCRIPT" ]]; then
    echo "Wallet alias script not found — skipping alias health check." > "$CHECK_A_OUT"
    return
  fi

  # Get list of aliases (tab-separated: name\tnetwork\taddress lines, or JSON)
  # wallet-aliases.sh list outputs JSON of the wallets object
  local alias_json
  alias_json="$("$ALIASES_SCRIPT" list 2>/dev/null || echo '{}')"

  # Parse names and addresses for the undeployed network (default for health check)
  local names
  names="$(echo "$alias_json" | jq -r 'keys[]' 2>/dev/null || true)"

  if [[ -z "$names" ]]; then
    echo "No wallet aliases found. Use /setup-test-wallets to create test wallets." > "$CHECK_A_OUT"
    return
  fi

  local wallet_summaries=()

  while IFS= read -r name; do
    [[ -z "$name" ]] && continue

    # Try each network, preferring undeployed
    local address=""
    for net in undeployed preprod preview; do
      local candidate
      candidate="$(echo "$alias_json" | jq -r --arg n "$name" --arg net "$net" '.[$n][$net] // empty' 2>/dev/null || true)"
      if [[ -n "$candidate" ]]; then
        address="$candidate"
        break
      fi
    done

    if [[ -z "$address" ]]; then
      wallet_summaries+=("#${name} (no address)")
      continue
    fi

    # Attempt balance check — may fail if devnet not running
    local balance_json
    if balance_json="$(timeout 10 npx -y midnight-wallet-cli@latest balance "$address" --json 2>/dev/null)"; then
      local night_balance
      night_balance="$(echo "$balance_json" | jq -r '.balance // .NIGHT // "unknown"' 2>/dev/null || echo "unknown")"
      wallet_summaries+=("#${name} (${night_balance} NIGHT)")
    else
      # Balance check failed — devnet likely not running
      wallet_summaries+=("#${name} (balance unavailable)")
    fi
  done <<< "$names"

  if [[ ${#wallet_summaries[@]} -eq 0 ]]; then
    out="No wallet aliases found. Use /setup-test-wallets to create test wallets."
  else
    local joined
    joined="$(IFS=', '; echo "${wallet_summaries[*]}")"
    out="Wallet aliases loaded: ${joined}."
  fi

  echo "$out" > "$CHECK_A_OUT"
}

# ---------------------------------------------------------------------------
# Check B: SDK version alignment
# ---------------------------------------------------------------------------
check_b() {
  local out=""
  local warn=""

  # Get wallet-cli's @midnight-ntwrk/* dependencies
  local deps_json
  if ! deps_json="$(timeout 20 npm view midnight-wallet-cli@latest dependencies --json 2>/dev/null)"; then
    echo "Could not fetch midnight-wallet-cli dependency info (npm unavailable or network error)." > "$CHECK_B_OUT"
    return
  fi

  if [[ -z "$deps_json" || "$deps_json" == "null" ]]; then
    echo "No dependencies found for midnight-wallet-cli@latest." > "$CHECK_B_OUT"
    return
  fi

  # Extract @midnight-ntwrk/* packages and their version ranges
  local pkg_issues=()

  while IFS= read -r line; do
    local pkg version_range
    pkg="$(echo "$line" | jq -r '.[0]')"
    version_range="$(echo "$line" | jq -r '.[1]')"

    [[ -z "$pkg" || -z "$version_range" ]] && continue

    # Get all published versions and find latest stable (no pre-release suffix)
    local versions_json
    if ! versions_json="$(timeout 15 npm view "$pkg" versions --json 2>/dev/null)"; then
      continue
    fi

    local latest_stable
    latest_stable="$(echo "$versions_json" | jq -r '
      if type == "array" then .
      elif type == "string" then [.]
      else []
      end
      | map(select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$")))
      | sort_by(split(".") | map(tonumber))
      | last // empty
    ' 2>/dev/null || true)"

    if [[ -z "$latest_stable" ]]; then
      continue
    fi

    # Extract required major from version_range (strip leading ^~>=)
    local req_version
    req_version="$(echo "$version_range" | sed 's/^[^0-9]*//')"
    local req_major latest_major
    req_major="$(echo "$req_version" | cut -d. -f1)"
    latest_major="$(echo "$latest_stable" | cut -d. -f1)"

    if [[ "$req_major" != "$latest_major" ]]; then
      pkg_issues+=("${pkg}: wallet-cli requires ^${req_version} but latest stable is ${latest_stable}")
    fi
  done < <(echo "$deps_json" | jq -c 'to_entries | map(select(.key | startswith("@midnight-ntwrk/"))) | .[] | [.key, .value]')

  if [[ ${#pkg_issues[@]} -eq 0 ]]; then
    out="Wallet CLI SDK versions are current."
  else
    local joined
    joined="$(IFS='; '; echo "${pkg_issues[*]}")"
    out="SDK version issues: ${joined}."
    warn="WARNING: midnight-wallet-cli depends on outdated @midnight-ntwrk/* packages — wallet CLI may be outdated. ${joined}."
  fi

  echo "$out" > "$CHECK_B_OUT"
  [[ -n "$warn" ]] && echo "$warn" > "$CHECK_B_WARN" || true
}

# ---------------------------------------------------------------------------
# Check C: Ledger version cross-check
# ---------------------------------------------------------------------------
check_c() {
  local out=""
  local warn=""

  # Get Compact compiler ledger version
  local compact_ledger=""
  if command -v compact >/dev/null 2>&1; then
    # Try to extract ledger version from compact compile output
    local compact_out
    if compact_out="$(timeout 10 compact compile -- --ledger-version 2>&1 || true)"; then
      compact_ledger="$(echo "$compact_out" | grep -oE 'ledger-[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
    fi
    if [[ -z "$compact_ledger" ]]; then
      # Try bare --version or --ledger-version flag
      compact_out="$(timeout 5 compact --ledger-version 2>&1 || timeout 5 compact --version 2>&1 || true)"
      compact_ledger="$(echo "$compact_out" | grep -oE 'ledger-[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
    fi
  fi

  # Get wallet-cli's ledger dependency version
  local deps_json
  if ! deps_json="$(timeout 20 npm view midnight-wallet-cli@latest dependencies --json 2>/dev/null)"; then
    if [[ -z "$compact_ledger" ]]; then
      echo "Compact CLI not installed and npm unavailable — skipping ledger version check." > "$CHECK_C_OUT"
    else
      echo "Compact compiler targets ${compact_ledger}. Could not fetch wallet-cli ledger dependency (npm unavailable)." > "$CHECK_C_OUT"
    fi
    return
  fi

  # Find @midnight-ntwrk/ledger-* dependency
  local ledger_pkg ledger_version_range
  ledger_pkg="$(echo "$deps_json" | jq -r 'to_entries[] | select(.key | test("@midnight-ntwrk/ledger")) | .key' 2>/dev/null | head -1 || true)"
  ledger_version_range="$(echo "$deps_json" | jq -r 'to_entries[] | select(.key | test("@midnight-ntwrk/ledger")) | .value' 2>/dev/null | head -1 || true)"

  if [[ -z "$ledger_pkg" || -z "$ledger_version_range" ]]; then
    if [[ -z "$compact_ledger" ]]; then
      echo "Compact CLI not installed and no ledger dependency found in wallet-cli — skipping ledger cross-check." > "$CHECK_C_OUT"
    else
      echo "Compact compiler targets ${compact_ledger}. No @midnight-ntwrk/ledger-* dependency found in wallet-cli." > "$CHECK_C_OUT"
    fi
    return
  fi

  # Extract major version from wallet-cli ledger dep
  local wallet_ledger_version
  wallet_ledger_version="$(echo "$ledger_version_range" | sed 's/^[^0-9]*//')"
  local wallet_ledger_major
  wallet_ledger_major="$(echo "$wallet_ledger_version" | cut -d. -f1)"

  if [[ -z "$compact_ledger" ]]; then
    out="Compact CLI not installed — skipping ledger cross-check. Wallet CLI depends on ${ledger_pkg}@${ledger_version_range}."
    echo "$out" > "$CHECK_C_OUT"
    return
  fi

  # Extract major version from compact ledger string (e.g. "ledger-8.0.2" → "8")
  local compact_ledger_major
  compact_ledger_major="$(echo "$compact_ledger" | grep -oE '[0-9]+' | head -1 || true)"

  if [[ -z "$compact_ledger_major" || -z "$wallet_ledger_major" ]]; then
    out="Could not parse ledger major versions — compact: '${compact_ledger}', wallet-cli ledger dep: '${ledger_version_range}'."
    echo "$out" > "$CHECK_C_OUT"
    return
  fi

  if [[ "$compact_ledger_major" == "$wallet_ledger_major" ]]; then
    out="Compact compiler ledger version (${compact_ledger}) matches wallet CLI ledger dependency (${ledger_pkg}@${ledger_version_range})."
  else
    out="LEDGER VERSION MISMATCH: Compact compiler targets ${compact_ledger} (major ${compact_ledger_major}) but wallet CLI targets ${ledger_pkg}@${ledger_version_range} (major ${wallet_ledger_major}). Contracts compiled for ledger-${compact_ledger_major} may be incompatible with wallet transactions targeting ledger-${wallet_ledger_major}."
    warn="WARNING: Major ledger version mismatch — Compact compiler targets ledger-${compact_ledger_major} but wallet CLI targets ledger-${wallet_ledger_major}. Compiled contracts may not work with wallet transactions. Update either the Compact CLI or midnight-wallet-cli to align ledger versions."
  fi

  echo "$out" > "$CHECK_C_OUT"
  [[ -n "$warn" ]] && echo "$warn" > "$CHECK_C_WARN" || true
}

# ---------------------------------------------------------------------------
# Run all checks in parallel
# ---------------------------------------------------------------------------
check_a &
PID_A=$!

check_b &
PID_B=$!

check_c &
PID_C=$!

wait $PID_A || true
wait $PID_B || true
wait $PID_C || true

# ---------------------------------------------------------------------------
# Assemble output
# ---------------------------------------------------------------------------
result_a="$(cat "$CHECK_A_OUT" 2>/dev/null || echo "Wallet alias check failed.")"
result_b="$(cat "$CHECK_B_OUT" 2>/dev/null || echo "SDK version check failed.")"
result_c="$(cat "$CHECK_C_OUT" 2>/dev/null || echo "Ledger version check failed.")"

warn_b="$(cat "$CHECK_B_WARN" 2>/dev/null || true)"
warn_c="$(cat "$CHECK_C_WARN" 2>/dev/null || true)"

# Build additionalContext
additional_context="${result_a} ${result_b} ${result_c}"

# Build systemMessage (only if there are warnings)
system_message=""
if [[ -n "$warn_b" && -n "$warn_c" ]]; then
  system_message="${warn_b} ${warn_c}"
elif [[ -n "$warn_b" ]]; then
  system_message="$warn_b"
elif [[ -n "$warn_c" ]]; then
  system_message="$warn_c"
fi

# Output JSON using jq for correct escaping
if [[ -n "$system_message" ]]; then
  jq -n \
    --arg ctx "$additional_context" \
    --arg msg "$system_message" \
    '{"additionalContext": $ctx, "systemMessage": $msg}'
else
  jq -n \
    --arg ctx "$additional_context" \
    '{"additionalContext": $ctx}'
fi
