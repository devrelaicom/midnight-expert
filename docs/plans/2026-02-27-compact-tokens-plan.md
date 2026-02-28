# compact-tokens Skill Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a comprehensive `compact-tokens` skill for the `compact-core` plugin covering Midnight's full token system — NIGHT/DUST, shielded/unshielded tokens, zswap, token colors, stdlib API, and OpenZeppelin patterns.

**Architecture:** Decision-tree-first SKILL.md with three reference files (architecture, operations, patterns) and four comprehensively commented OpenZeppelin example contracts. Follows the same conventions as the existing `compact-ledger` skill.

**Tech Stack:** Compact language, Midnight MCP for research, markdown skill files

**Design doc:** `docs/plans/2026-02-27-compact-tokens-design.md`

---

## Research Requirement

Several tasks require fetching content from Midnight's ecosystem. Use the Midnight MCP tools:
- `mcp__midnight__midnight-search-compact` — Search Compact code across repositories
- `mcp__midnight__midnight-fetch-docs` — Fetch documentation pages from docs.midnight.network
- `mcp__midnight__midnight-search-docs` — Search documentation content
- `mcp__octocode-mcp__githubGetFileContent` — Fetch specific files from GitHub repos
- `mcp__octocode-mcp__githubViewRepoStructure` — Browse repository structure

Key repositories:
- `OpenZeppelin/compact-contracts` — FungibleToken, NonFungibleToken, MultiToken in `contracts/src/token/`
- `OpenZeppelin/midnight-apps` — ShieldedERC20 in `contracts/src/shielded-token/`
- `midnightntwrk/compact-export` — Standard library API docs in `doc/api/CompactStandardLibrary/`

---

### Task 1: Create Directory Structure

**Files:**
- Create: `plugins/compact-core/skills/compact-tokens/SKILL.md` (placeholder)
- Create: `plugins/compact-core/skills/compact-tokens/references/` (directory)
- Create: `plugins/compact-core/skills/compact-tokens/examples/` (directory)

**Step 1: Create directories and placeholder**

```bash
mkdir -p plugins/compact-core/skills/compact-tokens/references
mkdir -p plugins/compact-core/skills/compact-tokens/examples
```

Create a minimal placeholder `SKILL.md` to verify the skill is discoverable:

```markdown
---
name: compact-tokens
description: This skill should be used when the user asks about Midnight tokens, token types (NIGHT, DUST, shielded, unshielded), minting and burning tokens, token transfers, token colors and domain separators, the zswap protocol, ShieldedCoinInfo, QualifiedShieldedCoinInfo, Kernel mint operations, contract token patterns (FungibleToken, NonFungibleToken, MultiToken), the account model vs UTXO model for tokens, sendShielded, receiveShielded, sendUnshielded, mintShieldedToken, mintUnshieldedToken, unshieldedBalance, OpenZeppelin Compact token contracts, or choosing between shielded and unshielded token approaches.
---

# Compact Tokens

Placeholder — content to follow.
```

**Step 2: Verify structure**

```bash
find plugins/compact-core/skills/compact-tokens -type f -o -type d | sort
```

Expected output should show `SKILL.md`, `references/`, and `examples/` directories.

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-tokens/
git commit -m "feat(compact-core): scaffold compact-tokens skill directory structure"
```

---

### Task 2: Write SKILL.md

**Files:**
- Modify: `plugins/compact-core/skills/compact-tokens/SKILL.md`

**Convention reference:** Follow the structure of `plugins/compact-core/skills/compact-ledger/SKILL.md` — YAML frontmatter, concise overview, tables, code examples, reference routing. The SKILL.md is ~140 lines in `compact-ledger`; target similar size.

**Step 1: Research token functions for accurate API tables**

Use `mcp__midnight__midnight-search-compact` to verify exact function signatures for:
- Shielded: `mintShieldedToken`, `sendShielded`, `sendImmediateShielded`, `receiveShielded`, `mergeCoin`, `mergeCoinImmediate`, `evolveNonce`, `shieldedBurnAddress`, `ownPublicKey`
- Unshielded: `mintUnshieldedToken`, `sendUnshielded`, `receiveUnshielded`, `unshieldedBalance`, `unshieldedBalanceLt`, `unshieldedBalanceGte`, `unshieldedBalanceGt`, `unshieldedBalanceLte`
- Token type: `tokenType`, `nativeToken`

Also verify the types: `ShieldedCoinInfo`, `QualifiedShieldedCoinInfo`, `ShieldedSendResult`, `ZswapCoinPublicKey`, `UserAddress`, `ContractAddress`.

Cross-reference with the standard library API at `midnightntwrk/compact-export` `doc/api/CompactStandardLibrary/exports.md`.

**Step 2: Write SKILL.md content**

Write the full SKILL.md following the design doc's section plan:

1. **Opening paragraph** (~3 lines) — Scope: tokens on Midnight. Cross-references: `compact-ledger` for ledger state design, `compact-structure` for contract anatomy.

2. **Token Decision Tree** — Table with columns: Need | Approach | Key Functions. Rows:
   - Private balances/transfers → Shielded ledger tokens → `mintShieldedToken`, `sendShielded`, `receiveShielded`
   - Transparent balances/transfers → Unshielded ledger tokens → `mintUnshieldedToken`, `sendUnshielded`, `unshieldedBalance`
   - Programmable fungible token → Contract token (Map state) → OpenZeppelin FungibleToken pattern
   - NFTs / multi-token → Contract token (ownership Maps) → OpenZeppelin NonFungibleToken/MultiToken
   - Gas fees → DUST (from NIGHT) → Not contract-programmable

3. **Token Types Quick Reference** — Four-quadrant table with columns: Type | Location | Privacy | Model | Key Traits. Rows: Shielded Ledger, Unshielded Ledger, Shielded Contract, Unshielded Contract.

4. **Shielded Token Operations** — Key types table (`ShieldedCoinInfo` fields, `QualifiedShieldedCoinInfo`, `ShieldedSendResult`), function table (name, parameters, returns, purpose), and one code example showing mint + send:

   ```compact
   ledger kernel: Kernel;

   export circuit mintAndSend(
     amount: Uint<64>,
     nonce: Bytes<32>,
     recipient: Either<ZswapCoinPublicKey, ContractAddress>
   ): ShieldedCoinInfo {
     const domain = pad(32, "mytoken:");
     return mintShieldedToken(
       disclose(domain), disclose(amount) as Uint<128>,
       disclose(nonce), disclose(recipient)
     );
   }
   ```

5. **Unshielded Token Operations** — Function table, balance caveat callout, and one code example showing mint + balance check:

   ```compact
   export circuit mintAndCheck(amount: Uint<64>): Uint<128> {
     const domain = pad(32, "mytoken:");
     const color = mintUnshieldedToken(
       disclose(domain), disclose(amount),
       left<ContractAddress, UserAddress>(kernel.self())
     );
     receiveUnshielded(color, disclose(amount) as Uint<128>);
     return unshieldedBalance(color);
   }
   ```

6. **Token Colors & Identification** — Explain `tokenType = hash(contractAddress, domainSeparator)`, `nativeToken()` returns zero (NIGHT), the `color` field in `ShieldedCoinInfo`.

7. **NIGHT & DUST** — NIGHT: native utility token (UTXO-based, bridges from Cardano as cNIGHT). DUST: shielded gas resource (not a token), generated from NIGHT over time via delegation, non-transferable, used only for fees. Testnet: tNIGHT and tDUST.

8. **Common Mistakes** — Table with columns: Wrong | Correct | Why. Include:
   - Using `kernel.mintShielded` instead of `mintShieldedToken` (kernel is low-level)
   - Using `unshieldedBalance()` in logic (stale read caveat)
   - Forgetting `disclose()` on token function parameters
   - Sending shielded tokens to `ContractAddress` without `receiveShielded` on the receiving side
   - Using `Uint<64>` for shielded amounts (should be `Uint<128>`)
   - Missing `receiveUnshielded` after `mintUnshieldedToken` to self

9. **Reference Routing** — Table with columns: Topic | Reference File. Include all three references and four examples.

**Step 3: Verify conventions**

Check that:
- YAML frontmatter has `name` and `description`
- No H1 in frontmatter (only in body)
- Cross-references use backtick format (e.g., `` `compact-ledger` ``)
- Code blocks use ` ```compact ` language tag
- Tables are properly formatted markdown
- Total length is ~140-170 lines (similar to `compact-ledger` SKILL.md at 143 lines)

**Step 4: Commit**

```bash
git add plugins/compact-core/skills/compact-tokens/SKILL.md
git commit -m "feat(compact-core): add compact-tokens SKILL.md with decision-tree overview"
```

---

### Task 3: Write references/token-architecture.md

**Files:**
- Create: `plugins/compact-core/skills/compact-tokens/references/token-architecture.md`

**Convention reference:** Follow the style of `plugins/compact-core/skills/compact-ledger/references/state-design.md` (~296 lines) and `privacy-and-visibility.md` (~390 lines). Target 300-400 lines.

**Step 1: Research architecture details**

Use Midnight MCP to fetch/verify:
- `mcp__midnight__midnight-fetch-docs` with path `/learn/what-is-midnight` for dual model overview
- Search for "NIGHT DUST token delegation" in docs
- Search for "zswap" in compact repositories for protocol details
- Fetch pages under `/learn/understanding-midnights-technology/` for ledger model details
- Search for "account model UTXO" in docs

**Step 2: Write token-architecture.md**

Sections (per design doc):

1. **Header** — "Token Architecture" title, one-line description.

2. **Midnight's Dual Token Model** (~60 lines)
   - NIGHT: native utility token, exists as UTXOs on ledger, used for staking/delegation
   - Cross-chain: displayed as "NIGHT" in UIs, technically "cNIGHT" on Cardano, bridges via native bridge
   - DUST: shielded network resource (NOT a token), used exclusively for gas fees
   - DUST properties: non-transferable, value grows from associated NIGHT UTXO, decays after NIGHT spent, amount proportional to NIGHT balance
   - Delegation flow: hold NIGHT → register UTXOs → DUST generates over time → DUST pays for transactions
   - Testnet: tNIGHT (from faucet) → delegate → tDUST

3. **The Four Token Quadrants** (~80 lines)
   - Full comparison matrix table with columns: Token Type | Location | Privacy | Model | Use Cases | Key Characteristics
   - Shielded Ledger: blockchain ledger, private, UTXO, high-volume payments / cross-chain bridges, native privacy + maximum efficiency
   - Unshielded Ledger: blockchain ledger, transparent, UTXO, public treasuries / exchange listings, full transparency + high performance
   - Shielded Contract: smart contracts, private, account, compliance-friendly assets, programmable privacy + custom logic (NOTE: currently limited — ShieldedERC20 is archived)
   - Unshielded Contract: smart contracts, transparent, account, DeFi / governance / gaming, full programmability + ERC20-style
   - Choosing guidance table: Need → Best Choice → Why

4. **Zswap Protocol** (~70 lines)
   - Zerocash-derived with multi-asset support and atomic swaps
   - Core concept: coins tracked via commitment/nullifier sets — unspent coins = commitments NOT in nullifier set (not directly computable = privacy)
   - Commitments: stored in global Merkle tree + plain set (prevent duplicates) + root history (validate old proofs)
   - Nullifiers: unlinkable to their commitment (privacy property)
   - CoinInfo structure: `{ value: u128, type_: RawTokenType, nonce: [0u8; 32] }`
   - Offers: inputs (spend existing) + outputs (create new) + transient coins (created and spent same tx) + balance vector (must be non-negative)
   - Outputs: commitment + Pedersen commitment to type/value + optional contract address + optional ciphertext + ZK proof
   - Inputs: nullifier + Pedersen commitment + optional contract address + Merkle root + ZK proof

5. **Token Colors** (~40 lines)
   - Token type = 256-bit collision-resistant hash, or zero (native token/NIGHT)
   - Custom tokens: `tokenType = hash(contractAddress, domainSeparator)`
   - Collision resistance prevents cross-contract token minting
   - Domain separator: 32-byte value chosen by developer, namespaces their token type
   - In Compact: `tokenType(pad(32, "mytoken:"), kernel.self())` → `Bytes<32>`
   - The `color` field in `ShieldedCoinInfo` carries this token type identifier
   - Convention: use descriptive domain separators like `pad(32, "myapp:reward:")`

6. **Account Model vs UTXO Model** (~40 lines)
   - UTXO for ledger tokens: parallel processing (independent UTXOs), individual shielding, atomic operations, efficient state management
   - Account model for contract state: familiar programming patterns (Map-based balances), rich state management, complex logic
   - Why both: UTXO is optimal for value transfer privacy; account model is optimal for programmable state
   - Ledger state structure: coin commitment Merkle tree, nullifier set, valid past roots, contract address → contract state map

7. **Shielded vs Unshielded Deep Comparison** (~50 lines)
   - Full property comparison table: sender visible, recipient visible, value visible, token type visible, mechanism, coin representation, compliance approach
   - When to use shielded: balance privacy required, sender/receiver privacy needed, regulatory environment permits ZK-based compliance
   - When to use unshielded: transparency acceptable/desired, auditability needed, simpler integration
   - Note: shielded and unshielded are generally NOT interchangeable — choose at design time
   - Compliance: shielded tokens can use viewing keys (read-only access to shielded txs); unshielded are inherently auditable

**Step 3: Verify**

Check that all claims are sourced from MCP research. Verify total length is 300-400 lines. Ensure no duplication with SKILL.md (reference file goes deeper, SKILL.md summarizes).

**Step 4: Commit**

```bash
git add plugins/compact-core/skills/compact-tokens/references/token-architecture.md
git commit -m "feat(compact-core): add token-architecture reference for compact-tokens"
```

---

### Task 4: Write references/token-operations.md

**Files:**
- Create: `plugins/compact-core/skills/compact-tokens/references/token-operations.md`

**Convention reference:** Follow the style of `plugins/compact-core/skills/compact-ledger/references/types-and-operations.md` (~402 lines). Target 350-450 lines.

**Step 1: Research exact function signatures**

Use Midnight MCP to fetch the authoritative stdlib API:
- `mcp__octocode-mcp__githubGetFileContent` for `midnightntwrk/compact-export` file `doc/api/CompactStandardLibrary/exports.md`
- `mcp__midnight__midnight-search-compact` queries for each function name to verify parameter types
- Cross-reference with the test contracts in `midnightntwrk/compact-export/examples/camelCase/new/standard.compact`

**Step 2: Write token-operations.md**

Sections (per design doc):

1. **Header** — "Token Operations" title, one-line description: "Exhaustive API reference for all token-related types and functions in Compact."

2. **Types** (~60 lines) — Field-level documentation for each type in a table format:

   | Type | Fields | Purpose |
   |------|--------|---------|
   | `ShieldedCoinInfo` | `nonce: Bytes<32>`, `color: Bytes<32>`, `value: Uint<128>` | Describes a newly created shielded coin |
   | `QualifiedShieldedCoinInfo` | same + `mtIndex: Uint<64>` | Existing shielded coin on ledger with Merkle tree index |
   | `ShieldedSendResult` | `change: Maybe<ShieldedCoinInfo>`, `sent: ShieldedCoinInfo` | Result of send operations; check `change.is_some` |
   | `ZswapCoinPublicKey` | `bytes: Bytes<32>` | User's public key for receiving shielded coins |
   | `UserAddress` | `bytes: Bytes<32>` | User address for unshielded token recipients |
   | `ContractAddress` | `bytes: Bytes<32>` | Contract address for token recipients |

   Include notes on QualifiedShieldedCoinInfo vs ShieldedCoinInfo (qualified = already on ledger, has Merkle tree index; unqualified = newly created in this transaction).

3. **Token Type Functions** (~20 lines) — Two functions with full docs:
   - `nativeToken(): Bytes<32>` — Returns the token type of the native token (NIGHT). The native type is the zero value.
   - `tokenType(domainSep: Bytes<32>, contract: ContractAddress): Bytes<32>` — Derives a globally namespaced token type from domain separator + contract address.

4. **Shielded Token Functions** (~100 lines) — Complete table with columns: Function | Parameters | Returns | Purpose. Each function gets its own row:

   - `mintShieldedToken(domainSep: Bytes<32>, value: Uint<128>, nonce: Bytes<32>, recipient: Either<ZswapCoinPublicKey, ContractAddress>): ShieldedCoinInfo`
   - `receiveShielded(coin: ShieldedCoinInfo): []`
   - `sendShielded(input: QualifiedShieldedCoinInfo, recipient: Either<ZswapCoinPublicKey, ContractAddress>, value: Uint<128>): ShieldedSendResult`
   - `sendImmediateShielded(input: ShieldedCoinInfo, target: Either<ZswapCoinPublicKey, ContractAddress>, value: Uint<128>): ShieldedSendResult`
   - `mergeCoin(a: QualifiedShieldedCoinInfo, b: QualifiedShieldedCoinInfo): ShieldedCoinInfo`
   - `mergeCoinImmediate(a: QualifiedShieldedCoinInfo, b: ShieldedCoinInfo): ShieldedCoinInfo`
   - `evolveNonce(index: Uint<128>, nonce: Bytes<32>): Bytes<32>`
   - `shieldedBurnAddress(): Either<ZswapCoinPublicKey, ContractAddress>`
   - `ownPublicKey(): ZswapCoinPublicKey`
   - `createZswapOutput(coin: ShieldedCoinInfo, recipient: Either<ZswapCoinPublicKey, ContractAddress>): []` (low-level)
   - `createZswapInput(coin: QualifiedShieldedCoinInfo): []` (low-level)

   After the table, include usage notes:
   - `sendShielded` is for spending coins already on the ledger (have Merkle tree index)
   - `sendImmediateShielded` is for spending coins created within the same transaction
   - Always check `ShieldedSendResult.change.is_some` — if true, handle the change coin
   - `createZswapOutput`/`createZswapInput` are low-level; prefer the higher-level send/receive functions
   - `sendShielded` does not currently create coin ciphertexts — sending to another user's public key won't inform them

5. **Unshielded Token Functions** (~60 lines) — Complete table:

   - `mintUnshieldedToken(domainSep: Bytes<32>, value: Uint<64>, recipient: Either<ContractAddress, UserAddress>): Bytes<32>`
   - `sendUnshielded(color: Bytes<32>, amount: Uint<128>, recipient: Either<ContractAddress, UserAddress>): []`
   - `receiveUnshielded(color: Bytes<32>, amount: Uint<128>): []`
   - `unshieldedBalance(color: Bytes<32>): Uint<128>`
   - `unshieldedBalanceLt(color: Bytes<32>, amount: Uint<128>): Boolean`
   - `unshieldedBalanceGte(color: Bytes<32>, amount: Uint<128>): Boolean`
   - `unshieldedBalanceGt(color: Bytes<32>, amount: Uint<128>): Boolean`
   - `unshieldedBalanceLte(color: Bytes<32>, amount: Uint<128>): Boolean`

   Usage notes:
   - `mintUnshieldedToken` returns the `color` (token type) — save it for subsequent operations
   - After minting to `kernel.self()`, call `receiveUnshielded` to credit the contract's balance
   - `unshieldedBalance()` returns value at transaction construction time — if balance changes between construction and application, the tx fails. Prefer the comparison functions (`unshieldedBalanceLt`, `unshieldedBalanceGte`, etc.)
   - Mint amount is `Uint<64>` but send/balance amounts are `Uint<128>` — cast with `as Uint<128>` when needed
   - Recipient uses `Either<ContractAddress, UserAddress>` (note: reversed order from shielded's `Either<ZswapCoinPublicKey, ContractAddress>`)

6. **Kernel Token Operations** (~50 lines) — Full table:

   - `kernel.mintShielded(domainSep: Bytes<32>, amount: Uint<64>): []`
   - `kernel.mintUnshielded(domainSep: Bytes<32>, amount: Uint<64>): []`
   - `kernel.incUnshieldedOutputs(tokenType: Either<Bytes<32>, Bytes<32>>, amount: Uint<64>): []`
   - `kernel.incUnshieldedInputs(tokenType: Either<Bytes<32>, Bytes<32>>, amount: Uint<64>): []`
   - `kernel.balance(tokenType: Either<Bytes<32>, Bytes<32>>): Uint<64>`
   - `kernel.balanceLessThan(tokenType: Either<Bytes<32>, Bytes<32>>, amount: Uint<64>): Boolean`
   - `kernel.balanceGreaterThan(tokenType: Either<Bytes<32>, Bytes<32>>, amount: Uint<64>): Boolean`
   - Claim operations: `claimContractCall`, `claimZswapCoinReceive`, `claimZswapCoinSpend`, `claimZswapNullifier`, `claimUnshieldedCoinSpend`

   Notes: kernel operations are low-level building blocks. Prefer stdlib functions (`mintShieldedToken`, `sendShielded`, etc.) which compose kernel operations correctly. Kernel mint functions take `Uint<64>` while stdlib functions may accept `Uint<128>`.

7. **Recipient Addressing** (~30 lines) — Explain the two Either patterns:
   - Shielded: `Either<ZswapCoinPublicKey, ContractAddress>` — `left()` = user, `right()` = contract
   - Unshielded: `Either<ContractAddress, UserAddress>` — `left()` = contract, `right()` = user
   - Code examples showing both with `left<>()` and `right<>()` constructors
   - Note: `ownPublicKey()` returns the current user's `ZswapCoinPublicKey`
   - Note: `kernel.self()` returns the contract's own `ContractAddress`

8. **TypeScript Touchpoints** (~50 lines) — Brief but essential:
   - Witness for providing shielded coins: how a witness returns `QualifiedShieldedCoinInfo` from wallet state
   - Reading token balances from contract state in TypeScript (accessing exported ledger fields)
   - Wallet DUST registration flow: `wallet.registerNightUtxosForDustGeneration()` → wait for non-zero balance
   - TypeScript SDK types: `DomainSeparator`, `TokenType`, `tokenType()` function in `@midnight-ntwrk/ledger`

**Step 3: Verify**

Verify all function signatures against MCP research results. Check total length ~350-450 lines. Ensure tables are properly formatted.

**Step 4: Commit**

```bash
git add plugins/compact-core/skills/compact-tokens/references/token-operations.md
git commit -m "feat(compact-core): add token-operations reference for compact-tokens"
```

---

### Task 5: Write references/token-patterns.md

**Files:**
- Create: `plugins/compact-core/skills/compact-tokens/references/token-patterns.md`

**Convention reference:** Follow the style of `plugins/compact-core/skills/compact-ledger/references/privacy-and-visibility.md` (~390 lines). Target 350-450 lines.

**Step 1: Research OpenZeppelin patterns**

Use Midnight MCP to fetch key pattern implementations:
- `mcp__midnight__midnight-search-compact` for OpenZeppelin token patterns
- `mcp__octocode-mcp__githubGetFileContent` for `OpenZeppelin/compact-contracts` README (composition examples)
- Search for access control composition patterns (Ownable + FungibleToken)
- Search for the `_update` mechanism in FungibleToken and NonFungibleToken

**Step 2: Write token-patterns.md**

Sections (per design doc):

1. **Header** — "Token Patterns" title, one-line description.

2. **Minting Patterns** (~60 lines) — Three patterns with full code examples:

   a. Shielded mint with domain separator:
   ```compact
   export circuit mint(amount: Uint<64>, nonce: Bytes<32>,
       recipient: Either<ZswapCoinPublicKey, ContractAddress>): ShieldedCoinInfo {
     const domain = pad(32, "mytoken:");
     return mintShieldedToken(disclose(domain), disclose(amount) as Uint<128>,
       disclose(nonce), disclose(recipient));
   }
   ```

   b. Unshielded mint to self (contract holds tokens):
   ```compact
   export circuit mintToSelf(amount: Uint<64>): Bytes<32> {
     const domain = pad(32, "mytoken:");
     const color = mintUnshieldedToken(disclose(domain), disclose(amount),
       left<ContractAddress, UserAddress>(kernel.self()));
     receiveUnshielded(color, disclose(amount) as Uint<128>);
     return color;
   }
   ```

   c. Unshielded mint to user:
   ```compact
   export circuit mintToUser(amount: Uint<64>, user: UserAddress): Bytes<32> {
     const domain = pad(32, "mytoken:");
     return mintUnshieldedToken(disclose(domain), disclose(amount),
       right<ContractAddress, UserAddress>(disclose(user)));
   }
   ```

   d. Mint with access control (composing with Ownable):
   ```compact
   import "access/Ownable" prefix Ownable_;

   export circuit mint(amount: Uint<64>, recipient: UserAddress): Bytes<32> {
     Ownable_assertOnlyOwner();
     const domain = pad(32, "mytoken:");
     return mintUnshieldedToken(disclose(domain), disclose(amount),
       right<ContractAddress, UserAddress>(disclose(recipient)));
   }
   ```

3. **Transfer Patterns** (~50 lines) — Two patterns:

   a. Shielded send with change handling:
   ```compact
   witness getCoin(): QualifiedShieldedCoinInfo;

   export circuit sendTokens(recipient: Either<ZswapCoinPublicKey, ContractAddress>,
       amount: Uint<128>): [] {
     const coin = getCoin();
     receiveShielded(disclose(coin));
     const result = sendImmediateShielded(disclose(coin), disclose(recipient), disclose(amount));
     if (result.change.is_some) {
       const caller = left<ZswapCoinPublicKey, ContractAddress>(ownPublicKey());
       sendImmediateShielded(result.change.value, caller, result.change.value.value);
     }
   }
   ```
   Note: always handle change — if `result.change.is_some`, the leftover must go somewhere.

   b. Unshielded send from contract balance:
   ```compact
   export circuit sendFromContract(color: Bytes<32>, amount: Uint<128>,
       user: UserAddress): [] {
     assert(unshieldedBalanceGte(disclose(color), disclose(amount)), "Insufficient balance");
     sendUnshielded(disclose(color), disclose(amount),
       right<ContractAddress, UserAddress>(disclose(user)));
   }
   ```
   Note: use `unshieldedBalanceGte` instead of comparing `unshieldedBalance()` directly.

   c. Note on contract-to-contract: direct contract-to-contract transfers are not yet supported in Midnight. OpenZeppelin uses `_unsafe` variants experimentally. Plan for this limitation.

4. **Burn Patterns** (~40 lines)

   a. Shielded burn:
   ```compact
   export circuit burn(coin: ShieldedCoinInfo, amount: Uint<128>): [] {
     receiveShielded(disclose(coin));
     const result = sendImmediateShielded(disclose(coin), shieldedBurnAddress(), disclose(amount));
     if (result.change.is_some) {
       const caller = left<ZswapCoinPublicKey, ContractAddress>(ownPublicKey());
       sendImmediateShielded(result.change.value, caller, result.change.value.value);
     }
   }
   ```

   b. Supply tracking caveat: for shielded tokens, users can burn by sending directly to `shieldedBurnAddress()` without going through the contract. Any on-chain `_totalSupply` counter will become inaccurate. This is a known limitation — there is no way to enforce that burns go through the contract.

5. **Approval & Delegation** (~40 lines) — Patterns extracted from OpenZeppelin:

   a. The allowance pattern (from FungibleToken): `_allowances` Map, `approve` sets allowance, `transferFrom` checks and decrements. Include simplified code showing the core logic.

   b. Operator approvals (from MultiToken/NonFungibleToken): `_operatorApprovals` nested Map, `setApprovalForAll` toggles, checked before transfers.

   Note: these patterns only apply to unshielded contract tokens. Shielded tokens have no approval mechanism.

6. **Supply Tracking** (~30 lines)

   - Unshielded: use `ledger _totalSupply: Uint<128>` — reliable because all mints/burns go through contract circuits.
   - Shielded: `_totalSupply` is unreliable (see burn caveat above). Track mint amounts only if needed; acknowledge burns may be under-counted.
   - Counter vs Uint for supply: use `Uint<128>` for supply tracking (Counter is limited to `Uint<16>` steps and `Uint<64>` max).

7. **OpenZeppelin Contract Patterns** (~80 lines) — Key architectural patterns extracted:

   a. **Module composition**: `import "token/FungibleToken" prefix FungibleToken_;` — all OZ contracts are modules imported with prefix. Implementing contracts compose token + access control + security.

   b. **Initializable guard**: Contracts use `Initializable_assertNotInitialized()` and `Initializable_assertInitialized()` to ensure one-time setup. Constructor calls `initialize()`.

   c. **Safe/unsafe circuit pairs**: Safe variants (e.g., `transfer`) block `ContractAddress` recipients. Unsafe variants (`_unsafeTransfer`) allow them. This is a workaround until contract-to-contract calls are supported.

   d. **The `_update` mechanism**: Core accounting logic for both FungibleToken and NonFungibleToken. Handles mint (from zero address), burn (to zero address), and transfer in one circuit. Uses `shieldedBurnAddress()` as the zero address sentinel.

   e. **Universal account type**: `Either<ZswapCoinPublicKey, ContractAddress>` throughout — covers both user wallets and contract addresses.

   f. **Composing with access control**: Example showing Ownable + Pausable + FungibleToken composition in a constructor and guarded mint circuit.

   Include a note: "For complete implementations showing these patterns in full context, review the commented example contracts in the `examples/` directory."

8. **Known Limitations** (~30 lines) — Comprehensive list:
   - No custom spend logic for shielded tokens (once received, no contract can enforce behavior)
   - No contract-to-contract calls (yet) — safe circuits block ContractAddress recipients
   - No events in Compact — no Transfer/Approval event emission
   - No batch operations — Compact lacks dynamic arrays
   - `Uint<128>` not `Uint<256>` — Midnight's circuit backend limitation
   - Shielded mint limited to `Uint<64>` in `mintShieldedToken` (compiler limitation)
   - ShieldedERC20 is archived — do not use in production
   - `sendShielded` does not create coin ciphertexts — recipients other than current user won't be notified
   - No ERC165-like introspection

**Step 3: Verify**

Check total length ~350-450 lines. Ensure all code examples compile conceptually (correct types, proper `disclose()` usage, correct `left()`/`right()` constructors). Verify patterns match MCP research.

**Step 4: Commit**

```bash
git add plugins/compact-core/skills/compact-tokens/references/token-patterns.md
git commit -m "feat(compact-core): add token-patterns reference for compact-tokens"
```

---

### Task 6: Create examples/FungibleToken.compact

**Files:**
- Create: `plugins/compact-core/skills/compact-tokens/examples/FungibleToken.compact`

**Step 1: Fetch source**

Use `mcp__octocode-mcp__githubGetFileContent` to fetch `contracts/src/token/FungibleToken.compact` from `OpenZeppelin/compact-contracts` (main branch).

Also fetch `contracts/src/utils/Utils.compact` and `contracts/src/security/Initializable.compact` for context on dependencies.

**Step 2: Create comprehensively commented version**

Take the full source and add comments following the design doc's comment strategy:

- **File header block**:
  ```
  // OpenZeppelin FungibleToken for Midnight Compact
  // Source: OpenZeppelin/compact-contracts v0.0.1-alpha.1
  // Status: ALPHA — NOT AUDITED, NOT PRODUCTION-READY
  //
  // An unshielded fungible token library, inspired by ERC20 but with significant
  // differences due to Compact/Midnight constraints. See "Limitations" below.
  //
  // Limitations:
  // - Uint<128> instead of Uint<256> (circuit backend limitation)
  // - No events (Compact does not support event emission)
  // - No contract-to-contract calls (safe circuits block ContractAddress)
  // - Should NOT be called "ERC20" due to these incompatibilities
  //
  // Key patterns demonstrated:
  // - Module-based composition (import with prefix)
  // - Initializable guard for one-time setup
  // - Safe/unsafe circuit pairs
  // - _update as core accounting mechanism
  // - Either<ZswapCoinPublicKey, ContractAddress> as universal account type
  ```

- **Section comments** before each group: ledger state, initialization, view circuits, approval circuits, transfer circuits, internal circuits, the `_update` mechanism
- **Inline comments** on key lines: why `disclose()` is used, why overflow check uses MAX_UINT128, why `shieldedBurnAddress()` represents the zero address, why `_unsafe` variants exist
- **Pattern highlight comments**: `// PATTERN: Module composition — ...`, `// PATTERN: Safe/unsafe pair — ...`, `// PATTERN: _update mechanism — ...`
- **Limitation callout comments**: `// LIMITATION: ...`

Preserve the original code exactly — only add comments, do not modify logic.

**Step 3: Verify**

Check that the file contains the full original source plus comprehensive comments. Verify no logic was changed.

**Step 4: Commit**

```bash
git add plugins/compact-core/skills/compact-tokens/examples/FungibleToken.compact
git commit -m "feat(compact-core): add commented FungibleToken example for compact-tokens"
```

---

### Task 7: Create examples/NonFungibleToken.compact

**Files:**
- Create: `plugins/compact-core/skills/compact-tokens/examples/NonFungibleToken.compact`

**Step 1: Fetch source**

Use `mcp__octocode-mcp__githubGetFileContent` to fetch `contracts/src/token/NonFungibleToken.compact` from `OpenZeppelin/compact-contracts` (main branch).

**Step 2: Create comprehensively commented version**

Same comment strategy as Task 6, adapted for NFT specifics:

- **File header block**: Identity, source, alpha status, NFT-specific limitations (no safeTransfer, no baseURI, no ERC165, Uint<128> token IDs)
- **Section comments**: ownership Map, balance tracking, per-token approvals, operator approvals, token URIs, view circuits, transfer logic, internal `_update`
- **Inline comments**: why ownership is tracked separately from balances, how authorization checks work (`_checkAuthorized`), why approval is cleared on transfer, how `_update` handles mint (from zero) vs transfer vs burn (to zero)
- **Pattern highlights**: ownership tracking pattern, dual approval pattern (per-token + operator), authorization check pattern
- **Limitation callouts**: no safe transfers (no C2C acceptance callback), no batch transfers, Uint<128> IDs

**Step 3: Verify and commit**

```bash
git add plugins/compact-core/skills/compact-tokens/examples/NonFungibleToken.compact
git commit -m "feat(compact-core): add commented NonFungibleToken example for compact-tokens"
```

---

### Task 8: Create examples/MultiToken.compact

**Files:**
- Create: `plugins/compact-core/skills/compact-tokens/examples/MultiToken.compact`

**Step 1: Fetch source**

Use `mcp__octocode-mcp__githubGetFileContent` to fetch `contracts/src/token/MultiToken.compact` from `OpenZeppelin/compact-contracts` (main branch).

**Step 2: Create comprehensively commented version**

Same comment strategy, adapted for multi-token specifics:

- **File header block**: Identity, source, alpha status, most extensive limitation list (no batch ops, no introspection, no safe transfers, no per-token approvals, operator-only approval)
- **Section comments**: nested balance Maps (`Map<Uint<128>, Map<account, Uint<128>>>`), operator approvals, URI with ID substitution, transfer logic, internal `_update`
- **Inline comments**: why balances use nested Maps (token ID → account → balance), why batch operations are impossible (Compact lacks dynamic arrays), how operator approvals differ from FungibleToken's per-spender allowances
- **Pattern highlights**: nested Map initialization pattern, operator-only approval pattern, URI substitution pattern
- **Limitation callouts**: no batch operations, no per-token approvals, no balance batch queries

**Step 3: Verify and commit**

```bash
git add plugins/compact-core/skills/compact-tokens/examples/MultiToken.compact
git commit -m "feat(compact-core): add commented MultiToken example for compact-tokens"
```

---

### Task 9: Create examples/ShieldedFungibleToken.compact

**Files:**
- Create: `plugins/compact-core/skills/compact-tokens/examples/ShieldedFungibleToken.compact`

**Step 1: Fetch source**

Use `mcp__octocode-mcp__githubGetFileContent` to fetch both files from `OpenZeppelin/midnight-apps`:
- `contracts/src/shielded-token/openzeppelin/ShieldedERC20.compact` (the library module)
- `contracts/src/shielded-token/ShieldedFungibleToken.compact` (the facade/entry point)

Combine into a single commented example file (facade first, then library), or keep the library as the primary with the facade shown in a header comment as the usage pattern.

**Step 2: Create comprehensively commented version**

- **File header block**: Identity, source, **ARCHIVED** status prominently noted, why it's archived (no custom spend logic, unreliable supply tracking, no access control on mint, mint limited to Uint<64>)
- **Section comments**: nonce management, shielded minting via `mintShieldedToken`, burn via `sendImmediateShielded` to `shieldedBurnAddress()`, change coin handling
- **Inline comments**: why nonce evolution is needed (`evolveNonce` ensures unique coins), why `receiveShielded` must be called before `sendImmediateShielded`, why `_totalSupply` is unreliable for shielded tokens, how the burn flow handles change coins
- **Pattern highlights**: shielded mint pattern, nonce evolution pattern, burn-with-change pattern, token type derivation pattern
- **Limitation callouts**: archived status, no custom spend logic, supply can be silently reduced by external burns, no access control built in, mint amount limited to Uint<64>

**Step 3: Verify and commit**

```bash
git add plugins/compact-core/skills/compact-tokens/examples/ShieldedFungibleToken.compact
git commit -m "feat(compact-core): add commented ShieldedFungibleToken example for compact-tokens"
```

---

### Task 10: Final Review and Plugin Keyword Update

**Files:**
- Modify: `plugins/compact-core/.claude-plugin/plugin.json`

**Step 1: Update plugin.json keywords**

Add token-related keywords to the plugin's keyword list:

```json
"keywords": [
  "midnight",
  "compact",
  "smart-contracts",
  "zero-knowledge",
  "ledger",
  "circuits",
  "witnesses",
  "zk-proofs",
  "tokens",
  "shielded",
  "unshielded",
  "zswap"
]
```

**Step 2: Full skill review**

Read through all files in order and verify:
- SKILL.md frontmatter triggers on all intended queries
- Decision tree covers all four quadrants
- API tables in SKILL.md match reference file details
- Reference routing table lists all files correctly (3 references + 4 examples)
- Cross-references between files are accurate
- No content duplication between SKILL.md and references (SKILL.md summarizes, references go deep)
- All code examples use correct syntax: `disclose()` where needed, proper `left()`/`right()` constructors, correct types
- Example files contain full original source with comments only (no logic changes)
- No claims that contradict MCP research findings

**Step 3: Commit**

```bash
git add plugins/compact-core/.claude-plugin/plugin.json
git commit -m "feat(compact-core): add token keywords to plugin manifest"
```
