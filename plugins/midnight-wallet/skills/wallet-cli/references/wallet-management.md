# Wallet Management Reference

Covers wallet generation, listing, selection, inspection, and removal using the `midnight-wallet-cli` MCP tools.

---

## Wallet File Structure

Each wallet is stored as a JSON file at:

```
~/.midnight/wallets/<name>.json
```

File format:

```json
{
  "seed": "deadbeef...64hexchars",
  "mnemonic": "word1 word2 ... word24",
  "addresses": {
    "undeployed": "mn_addr_undeployed1...",
    "preprod":    "mn_addr_preprod1...",
    "preview":    "mn_addr_preview1..."
  },
  "createdAt": "2026-03-27T12:00:00.000Z"
}
```

**Security:** Wallet files contain the raw seed and mnemonic in plaintext. The wallet-cli sets restrictive file permissions on creation:

| Path | Permission |
|------|------------|
| `~/.midnight/` | `0700` (owner read/write/execute only) |
| `~/.midnight/wallets/` | `0700` |
| `~/.midnight/wallets/<name>.json` | `0600` (owner read/write only) |

These wallet files are for local development only. Never commit them or use the wallets for real funds.

---

## Cryptographic Foundations

### BIP-39 Mnemonic Generation

When no `--seed` or `--mnemonic` is provided, the wallet-cli generates:

1. **256 bits of entropy** from a cryptographically secure random source
2. A checksum byte is appended (256 ÷ 32 = 8 bits)
3. The resulting 264 bits are split into 24 groups of 11 bits each
4. Each 11-bit value indexes into the 2048-word BIP-39 wordlist
5. Result: a 24-word mnemonic phrase

The mnemonic is displayed **once at creation time** and then stored in the wallet file. It is never returned by `midnight_wallet_info` or `midnight_info` after that.

### HD Key Derivation

The Midnight wallet uses hierarchical deterministic (HD) derivation from the seed:

```
Seed (64 bytes)
  └─ Account 0
       └─ NightExternal role
            └─ Key index 0  →  Default address
            └─ Key index 1  →  Alternate address (via midnight_address --index 1)
            └─ ...
```

One seed produces a separate address for each network (`undeployed`, `preprod`, `preview`). All three addresses are stored in the wallet file at creation time.

### Multi-Network Addressing

A single seed deterministically produces different addresses for each network. This means:

- The same mnemonic restores wallets on all three networks simultaneously
- Sending NIGHT to the `undeployed` address of a wallet does not affect its `preprod` balance
- The genesis wallet (seed `0x000...001`) has a distinct address on each network

---

## Operations

### Generate a Wallet

**Tool:** `midnight_wallet_generate`

Create a new wallet with an auto-generated mnemonic:

```json
{
  "name": "alice"
}
```

Restore from a known mnemonic:

```json
{
  "name": "alice",
  "mnemonic": "word1 word2 ... word24",
  "network": "undeployed"
}
```

Restore from a raw hex seed:

```json
{
  "name": "alice",
  "seed": "deadbeef...64chars"
}
```

Overwrite an existing wallet file:

```json
{
  "name": "alice",
  "force": true
}
```

**Flags summary:**

| Flag | Purpose | Notes |
|------|---------|-------|
| `name` | Required wallet name | Becomes the filename |
| `network` | Default network | `undeployed` / `preprod` / `preview` |
| `seed` | 64-char hex | Restores from raw seed |
| `mnemonic` | 24-word phrase | Restores from BIP-39 mnemonic |
| `force` | Overwrite existing | Dangerous if the old wallet has funds |

### List Wallets

**Tool:** `midnight_wallet_list`

No parameters. Returns an array of all wallets in `~/.midnight/wallets/`, with their addresses for each network and a marker indicating which wallet is currently active.

### Set Active Wallet

**Tool:** `midnight_wallet_use`

```json
{
  "name": "alice"
}
```

Sets `alice` as the active wallet. All subsequent tool calls that accept an optional `wallet` parameter will use `alice` unless overridden.

### Inspect a Wallet

**Tool:** `midnight_wallet_info`

```json
{
  "name": "alice"
}
```

Returns wallet name, creation timestamp, and addresses. **Does not return seed or mnemonic.** If `name` is omitted, shows the active wallet.

### Remove a Wallet

**Tool:** `midnight_wallet_remove`

```json
{
  "name": "alice"
}
```

Permanently deletes `~/.midnight/wallets/alice.json`. This is irreversible. Ensure the mnemonic is backed up before removing a wallet that holds funds.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `WALLET_NOT_FOUND` — wallet does not exist | The name doesn't match any file in `~/.midnight/wallets/` | Run `midnight_wallet_list` to see available wallets. Check spelling. |
| `Error: wallet file already exists` | A wallet with that name was previously created | Add `"force": true` to overwrite, or choose a different name. |
| `Invalid seed: must be 64 hex characters` | Seed string is wrong length or contains non-hex chars | Re-check the seed. Seeds are exactly 64 lowercase hex characters. |
| `Invalid mnemonic` | Word count is not 24, or words not in BIP-39 wordlist | Count words, verify each word against the BIP-39 English wordlist. |
| `Permission denied: ~/.midnight/wallets/` | File permissions corrupted | Run `chmod 0700 ~/.midnight ~/.midnight/wallets`. |
| Address on wrong network | Wallet file has correct seed but wrong network address | Addresses are pre-derived — the wallet file already has all three. Use the address for the correct network key from the wallet file. |
| Wallet missing after system restore | Wallet files are stored locally, not backed up | Restore from the 24-word mnemonic using `midnight_wallet_generate` with the `mnemonic` parameter. |
