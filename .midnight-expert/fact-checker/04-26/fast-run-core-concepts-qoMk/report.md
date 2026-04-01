# Fact-Check Report: core-concepts-plugin

> This report was generated using fast-check (source-only verification). For full execution-based verification, use /check.

**Date:** 2026-04-01
**Source:** plugins/core-concepts/ (Midnight Expert plugin — 8 skills, 14 reference files, 1 agent)
**Run ID:** .midnight-expert/fact-checker/04-26/fast-run-core-concepts-qoMk

## Executive Summary

| Verdict | Count |
|---------|-------|
| Confirmed | 44 |
| Refuted | 25 |
| Inconclusive | 4 |
| Not verified (fast-check) | 110 |
| **Total extracted** | **183** |

68 of 183 claims were source-verified against `midnightntwrk/midnight-ledger` (branch `ledger-8`) and `LFDT-Minokawa/compact` (branch `main`). The remaining 110 claims (protocol schemas, tokenomics, some Compact syntax, protocol theory) were not individually verified in this fast-check run.

**Error rate among verified claims: 36.8%** (25 refuted out of 68 verified)

## Refuted Claims

_These are the actionable findings requiring correction._

| # | Claim | Source File | Evidence |
|---|-------|-------------|----------|
| claim-001 | Every transaction contains a guaranteed_zswap_offer (always present) | architecture/SKILL.md | Field is `guaranteed_coins: Option<ZswapOffer>` — Optional, not always present. Name wrong. |
| claim-002 | Every transaction contains an optional fallible_zswap_offer | architecture/SKILL.md | Field is `fallible_coins: HashMap<u16, ZswapOffer>` (map keyed by segment), not a single Option. |
| claim-003 | Every transaction contains contract_calls_or_deploys field | architecture/SKILL.md | No such field. Interactions stored in `intents: HashMap<u16, Intent>` where `Intent.actions: Array<ContractAction>`. |
| claim-007 | Fallible Zswap coin operations applied during guaranteed phase | architecture/SKILL.md | Fallible coins validated via `try_apply` during guaranteed phase but state update discarded. Actual application in own segments. |
| claim-011 | ContractCall entry_point is type String | architecture/SKILL.md | Type is `EntryPointBuf` (newtype wrapping `Vec<u8>`), not `String`. |
| claim-013 | Ledger zswap_state fields: commitment_tree, commitment_tree_first_free (u32), nullifiers (Set), commitment_tree_history (Set) | architecture/SKILL.md | All names/types wrong. Actual: `coin_coms: MerkleTree`, `first_free: u64`, `nullifiers: HashMap<Nullifier,()>`, `past_roots: TimeFilterMap<Identity<MerkleTreeDigest>>`. |
| claim-014 | ContractState has state: ImpactValue and operations: Map<String, SNARKVerifierKey> | architecture/SKILL.md | `ImpactValue` and `SNARKVerifierKey` don't exist. Actual: `data: ChargedState`, `operations: HashMap<EntryPointBuf, ContractOperation>`. |
| claim-015 | Contract Merkle trees are MerkleTree(d) Impact values with compile-time-fixed depth | architecture/SKILL.md | No "Impact values" type. Depth is runtime `u8` per node, not compile-time const generic. |
| claim-017 | ZK proof verification occurs during stateless well-formedness check | architecture/SKILL.md | Proof verification is in `op_check` which requires reference state (to look up verifier keys). Not purely stateless. |
| claim-018 | Contract call ZK proofs verified in guaranteed phase, not well-formedness | architecture/references/transaction-deep-dive.md | Proofs verified in `ContractCall::well_formed` via `op_check`. Contradicts the claim directly. |
| claim-020 | Merging requires at least one transaction with empty contract calls | architecture/SKILL.md | `merge()` has no such constraint. Only requires matching `network_id` and non-colliding segment IDs. |
| claim-022 | Token Type = Hash(contract_address, domain_separator) | architecture/SKILL.md | Argument order reversed. Actual: `Hash(domain_sep, contract_address)`. |
| claim-025 | Pedersen formula: Commit(v) = v\*G + r\*H with independent generators | architecture/references/cryptographic-binding.md | Actual: `r*G + v*hash_to_curve(type)`. v/r roles transposed; H is type-dependent, not fixed. |
| claim-026 | One Schnorr proof per transaction | architecture/references/cryptographic-binding.md | One per intent/segment. `StandardTransaction.intents` is a `HashMap` — multiple intents = multiple proofs. |
| claim-027 | Schnorr proof proves contract contribution has zero net value | architecture/references/cryptographic-binding.md | `PureGeneratorPedersen.valid()` proves knowledge of Pedersen randomness for overall coin balance, not contract contribution. |
| claim-028 | SchnorrProof has commitment (Point), challenge (Scalar), response (Scalar) | architecture/references/cryptographic-binding.md | Actual: `commitment` (Pedersen), `target` (nonce point), `reply` (scalar). Challenge is recomputed, not stored. |
| claim-033 | Input has nullifier, type_value_commit, merkle_path, zk_proof etc. | architecture/references/transaction-deep-dive.md | Actual fields: `nullifier`, `value_commitment`, `contract_address`, `merkle_tree_root`, `proof`. No `type_value_commit` or `merkle_path`. |
| claim-034 | Output has commitment, type_value_commit, ciphertext, zk_proof etc. | architecture/references/transaction-deep-dive.md | Actual: `coin_com`, `value_commitment`, `contract_address`, `ciphertext`, `proof`. All field names wrong. |
| claim-035 | Transcript has gas_bound (u64), effects with received_commitments etc. | architecture/references/transaction-deep-dive.md | `gas` is `RunningCost` not `u64`. Effects fields use different names: `claimed_shielded_receives` not `received_commitments`. |
| claim-048 | MerkleTree stores only the root on-chain | data-models/references/ledger-structure.md | Full tree structure stored (`MerkleTree<()>`), not just root. Leaf preimages hidden but tree nodes stored. |
| claim-082 | type_value_commit = type\*G_t + value\*G_v + randomness\*G_r | protocols/references/zswap-internals.md | `type_value_commit` doesn't exist as field name. Actual: 2 generators `r*G + v*hash_to_curve(type)`, not 3. |
| claim-084 | sendShielded returns SendResult | protocols/references/zswap-internals.md | Return type is `ShieldedSendResult`, not `SendResult`. |
| claim-142 | Impact VM Array(n) where 0 < n < 16 | smart-contracts/references/impact-vm.md | Upper bound is inclusive: `n <= 16`, not exclusive `n < 16`. |
| claim-143 | Context is 5-element array | smart-contracts/references/impact-vm.md | Context has 8 entries. Missing: `caller`, `balance`, `last_block_time`. "Block timestamp" is actually `seconds_since_epoch`. |
| claim-144 | Only first two context entries correctly initialized | smart-contracts/references/impact-vm.md | All 8 entries populated with real values in `ledger-8`. No reserved zero-initialized slots. |

## Results by Source File

### architecture/SKILL.md (16 verified)

| Verdict | Claim | Evidence |
|---------|-------|----------|
| REFUTED | Transaction contains guaranteed_zswap_offer (always present) | Field is `guaranteed_coins: Option<>` |
| REFUTED | Transaction contains optional fallible_zswap_offer | Field is `fallible_coins: HashMap<u16, ...>` |
| REFUTED | Transaction contains contract_calls_or_deploys | No such field; uses `intents` with `ContractAction` |
| CONFIRMED | Transaction contains binding_randomness for Pedersen commitment | `pub binding_randomness: PedersenRandomness` confirmed |
| CONFIRMED | Guaranteed section must succeed or entire tx rejected | Segment 0 failure returns original state |
| CONFIRMED | Fallible section may fail without affecting guaranteed | Non-zero segment failure preserves guaranteed state |
| REFUTED | Fallible coin ops applied during guaranteed phase | Validated but not applied during guaranteed phase |
| CONFIRMED | Only fallible effects rolled back on failure | All fallible segment effects discarded |
| CONFIRMED | Transaction binding uses Pedersen commitments | `Pedersen = EmbeddedGroupAffine` with homomorphic ops |
| REFUTED | Ledger zswap_state field names and types | All field names and types differ from actual Rust |
| REFUTED | ContractState has ImpactValue and SNARKVerifierKey | Types don't exist in codebase |
| REFUTED | Contract MerkleTree depth is compile-time-fixed | Depth is runtime u8, not const generic |
| CONFIRMED | Three execution phases: well-formedness, guaranteed, fallible | Confirmed by source structure |
| REFUTED | ZK proofs verified in stateless well-formedness | Proof verification in op_check needs state |
| CONFIRMED | Balance formula: sum(inputs) - sum(outputs) - fees + mints >= 0 | Confirmed by spec |
| REFUTED | Merging requires empty contract calls | No such constraint in merge() |

### architecture/references/cryptographic-binding.md (6 verified)

| Verdict | Claim | Evidence |
|---------|-------|----------|
| REFUTED | Pedersen Commit(v) = v\*G + r\*H | Actual: r\*G + v\*hash_to_curve(type) |
| REFUTED | One Schnorr proof per transaction | One per intent/segment, not per transaction |
| REFUTED | Schnorr proves contract zero net value | Proves knowledge of Pedersen randomness |
| REFUTED | SchnorrProof has commitment, challenge, response | Has commitment, target (nonce), reply. No stored challenge. |
| CONFIRMED | Schnorr challenge uses Fiat-Shamir | Deterministic hash of public values confirmed |
| CONFIRMED | Contract Address = Hash(contract_state, nonce) | SHA-256 of tagged ContractDeploy confirmed |

### architecture/references/transaction-deep-dive.md (4 verified)

| Verdict | Claim | Evidence |
|---------|-------|----------|
| REFUTED | Contract call proofs verified in guaranteed phase | Verified in well_formed via op_check |
| REFUTED | Input structure field names | All names differ from actual Rust |
| REFUTED | Output structure field names | All names differ from actual Rust |
| REFUTED | Transcript structure field names and types | Names and types all differ |

### architecture/references/state-management.md (2 verified)

| Verdict | Claim | Evidence |
|---------|-------|----------|
| CONFIRMED | Commitment insertion at first_free then increment | Exact behavior confirmed |
| CONFIRMED | Nullifiers persist forever, cannot be pruned | Only insert operations; no removal code |

### data-models/ (8 verified)

| Verdict | Claim | Evidence |
|---------|-------|----------|
| CONFIRMED | CoinInfo = { value, type, nonce } | Info struct matches exactly |
| CONFIRMED | Nullifier from coin data + spending key, not commitment | Confirmed in nullifier() function |
| CONFIRMED | Commitment tree append-only | first_free only incremented |
| CONFIRMED | Pedersen commitments separate from Merkle tree leaves | coin_com: Commitment vs value_commitment: Pedersen |
| CONFIRMED | UTXOs consumed atomically | Single nullifier per spend; no partial mechanism |
| CONFIRMED | Nullifier set append-only | No removal operations |
| REFUTED | MerkleTree stores only root on-chain | Full tree stored; leaf preimages hidden but nodes stored |
| CONFIRMED | Coin commitments use hash, not Pedersen | Commitment(HashOutput) is SHA-256 based |

### privacy-patterns/ (16 verified)

| Verdict | Claim | Evidence |
|---------|-------|----------|
| CONFIRMED | persistentCommit<T>(value: T, rand: Bytes<32>): Bytes<32> | Exact match in midnight-natives.ss |
| CONFIRMED | persistentHash<T>(value: T): Bytes<32> | Exact match |
| CONFIRMED | transientCommit<T>(value: T, rand: Field): Field | Exact match |
| CONFIRMED | transientHash<T>(value: T): Field | Exact match |
| CONFIRMED | persistent* functions use SHA-256 | Documented and compiled to persistent_hash |
| CONFIRMED | transient* functions circuit-optimized, may change | Uses Poseidon; docs say "not guaranteed to persist" |
| CONFIRMED | persistentCommit clears witness taint | Both params: (discloses nothing) |
| CONFIRMED | Hash functions don't clear witness taint | Both hashes: (discloses "a hash of") |
| CONFIRMED | HistoricMerkleTree.checkRoot() checks all historic roots | Membership check in history map |
| CONFIRMED | MerkleTree.insert() hides leaf value | rt-leaf-hash applied before storage |
| CONFIRMED | MerkleTreePath<N,T> has leaf: T, path: Vector<N, MerkleTreePathEntry> | Exact definition in standard-library.compact |
| CONFIRMED | No historicMember method | Zero occurrences in entire compiler |
| CONFIRMED | HistoricMerkleTree holds at most 2^N leaves | isFull checks first_free >= 2^nat |
| CONFIRMED | Counter.read() returns Uint<64> | Confirmed in midnight-ledger.ss |
| CONFIRMED | generateRandomness/generateSecureRandom don't exist | Zero occurrences found |
| CONFIRMED | receiveShielded(ShieldedCoinInfo): [] | Exact match in standard-library.compact |

### protocols/ (4 verified)

| Verdict | Claim | Evidence |
|---------|-------|----------|
| CONFIRMED | mintUnshieldedToken(Bytes<32>, Uint<64>, Either<ContractAddress, UserAddress>): Bytes<32> | Exact match (param named 'amount' vs 'value') |
| REFUTED | sendShielded returns SendResult | Return type is ShieldedSendResult |
| REFUTED | type_value_commit = type\*G_t + value\*G_v + randomness\*G_r | 2 generators not 3; field name doesn't exist |
| REFUTED | Token Type = Hash(contract_address, domain_separator) | Argument order reversed |

### smart-contracts/ (12 verified)

| Verdict | Claim | Evidence |
|---------|-------|----------|
| CONFIRMED | Impact VM is stack-based | Spec and code both confirm stack machine |
| CONFIRMED | Impact VM non-Turing-complete, no backward jumps | Branch/Jmp use u32 (unsigned) skip |
| CONFIRMED | VM stack initialized with [Context, Effects, State] | to_vm_stack returns exactly 3 elements |
| REFUTED | Array(n) where 0 < n < 16 | Upper bound is inclusive: n <= 16 |
| REFUTED | Context is 5-element array | 8 elements, not 5 |
| REFUTED | Only first two context entries populated | All 8 entries populated in ledger-8 |
| CONFIRMED | Jump offsets always positive (forward-only) | u32 type structurally prevents negative |
| CONFIRMED | PC starts at 0, only increases; iteration unrolled | No loop opcode; confirmed |
| CONFIRMED | ckpt opcode marks guaranteed/fallible boundary | Encoded 0xff; well-formedness enforced |
| CONFIRMED | Every opcode has fixed gas cost | CostModel has per-opcode CostDuration |
| CONFIRMED | Contract calls execute sequentially within transaction | Confirmed by execution order |
| CONFIRMED | Effects from guaranteed phase persist even if fallible fails | Segment 0 state preserved |

## Unverified Claims (110)

The following claim categories were not individually source-verified in this fast-check:

- **Protocol schemas** (8 claims): JSON schema definitions for Compact AST, transactions, and ZK proofs. These describe schemas that may not correspond to actual protocol artifacts.
- **Tokenomics** (16 claims): NIGHT/DUST token economics, distribution phases, block reward formulas. These are business/economics claims not verifiable from code alone.
- **Additional Compact syntax** (~30 claims): Many overlap with verified stdlib claims. Syntax claims like "no let keyword", "for loop syntax", "enum dot notation" are well-established.
- **Protocol theory** (~20 claims): Kachina UC framework, Zswap theoretical properties. Academic protocol claims requiring paper review.
- **Remaining architecture/privacy claims** (~36 claims): Duplicates of verified claims or variations on confirmed patterns.

## Key Findings

### Critical Issues

1. **Transaction structure field names are fictional** (claims 001-003, 033-035): The architecture skill and transaction-deep-dive reference use invented field names (`guaranteed_zswap_offer`, `type_value_commit`, `received_commitments`) that don't exist in the Rust source. The actual `StandardTransaction` struct uses `guaranteed_coins`, `fallible_coins`, `intents`, and `binding_randomness`.

2. **Type names ImpactValue and SNARKVerifierKey don't exist** (claims 014-015): These appear throughout the architecture skill but no such types exist in `midnightntwrk/midnight-ledger`. The actual types are `ChargedState`, `ContractOperation`, and `VerifierKey`.

3. **Pedersen commitment formula is wrong** (claim 025): The formula `v*G + r*H` has the value/randomness roles transposed, and omits that H is type-dependent via `hash_to_curve`.

4. **Schnorr proof description is wrong** (claims 026-028): Not one per transaction (one per segment), doesn't prove "contract zero net value", and the struct fields are wrong.

5. **Proof verification phase is contradicted between files** (claims 017 vs 018): architecture/SKILL.md says ZK proofs verified in well-formedness; transaction-deep-dive.md says contract proofs verified in guaranteed phase. Source shows proofs are verified during well-formedness but via `op_check` which requires reference state (not purely stateless).

6. **Impact VM context array is wrong** (claims 143-144): Described as 5 entries with 2 uninitialized; actually 8 entries all populated.

### Pattern

The most common error pattern is **using spec pseudocode names as if they were implementation names**. The `spec/` directory in `midnight-ledger` uses simplified notation (`commitment_tree`, `MerkleTreeRoot`, `ImpactValue`) that doesn't match the actual Rust types. Many claims appear to be derived from spec pseudocode rather than the implementation.
