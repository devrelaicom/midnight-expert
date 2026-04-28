# Smoke test anatomy

The smoke fixture executes the wallet construction pattern this plugin
documents and asserts that the local-devnet `dev` preset still pre-mints
NIGHT to the genesis seed.

## Steps the fixture performs

1. **HD derivation (`hd-derive`).** Build an HD wallet from the local-devnet
   genesis seed (`0x000…001`). Select account 0 and roles `Zswap`,
   `NightExternal`, `Dust`. Derive keys at index 0. Clear the HD wallet
   from memory.

2. **Key conversion (`key-convert`).** Convert the three derived byte
   arrays into typed keys:
   - `ZswapSecretKeys.fromSeed(...)` for shielded
   - `createKeystore(...)` for unshielded
   - `DustSecretKey.fromSeed(...)` for dust

3. **Facade init (`facade-init`).** Call `WalletFacade.init({ ... })`
   with a `DefaultConfiguration` pointing at the local devnet
   (`ws://localhost:9944`, `http://localhost:8088/api/v3/graphql`,
   `http://localhost:6300`) and factory functions for each sub-wallet.

4. **Wallet start (`wallet-start`).** Call `wallet.start(shieldedSecretKeys, dustSecretKey)`.

5. **Wait for sync (`wait-sync`).** Call `wallet.waitForSyncedState()`.

6. **Balance assertion (`balance-read`).** Read
   `state.unshielded.balances[ledger.nativeToken().raw]` and assert it
   is greater than `0n`. The native token key is the token's raw bytes
   (64 hex zeros), NOT the empty string.

## What success means

If all six steps pass, the construction pattern in this plugin still
works end-to-end against the live devnet. The patterns documented in
`midnight-wallet:wallet-sdk` and `midnight-wallet:managing-test-wallets`
are validated.

## What failure means

A failure at any step is structured: the fixture prints
`{"ok":false,"step":"<step>","error":"<message>"}`. The step name
points at the layer to investigate first. See `temp-project-setup.md`
for the per-step interpretation.
