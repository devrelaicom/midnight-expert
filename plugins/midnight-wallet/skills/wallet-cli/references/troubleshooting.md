# Troubleshooting Reference

Error codes, exit codes, and diagnostic steps for `midnight-wallet-cli` failures.

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Unknown error |
| `2` | Invalid arguments (`INVALID_ARGS`) |
| `3` | Wallet not found (`WALLET_NOT_FOUND`) |
| `4` | Network error (`NETWORK_ERROR`) |
| `5` | Insufficient balance or dust required (`INSUFFICIENT_BALANCE` / `DUST_REQUIRED`) |
| `6` | Transaction rejected, stale UTXO, or proof timeout (`TX_REJECTED` / `STALE_UTXO` / `PROOF_TIMEOUT`) |
| `7` | Cancelled (`CANCELLED`) |

---

## Network Errors

Symptoms: `NETWORK_ERROR`, `ECONNREFUSED`, WebSocket connection failures, timeout waiting for indexer.

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `ECONNREFUSED` on node port 9944 | Devnet node not running | Run `/midnight-tooling:devnet start`, then `/midnight-tooling:devnet health` |
| `ECONNREFUSED` on indexer port 8088 | Indexer not running or not yet ready | Run `/midnight-tooling:devnet health` to wait for indexer readiness |
| `ECONNREFUSED` on proof server port 6300 | Proof server not running | Run `/midnight-tooling:devnet health`, or `/midnight-tooling:devnet restart` if it crashed |
| WebSocket timeout from indexer | Indexer starting up | Wait 30 seconds, then retry |
| Balance query hangs indefinitely | Indexer not synced with node | Run `/midnight-tooling:devnet logs` and look for indexer errors; restart with `/midnight-tooling:devnet restart` |
| `NETWORK_ERROR` on all tools | Devnet fully stopped | Run `/midnight-tooling:devnet start` and wait for all services |
| `NETWORK_ERROR` only on proof-dependent tools | Proof server OOM crash | Run `/midnight-tooling:devnet restart`; check Docker memory limits |

### Devnet diagnostic commands

```
/midnight-tooling:devnet status    ← shows running containers
/midnight-tooling:devnet health    ← shows service health checks
/midnight-tooling:devnet logs      ← streams recent log output
/midnight-tooling:devnet restart   ← stops and restarts all services
```

---

## Wallet Errors

Symptoms: `WALLET_NOT_FOUND`, invalid seed/mnemonic errors, permission denied.

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `WALLET_NOT_FOUND` | Wallet name doesn't match any file | Call `midnight_wallet_list` to see available wallets. Check spelling. |
| `No active wallet` | `midnight_wallet_use` has not been called | Call `midnight_wallet_use { "name": "alice" }` or pass `wallet` to each tool. |
| `Invalid seed: must be 64 hex characters` | Seed wrong length or non-hex chars | Verify seed is exactly 64 lowercase hex characters. |
| `Invalid mnemonic` | Wrong word count or invalid words | Count words (must be 24), verify each word is in the BIP-39 English wordlist. |
| `Permission denied: ~/.midnight/wallets/` | File permissions corrupted | Run `chmod 0700 ~/.midnight ~/.midnight/wallets` in a terminal. |
| `wallet file already exists` | Name collision | Use `"force": true` to overwrite, or choose a different name. |
| Wallet shows wrong address | Using the wrong network for the current wallet | Address is network-specific. Verify `network` parameter matches the active devnet. |

---

## Transaction Errors

Symptoms: `DUST_REQUIRED`, `STALE_UTXO`, `INSUFFICIENT_BALANCE`, `TX_REJECTED`, `PROOF_TIMEOUT`.

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `DUST_REQUIRED` | Dust not registered for this wallet | Call `midnight_dust_register` before `midnight_transfer`. |
| `INSUFFICIENT_BALANCE` | Not enough NIGHT | Call `midnight_airdrop` to top up (undeployed only), or receive a transfer. |
| `STALE_UTXO` | A UTXO was consumed by a concurrent transaction before this one was submitted | Wait 5–10 seconds, then retry. Use `"no-cache": true` on the retry call. |
| `PROOF_TIMEOUT` | Proof server didn't respond in time | Check proof server with `/midnight-tooling:devnet health`. Restart with `/midnight-tooling:devnet restart`. |
| `TX_REJECTED` after airdrop on testnet | Airdrop only works on `undeployed` | Use the testnet faucet: https://faucet.preprod.midnight.network/ or https://faucet.preview.midnight.network/ |
| Transfer succeeds but balance doesn't update | Indexer lag | Wait a few seconds and call `midnight_balance` again. |
| Dust registered but transfer still fails with `DUST_REQUIRED` | Stale cache | Call `midnight_cache_clear`, then retry. |
| `TX_REJECTED` without clear reason | Protocol error or UTXO issue | Call `midnight_cache_clear`, wait 10 seconds, retry. If persistent, restart the devnet. |

### Stale UTXO Recovery

Stale UTXO errors (`STALE_UTXO`, exit code 6) occur when two operations try to spend the same UTXO. Recovery steps:

1. Wait 5–10 seconds.
2. Call `midnight_cache_clear` to force a fresh sync.
3. Retry the operation with `"no-cache": true`.

---

## Configuration Errors

Symptoms: `unknown config key`, invalid network name, invalid URL format.

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `Unknown config key` | Typo in key name | Valid keys: `network`, `proof-server`, `node`, `indexer-ws`, `wallet`. |
| `Invalid network` | Network name not in enum | Valid values: `undeployed`, `preprod`, `preview`. |
| `Invalid URL` for endpoint config | Malformed URL string | Ensure URL includes scheme (`http://` or `ws://`) and port. |
| Wallet-cli connecting to wrong endpoint | Stale config override | Call `midnight_config_unset` to restore auto-detection. |
| Auto-detection fails | Docker not running or no containers found | Start Docker. Run `/midnight-tooling:devnet start`. |

---

## Localnet Conflict Errors

If you see Docker port binding errors or container name conflicts:

| Symptom | Cause | Fix |
|---------|-------|-----|
| `port is already allocated` | Both wallet-cli localnet and devnet skill containers running on same port | Stop one: `/midnight-tooling:devnet stop` will stop the devnet skill containers. Do NOT use `midnight_localnet_stop` — it targets different container names. |
| `container name already in use` | Stale container from a previous run | Run `/midnight-tooling:devnet stop` then `/midnight-tooling:devnet start`. Do not use `midnight_localnet_clean` without explicit user confirmation. |
| `midnight_localnet_up` fails immediately | Devnet is already running | Do not use `midnight_localnet_*` lifecycle commands. Use `/midnight-tooling:devnet` instead. |

---

## Quick Diagnostic Checklist

When wallet operations fail with unexpected errors:

1. Is the devnet running? → `/midnight-tooling:devnet status`
2. Are all services healthy? → `/midnight-tooling:devnet health`
3. Does the wallet exist? → `midnight_wallet_list`
4. Is there a NIGHT balance? → `midnight_balance`
5. Is dust registered? → `midnight_dust_status`
6. Is the cache stale? → `midnight_cache_clear`, then retry
7. Are there recent errors in the logs? → `/midnight-tooling:devnet logs`
8. Is the network set correctly? → `midnight_config_get { "key": "network" }`
