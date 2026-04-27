# Manual temp-project setup

`smoke-test.sh` automates these steps. Use this manual flow only when
the script fails for environmental reasons and you want to drive each
step yourself.

## Prerequisites

- Node 20+
- A running local devnet — see `midnight-tooling:devnet`
- npm

## Steps

```bash
cd "$(mktemp -d)"
npm init -y
npm pkg set type=module
npm install \
  @midnight-ntwrk/wallet-sdk \
  @midnight-ntwrk/wallet-sdk-facade \
  @midnight-ntwrk/wallet-sdk-hd \
  @midnight-ntwrk/wallet-sdk-shielded \
  @midnight-ntwrk/wallet-sdk-unshielded-wallet \
  @midnight-ntwrk/wallet-sdk-dust-wallet \
  @midnight-ntwrk/wallet-sdk-capabilities \
  @midnight-ntwrk/wallet-sdk-abstractions \
  @midnight-ntwrk/wallet-sdk-address-format \
  @midnight-ntwrk/wallet-sdk-runtime \
  @midnight-ntwrk/wallet-sdk-utilities \
  @midnight-ntwrk/wallet-sdk-indexer-client \
  @midnight-ntwrk/wallet-sdk-node-client \
  @midnight-ntwrk/wallet-sdk-prover-client \
  @midnight-ntwrk/ledger-v8 \
  ws \
  rxjs
npm install -D tsx typescript @types/node @types/ws

# Copy the fixture from the skill into this temp dir
cp <plugin>/sdk-regression-check/scripts/fixtures/smoke-test.ts ./smoke-test.ts

# Run it
npx tsx ./smoke-test.ts
```

`npm pkg set type=module` is required because the SDK packages are
published as ESM-only. Without it, the install succeeds but `npx tsx`
fails with `ERR_PACKAGE_PATH_NOT_EXPORTED`.

## Expected output

On success, `smoke-test.ts` prints a single line of JSON like
`{"ok":true,"night":"<positive>"}` and exits 0.

On failure, it prints `{"ok":false,"step":"<step>","error":"<message>"}`
and exits 1. The `step` value tells you where to look:

| step | What it means |
|------|--------------|
| `hd-derive` | `HDWallet.fromSeed` or `deriveKeysAt` failed |
| `key-convert` | `ZswapSecretKeys.fromSeed`, `DustSecretKey.fromSeed`, or `createKeystore` failed |
| `facade-init` | `WalletFacade.init` failed (factory function or configuration issue) |
| `wallet-start` | `wallet.start()` failed |
| `wait-sync` | `wallet.waitForSyncedState()` failed (devnet, indexer, or proof-server unreachable) |
| `balance-read` | Wallet synced but unshielded NIGHT balance was 0 — usually a `dev`-preset or genesis-seed issue |
