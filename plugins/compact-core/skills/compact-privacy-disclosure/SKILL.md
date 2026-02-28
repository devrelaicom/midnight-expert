---
name: compact-privacy-disclosure
description: This skill should be used when the user asks about Midnight's privacy model, the disclose() function and disclosure rules, how to fix disclosure compiler errors, privacy-by-default design, witness protection program, commitment schemes (persistentCommit, transientCommit), nullifier patterns for double-spend prevention, MerkleTree membership proofs for anonymous authentication, unlinkable actions via round-based keys, selective disclosure, commit-reveal schemes, shielded vs transparent state design, what is visible on-chain, safe stdlib routines (transientCommit hiding witness data), or debugging "potential witness-value disclosure must be declared" errors.
---

# Compact Privacy & Disclosure

This skill covers the privacy dimension of Compact: understanding what is private by default, when and how to disclose, and how to build contracts that preserve user privacy. For visibility rules per ledger operation, see `compact-ledger`. For contract anatomy and circuit/witness design, see `compact-structure`. For standard library function signatures, see `compact-standard-library`. For shielded token privacy, see `compact-tokens`.

## Midnight's Privacy Model

Privacy is the default in Compact. All witness-derived data is private unless explicitly disclosed. The compiler's **Witness Protection Program** (an abstract interpreter) tracks which values contain witness data at every point in the program. When a tagged value reaches a public boundary (ledger write, conditional, exported circuit return, cross-contract call) without a `disclose()` wrapper, the compiler halts with an error reporting the full path from witness source to disclosure point.

`disclose()` is a compiler annotation, not a runtime operation. It does not encrypt, hash, or transform the value. Placing `disclose(x)` simply marks `x` as "okay to make public." The programmer is asserting: "I understand this value will be visible on-chain, and that is intentional."

## Privacy Decision Tree

| What to Protect | Approach | Key Primitives |
|----------------|----------|----------------|
| Hide a value on-chain | Commitment | `persistentCommit<T>` / `transientCommit<T>` |
| Prove membership anonymously | MerkleTree + ZK path | `HistoricMerkleTree` + `merkleTreePathRoot<N, T>` |
| Prevent double-actions | Nullifier | `persistentHash<T>([domain, secret])` + `Set<Bytes<32>>` |
| Hide who is acting | Unlinkable auth | `Counter` + rotated `persistentHash` |
| Multi-step hidden value | Commit-reveal | Commit phase + reveal phase |
| Private token balances | Shielded tokens | zswap infrastructure (see `compact-tokens`) |
| Share specific data only | Selective disclosure | `disclose()` on boolean result, not the value |

## Disclosure Rules Quick Reference

**When `disclose()` IS required:**

| Context | Example | Why |
|---------|---------|-----|
| Ledger write (direct) | `owner = disclose(pk)` | Value becomes public on-chain |
| Ledger write (ADT method) | `map.insert(disclose(key), val)` | Arguments to ADT ops are public |
| Conditional (`if`) | `if (disclose(x == y)) { ... }` | Branch choice reveals information |
| Conditional (`assert`) | `assert(disclose(x > 0), "msg")` | Assertion result is observable |
| Return from exported circuit | `return disclose(value)` | Return value leaves the ZK proof |
| Cross-contract call | Calling another contract's circuit | Arguments cross trust boundary |
| Constructor sealed field | `owner = disclose(pk)` | Sealed values are set publicly |

**When `disclose()` is NOT required:**

| Context | Example | Why |
|---------|---------|-----|
| Pure witness computation | `const h = persistentHash<Bytes<32>>(sk)` | Result stays within circuit |
| Internal circuit calls | `helper(witness_val)` | Non-exported, stays in proof |
| Intermediate variables | `const x = a + b` | No public boundary crossed |
| Commitment inputs | `persistentCommit<Field>(secret, rand)` | Commitment cryptographically hides input |

## Safe Stdlib Routines

| Function | Signature | Clears Witness Taint? | Why |
|----------|-----------|----------------------|-----|
| `persistentCommit<T>` | `(value: T, rand: Bytes<32>): Bytes<32>` | **Yes** | Commitment cryptographically hides input |
| `transientCommit<T>` | `(value: T, rand: Field): Field` | **Yes** | Same hiding property, circuit-efficient |
| `persistentHash<T>` | `(value: T): Bytes<32>` | **No** | Hash could theoretically be brute-forced |
| `transientHash<T>` | `(value: T): Field` | **No** | Same reasoning as persistentHash |

Even though commits clear taint on the *input*, the commitment *result* still needs `disclose()` when written to ledger:

```compact
const commitment = persistentCommit<Field>(secretValue, randomness);
storedCommitment = disclose(commitment);  // disclose() for ledger write, not for witness tracking
```

## Common Disclosure Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| `balance = getBalance()` | `balance = disclose(getBalance())` | Ledger write requires disclosure |
| `if (getFlag()) { ... }` | `if (disclose(getFlag())) { ... }` | Conditional requires disclosure |
| `return computeResult()` | `return disclose(computeResult())` | Exported circuit return requires disclosure |
| `disclose(getBalance()); ...; balance = x` | `balance = disclose(x)` | Disclose at disclosure point, not at source |
| `Set` for private membership | `MerkleTree` + ZK path proof | Set reveals which element is tested |
| Same domain for commitment and nullifier | Different domains | Same domain enables linking attack |
| `persistentHash(secret)` to "hide" witness | `persistentCommit(secret, rand)` | Hash doesn't clear witness taint; commit does |

## Reference Routing

| Topic | Reference File |
|-------|---------------|
| How `disclose()` works, Witness Protection Program, safe routines, placement best practices | `references/disclosure-mechanics.md` |
| Commitments, nullifiers, MerkleTree auth, unlinkability, threat model, anti-patterns | `references/privacy-patterns.md` |
| Fixing disclosure compiler errors step-by-step, common error patterns | `references/debugging-disclosure.md` |

## Examples

| Example | File | Pattern |
|---------|------|---------|
| Two-phase commit-reveal with salt-based commitments | `examples/CommitRevealScheme.compact` | Commit-Reveal |
| Single-use tokens with commitment + nullifier | `examples/NullifierDoubleSpend.compact` | Nullifiers |
| Anonymous voting with Merkle proofs and commit-reveal | `examples/PrivateVoting.compact` | Private Voting |
| Round-based key rotation for unlinkable actions | `examples/UnlinkableAuth.compact` | Unlinkable Auth |
| Proving properties without revealing values | `examples/SelectiveDisclosure.compact` | Selective Disclosure |
| Sealed-bid auction with time constraints | `examples/ShieldedAuction.compact` | Shielded Auction |
