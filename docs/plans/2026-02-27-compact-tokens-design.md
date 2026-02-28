# Design: compact-tokens Skill

## Overview

A dedicated skill for the `compact-core` plugin covering Midnight's token system comprehensively: NIGHT/DUST economics, shielded and unshielded tokens, the account vs UTXO model, zswap protocol, token colors, the full stdlib token API, and OpenZeppelin contract patterns.

## Decisions

- **Audience:** Both architecture understanding and practical contract development
- **Organization:** Decision-tree-first (mirrors `compact-ledger`'s ADT selection approach)
- **Reference files:** Three files (architecture, operations, patterns)
- **OpenZeppelin:** Pattern extraction in skill + full commented examples in `examples/` directory
- **TypeScript:** Compact-primary with TypeScript touchpoints where essential (witness implementations, balance reads)
- **NIGHT/DUST:** Included as architecture context, not a staking tutorial
- **Existing skills:** No modifications to `compact-ledger` or other skills

## File Structure

```
plugins/compact-core/skills/compact-tokens/
├── SKILL.md
├── references/
│   ├── token-architecture.md
│   ├── token-operations.md
│   └── token-patterns.md
└── examples/
    ├── FungibleToken.compact
    ├── NonFungibleToken.compact
    ├── MultiToken.compact
    └── ShieldedFungibleToken.compact
```

## SKILL.md Structure

### Frontmatter

- **name:** compact-tokens
- **description:** This skill should be used when the user asks about Midnight tokens, token types (NIGHT, DUST, shielded, unshielded), minting and burning tokens, token transfers, token colors and domain separators, the zswap protocol, ShieldedCoinInfo, QualifiedShieldedCoinInfo, Kernel mint operations, contract token patterns (FungibleToken, NonFungibleToken, MultiToken), the account model vs UTXO model for tokens, sendShielded, receiveShielded, sendUnshielded, mintShieldedToken, mintUnshieldedToken, unshieldedBalance, OpenZeppelin Compact token contracts, or choosing between shielded and unshielded token approaches.

### Sections

1. **Opening paragraph** (~3 lines) — Scope definition, cross-references to `compact-ledger` for state design and `compact-structure` for contract anatomy.

2. **Token Decision Tree** (~20 lines) — Table-driven decision guide mapping needs to approaches and key functions:
   - Private balances/transfers → Shielded ledger tokens (zswap UTXO)
   - Transparent balances/transfers → Unshielded ledger tokens
   - Programmable fungible token (ERC20-style) → Contract token with Map state
   - NFTs or multi-token collections → Contract token with ownership Maps
   - Gas fees → DUST (generated from NIGHT, not contract-programmable)

3. **Token Types Quick Reference** (~15 lines) — Four-quadrant model table (shielded/unshielded x ledger/contract) with privacy characteristics, underlying model (UTXO vs account), and key traits.

4. **Shielded Token Operations** (~25 lines) — Key types (`ShieldedCoinInfo`, `QualifiedShieldedCoinInfo`, `ZswapCoinPublicKey`), stdlib function table for shielded ops, one mint+send code example.

5. **Unshielded Token Operations** (~20 lines) — Stdlib function table for unshielded ops, balance query caveats, one mint+send code example.

6. **Token Colors & Identification** (~10 lines) — `tokenType(domainSep, contract)`, `nativeToken()`, the `color` field in `ShieldedCoinInfo`.

7. **NIGHT & DUST** (~15 lines) — NIGHT as native utility token, DUST as shielded gas resource (not a token), generation via delegation, testnet tokens (tNIGHT/tDUST), `nativeToken()` returns the NIGHT color.

8. **Common Mistakes** (~10 lines) — Wrong-to-correct table for token-specific errors.

9. **Reference Routing** — Table pointing to three reference files and four example contracts.

## references/token-architecture.md

Deep reference for the conceptual token model.

### Sections

- **Midnight's Dual Token Model** — NIGHT (native utility token, UTXO-based) and DUST (shielded gas resource, generated from NIGHT, non-transferable). Cross-chain relationship with Cardano (cNIGHT). Delegation flow.
- **The Four Token Quadrants** — Expanded comparison matrix with use-case guidance:
  - Shielded ledger tokens (UTXO, zswap) — high-volume private payments, cross-chain bridges
  - Unshielded ledger tokens (UTXO, transparent) — public treasuries, exchange listings
  - Shielded contract tokens (account model, programmable privacy) — compliance-friendly assets
  - Unshielded contract tokens (account model, ERC20-style) — DeFi, governance, gaming
- **Zswap Protocol** — Zerocash-derived with multi-asset support. Commitments in global Merkle tree, nullifiers prevent double-spending. Offers = inputs + outputs + transient coins + balance vector. CoinInfo structure. The commitment/nullifier set difference is not directly computable (core privacy property).
- **Token Colors** — `tokenType = hash(contractAddress, domainSeparator)`. Collision resistance prevents cross-contract minting. Native token is the zero value. Domain separator conventions.
- **Account Model vs UTXO Model** — UTXO for ledger tokens (parallel processing, individual shielding). Account model for contract state (Maps, rich logic). Why Midnight uses both.
- **Shielded vs Unshielded Deep Comparison** — Full property table (sender/receiver/value/type visibility). Compliance considerations (viewing keys for shielded).

## references/token-operations.md

Exhaustive API reference for all token-related types and functions.

### Sections

- **Types** — Field-level documentation:
  - `ShieldedCoinInfo` — `nonce: Bytes<32>`, `color: Bytes<32>`, `value: Uint<128>`
  - `QualifiedShieldedCoinInfo` — adds `mtIndex: Uint<64>` (Merkle tree index)
  - `ShieldedSendResult` — `change: Maybe<ShieldedCoinInfo>`, `sent: ShieldedCoinInfo`
  - `ZswapCoinPublicKey` — `bytes: Bytes<32>`
  - `UserAddress` — `bytes: Bytes<32>`
  - `ContractAddress` — `bytes: Bytes<32>`
- **Token Type Functions** — `nativeToken()`, `tokenType(domainSep, contract)` with signatures and examples.
- **Shielded Token Functions** — Complete table with full signatures:
  - `mintShieldedToken(domainSep, value, nonce, recipient)`
  - `receiveShielded(coin)`
  - `sendShielded(input, recipient, value)` → `ShieldedSendResult`
  - `sendImmediateShielded(input, target, value)` → `ShieldedSendResult`
  - `mergeCoin(a, b)`, `mergeCoinImmediate(a, b)`
  - `evolveNonce(index, nonce)`
  - `shieldedBurnAddress()`, `ownPublicKey()`
  - `createZswapOutput`, `createZswapInput` (low-level, typically not called manually)
- **Unshielded Token Functions** — Complete table:
  - `mintUnshieldedToken(domainSep, value, recipient)` → `Bytes<32>` (color)
  - `sendUnshielded(color, amount, recipient)`
  - `receiveUnshielded(color, amount)`
  - `unshieldedBalance(color)` — with stale-read caveat
  - `unshieldedBalanceLt/Gte/Gt/Lte(color, amount)` — preferred over `unshieldedBalance`
- **Kernel Token Operations** — `kernel.mintShielded`, `kernel.mintUnshielded`, balance and comparison functions, claim operations.
- **Recipient Addressing** — `Either<ZswapCoinPublicKey, ContractAddress>` for shielded, `Either<ContractAddress, UserAddress>` for unshielded, constructed with `left()`/`right()`.
- **TypeScript Touchpoints** — Witness implementations for shielded coin operations, reading token balances from contract state, brief wallet DUST registration flow.

## references/token-patterns.md

Practical patterns and OpenZeppelin integration.

### Sections

- **Minting Patterns** — Shielded mint with domain separator, unshielded mint to self/contract/user, mint with access control. Code examples.
- **Transfer Patterns** — Shielded send with change handling (`ShieldedSendResult`), unshielded send, contract-to-contract considerations and current limitations.
- **Burn Patterns** — Shielded burn via `shieldedBurnAddress()`, supply tracking challenges for shielded tokens.
- **Approval & Delegation** — Allowance pattern (FungibleToken), operator approvals (MultiToken/NonFungibleToken).
- **Supply Tracking** — Counter-based vs Uint-based supply, the shielded supply accounting problem (users can bypass contract to burn).
- **OpenZeppelin Contract Patterns** — Key patterns extracted:
  - Module composition with `import ... prefix`
  - Initializable guard for one-time setup
  - Safe/unsafe circuit pairs (blocking `ContractAddress` recipients until C2C calls are supported)
  - `_update` as the core accounting mechanism
  - `Either<ZswapCoinPublicKey, ContractAddress>` as universal account type
  - Composing tokens with access control (Ownable, AccessControl) and security (Pausable)
  - Note directing agent to review full examples for detailed reference
- **Known Limitations** — No custom spend logic for shielded tokens, no contract-to-contract calls (yet), no events in Compact, no batch operations, `Uint<128>` not `Uint<256>`, ShieldedERC20 archived status and why.

## examples/ Directory

Four comprehensively commented OpenZeppelin contracts.

### Comment Strategy

Each file includes:
- **File header** — Contract identity, limitations, maturity status (alpha/archived), source repo/version
- **Section comments** — Before each logical block (ledger state, initialization, view circuits, transfer logic, internal mechanics)
- **Inline comments** — Explaining *why* not *what* (e.g., why `disclose()` is needed, why `_unsafe` variants exist, why `shieldedBurnAddress()` represents the zero address)
- **Limitation callouts** — Clearly marked where Compact limitations force deviations from ERC standards
- **Pattern highlights** — Comments identifying reusable patterns ("module composition pattern", "safe/unsafe pair pattern")

### Files

| File | Source | Key Patterns |
|------|--------|-------------|
| `FungibleToken.compact` | OpenZeppelin/compact-contracts v0.0.1-alpha.1 | Balances Map, allowances, `_update` mechanism, overflow protection, safe/unsafe pairs |
| `NonFungibleToken.compact` | OpenZeppelin/compact-contracts v0.0.1-alpha.1 | Ownership Map, per-token + operator approvals, token URIs, authorization checks |
| `MultiToken.compact` | OpenZeppelin/compact-contracts v0.0.1-alpha.1 | Nested Maps for multi-token balances, operator-only approvals, URI with ID substitution |
| `ShieldedFungibleToken.compact` | OpenZeppelin/midnight-apps v0.0.1-alpha.0 | Zswap integration, nonce evolution, `mintShieldedToken`/`sendImmediateShielded`, burn with change |
