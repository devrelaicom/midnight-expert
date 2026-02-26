---
title: Fungible Token Template
type: pattern
description: A complete custom fungible token contract pattern — minting, sending, receiving, and balance tracking using Midnight's Zswap shielded pool.
links:
  - token-operations
  - coin-lifecycle
  - send-result-change-handling
  - standard-library-functions
  - access-control-pattern
  - export-and-visibility
  - constructor-circuit
  - maybe-and-either-types
  - starter-contract-templates
---

# Fungible Token Template

This pattern provides the skeleton of a complete custom fungible token contract on Midnight. All token operations use the shielded pool via Zswap, meaning token balances and transfers are private by default.

## Contract Structure

```compact
pragma language_version >= 0.18.0;
import CompactStandardLibrary;

// Token domain separator — must be stable across contract lifetime
const TOKEN_DOMAIN: Bytes<32> = pad(32, "myproject:TOKEN");

// Ledger
sealed ledger admin: Bytes<32>;
export ledger totalMinted: Counter;
export ledger vault: QualifiedCoinInfo;

// Witnesses
witness getAdminKey(): Bytes<32>;
witness getNonce(): Bytes<32>;

// Constructor
constructor(adminKey: Bytes<32>) {
  admin = disclose(adminKey);
}

// Access control (see access-control-pattern)
circuit requireAdmin(): [] {
  const key = getAdminKey();
  assert persistentHash<Bytes<32>>(key) == admin "Not admin";
}

// Mint new tokens
export circuit mint(
  recipient: Either<ZswapCoinPublicKey, ContractAddress>,
  amount: Uint<128>
): CoinInfo {
  requireAdmin();
  const nonce = getNonce();
  totalMinted.increment(amount as Uint<64>);
  return mintToken(TOKEN_DOMAIN, amount, nonce, recipient);
}

// Send from contract vault
export circuit sendFromVault(
  recipient: Either<ZswapCoinPublicKey, ContractAddress>,
  amount: Uint<128>
): [] {
  requireAdmin();
  const result = send(vault, recipient, amount);
  // CRITICAL: handle change — see send-result-change-handling
  vault.writeCoin(result.change,
    right<ZswapCoinPublicKey, ContractAddress>(kernel.self()));
}
```

## Key Design Decisions

**Token domain separator**: The `TOKEN_DOMAIN` constant uniquely identifies this token type. It is combined with the contract's address via `tokenType()` internally by `mintToken()`. Changing this string creates an entirely different token — see [[token-operations]] for details.

**Admin access**: Uses the [[access-control-pattern]] with a sealed admin key from [[constructor-circuit]]. The admin hash is stored rather than the raw key for privacy.

**Vault pattern**: The contract holds its own coins in a `QualifiedCoinInfo` ledger field. When sending from the vault, the change from `send()` must be written back — ignoring it permanently destroys tokens as warned in [[send-result-change-handling]].

**Counter for total supply**: Using a Counter for `totalMinted` provides safe concurrent minting. See [[cell-and-counter]] for why Counter is preferred here.

## Minting to Users vs Contracts

The `recipient` parameter uses `Either<ZswapCoinPublicKey, ContractAddress>` from [[maybe-and-either-types]]:

```compact
// Mint to a user's wallet
mint(left<ZswapCoinPublicKey, ContractAddress>(userPubKey), 1000);

// Mint to another contract
mint(right<ZswapCoinPublicKey, ContractAddress>(dexAddress), 5000);
```

## Exporting the Right Interface

Only the public API circuits are exported per [[export-and-visibility]]. The `requireAdmin()` helper and internal logic remain unexported. The exported circuits generate TypeScript bindings as described in [[compact-to-typescript-types]], allowing DApp code to call `mint()` and `sendFromVault()` with type safety.

## Extensions

This template can be extended with:
- **Burning**: Receive coins from users and don't write the change back
- **Allowlists**: Add a Set of authorized minters
- **Supply cap**: Assert `totalMinted < maxSupply` before minting (where `maxSupply` is a sealed field from [[constructor-circuit]])
- **Multi-token**: Use different domain separators for multiple token types from the same contract

For simpler starting points before building a full token contract, see [[starter-contract-templates]].
