---
name: midnight-wallet:fund-mnemonic
description: Derive a wallet from a BIP-39 mnemonic, fund it, and register dust
argument-hint: <name> "<24-word mnemonic>"
---

Derive a wallet from a BIP-39 mnemonic and set it up for use on the active network.

## Flow

1. Call `midnight_wallet_generate` with the provided name and `--mnemonic` flag
2. Extract the generated wallet's address for the active network from the response
3. Hand off to the `setup-test-wallets` skill: `/midnight-wallet:setup-test-wallets <name> <address>`

The setup-test-wallets skill will fund via airdrop (if on undeployed network), register dust, and save the wallet alias.

## Usage

```
/midnight-wallet:fund-mnemonic alice "word1 word2 word3 ... word24"
```

## Arguments

- `<name>` — Name for the wallet (used as both wallet-cli name and alias)
- `<mnemonic>` — 24-word BIP-39 mnemonic (must be quoted)

## Error Handling

- If the mnemonic is invalid, `midnight_wallet_generate` will return an error. Report it to the user.
- If a wallet with the given name already exists in wallet-cli, the generate step will fail. Suggest using a different name or `midnight_wallet_remove` first.
- If the network is not `undeployed`, the airdrop step in setup-test-wallets will be skipped (user needs to fund via faucet).
