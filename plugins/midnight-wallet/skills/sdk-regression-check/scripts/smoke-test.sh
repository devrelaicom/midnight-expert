#!/usr/bin/env bash
# Spin up a temp project with the LATEST published @midnight-ntwrk/wallet-sdk-*
# packages, then run the smoke-test fixture against the local devnet.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE="${SCRIPT_DIR}/fixtures/smoke-test.ts"

if [[ ! -f "$FIXTURE" ]]; then
  echo "ERROR: smoke-test fixture missing at $FIXTURE" >&2
  exit 2
fi

if ! curl -fsS http://localhost:9944/health >/dev/null 2>&1; then
  echo "ERROR: local devnet node not reachable at http://localhost:9944/health" >&2
  echo "       Start the devnet with /midnight-tooling:devnet start" >&2
  exit 2
fi

WORKDIR="$(mktemp -d -t midnight-smoke-XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT
echo "Working in $WORKDIR"

cd "$WORKDIR"
npm init -y >/dev/null
npm pkg set type=module

PACKAGES=(
  "@midnight-ntwrk/wallet-sdk"
  "@midnight-ntwrk/wallet-sdk-facade"
  "@midnight-ntwrk/wallet-sdk-hd"
  "@midnight-ntwrk/wallet-sdk-shielded"
  "@midnight-ntwrk/wallet-sdk-unshielded-wallet"
  "@midnight-ntwrk/wallet-sdk-dust-wallet"
  "@midnight-ntwrk/wallet-sdk-capabilities"
  "@midnight-ntwrk/wallet-sdk-abstractions"
  "@midnight-ntwrk/wallet-sdk-address-format"
  "@midnight-ntwrk/wallet-sdk-runtime"
  "@midnight-ntwrk/wallet-sdk-utilities"
  "@midnight-ntwrk/wallet-sdk-indexer-client"
  "@midnight-ntwrk/wallet-sdk-node-client"
  "@midnight-ntwrk/wallet-sdk-prover-client"
  "@midnight-ntwrk/ledger-v8"
  "ws"
  "rxjs"
)
echo "Installing latest packages…"
npm install --silent "${PACKAGES[@]}"
npm install --silent -D tsx typescript @types/node @types/ws

cp "$FIXTURE" "$WORKDIR/smoke-test.ts"

echo "Running smoke fixture…"
START=$(date +%s)
if npx tsx "$WORKDIR/smoke-test.ts"; then
  END=$(date +%s)
  echo "PASS — smoke test completed in $((END-START))s"
  exit 0
else
  END=$(date +%s)
  echo "FAIL — smoke test failed after $((END-START))s"
  exit 1
fi
