---
name: core-concepts:smart-contracts
description: Use when asking about Midnight smart contracts, Compact language basics, Impact VM, contract state separation, circuit entry points, deployment, or transaction execution model.
---

# Midnight Smart Contracts

Midnight smart contracts are replicated state machines that process transactions to modify public ledger state. Private state is maintained locally by each user and never published on-chain. Contracts are written in **Compact**, a domain-specific language designed for privacy-preserving computation, and compiled to **Impact VM** bytecode for on-chain execution and **ZK circuits** for off-chain proof generation.

## Transaction Anatomy

Every Midnight transaction contains:

1. **Public transcript** -- Visible state changes (ledger reads/writes, token operations)
2. **Zero-knowledge proof** -- Cryptographic proof that private computation was performed correctly
3. **Impact program** -- Bytecode that replays public state changes on-chain

The ZK proof validates that the private computation (witness data, internal logic) satisfies the contract's constraints without revealing the private inputs.

## Compact Language Structure

A Compact contract consists of four elements:

### 1. Ledger Declarations (Public State)

Each field is declared individually with `export ledger`:

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export ledger counter: Counter;
export ledger commitments: HistoricMerkleTree<32, Bytes<32>>;
export ledger nullifiers: Set<Bytes<32>>;
export ledger balances: Map<Bytes<32>, Uint<64>>;
```

Ledger state is public and on-chain. All reads and writes are visible to observers.

### 2. Exported Circuits (Entry Points)

Exported circuits are callable from transactions. They define the contract's public interface:

```compact
export circuit increment(): [] {
  counter.increment(1);
}

export circuit transfer(recipient: Bytes<32>, amount: Uint<64>): [] {
  assert(amount > 0, "Amount must be positive");
  // ... transfer logic
}
```

Return type `[]` (empty tuple) indicates no return value. Comparison operators (`>`, `<`, `>=`, `<=`) only work on `Uint<N>` types, not `Field`.

### 3. Witness Declarations (Private Inputs)

Witnesses are **declaration-only** in Compact -- they have no body. The implementation is in TypeScript, running off-chain:

```compact
witness local_secret_key(): Bytes<32>;
witness getProof(leaf: Bytes<32>): MerkleTreePath<32, Bytes<32>>;
witness getAmount(): Uint<64>;
```

Witness return values are private by default. When witness-tainted values flow to public context (ledger writes, assert conditions, circuit return values), the compiler requires `disclose()` to make the information flow explicit.

### 4. Internal Circuits (Helpers)

Non-exported helper functions use the `circuit` or `pure circuit` keyword:

```compact
circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:pk:"), sk
  ]);
}

pure circuit double(x: Field): Field {
  return x * 2;
}
```

There is no `function` keyword in Compact. Use `circuit` for helpers that may access ledger state, and `pure circuit` for purely computational helpers.

## Public vs Private State

| Aspect | Public (Ledger) | Private (Witness) |
|--------|----------------|-------------------|
| Storage | On-chain | Off-chain (user's machine) |
| Visibility | Fully visible | Hidden in ZK proof |
| Declaration | `export ledger name: Type;` | `witness name(params): Type;` |
| Persistence | Replicated across all nodes | Local to each participant |
| Mutation | Through ledger operations in circuits | Through TypeScript implementation |

**Key insight**: Compact separates what is visible (ledger operations compiled to Impact bytecode) from what is hidden (witness computations proven via ZK circuits). The `disclose()` annotation marks the boundary.

## Execution Model: Three Phases

Every transaction executes in three sequential phases:

### Phase 1: Well-Formedness (Stateless)

Checked by every node without accessing ledger state:

- Verify ZK proof against circuit verification key
- Verify Schnorr proof for the transaction's zero-value contribution
- Check structural validity (correct format, valid bytecodes)
- Validate token type consistency

This phase ensures the transaction is cryptographically valid before touching any state.

### Phase 2: Guaranteed (Stateful)

Executes the Impact program against current ledger state. Effects from this phase **always persist**, even if phase 3 fails:

- Look up contract state
- Run Impact bytecode (replay public state changes)
- Verify declared effects match actual execution results
- Collect transaction fees
- Process guaranteed token operations (Zswap offer)

### Phase 3: Fallible (Stateful)

Optional phase for operations that may fail due to concurrent state changes:

- Execute fallible Impact program
- Process fallible token operations
- **If this phase fails**: guaranteed effects still persist, but fallible effects are reverted. Fees are forfeited.

**Design pattern**: Put critical operations (fee payment, core state updates) in the guaranteed phase. Put operations that depend on external state (token swaps, balance checks against other contracts) in the fallible phase.

## Impact VM

The Impact VM executes the public portion of contract logic on-chain:

- **Stack-based** -- operates on a stack initialized with `[Context, Effects, State]`
- **Non-Turing-complete** -- no backward jumps; guaranteed termination
- **Deterministic** -- same inputs always produce the same outputs
- **Gas-bounded** -- every operation has a fixed cost; programs have cost limits

The Impact VM only sees public data. All private computation happens off-chain in the ZK proof. The VM replays the public state changes that the ZK proof has validated.

See `references/impact-vm.md` for opcodes, value types, and execution details.

## Compact Type System

| Type | Description | Size |
|------|-------------|------|
| `Boolean` | True/false | 1 bit |
| `Field` | Finite field element (~254 bits) | 1 field element |
| `Uint<N>` | Unsigned integer (N bits) | ceil(N/254) field elements |
| `Bytes<N>` | Fixed-size byte array | ceil(N/31) field elements |
| `Vector<N, T>` | Fixed-size array of T | N * size(T) |
| `[T, U, ...]` | Tuple | sum of element sizes |
| `[]` | Empty tuple (no return value) | 0 |

**Not a type**: `Void` does not exist in Compact -- use `[]`. `Address` is not a primitive -- use `Bytes<32>` for address-like values, or `ContractAddress` / `ZswapCoinPublicKey` from the standard library.

**Arrays**: Use `Vector<N, T>` for fixed-size arrays (e.g., `Vector<5, Field>`). The syntax `Field[5]` is invalid.

**Local bindings**: Only `const` exists for local variables. There is no `let` keyword. All local bindings are immutable; state mutation happens through ledger operations.

## Token Operations

Token operations are standard library circuit calls, not special syntax:

```compact
// Receive a coin (typically in guaranteed phase)
receive(coinInfo: CoinInfo): []

// Send a coin to a recipient
send(
  input: QualifiedCoinInfo,
  recipient: Either<ZswapCoinPublicKey, ContractAddress>,
  value: Uint<128>
): SendResult

// Mint an unshielded token
mintUnshieldedToken(
  domainSep: Bytes<32>,
  value: Uint<64>,
  recipient: Either<ContractAddress, UserAddress>
): Bytes<32>
```

These are imported via `import CompactStandardLibrary;` -- there is no selective import syntax.

## Contract Deployment

A deployment transaction contains the initial contract state and a nonce:

```
Deployment Transaction = Initial Contract State + Nonce
Contract Address = Hash(initial_state, nonce)
```

The contract address is deterministically derived from the deployment data. The nonce ensures unique addresses even for identical contract code.

## Practical Patterns

### Counter Pattern

The simplest contract uses the `Counter` ADT for thread-safe counting:

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export ledger count: Counter;

export circuit increment(): [] {
  count.increment(1);
}

// Counter.read() returns Uint<64>
export circuit getCount(): Uint<64> {
  return count.read();
}
```

`Counter` is preferred over raw `Field` for counting because `Counter.increment()` takes `Uint<16>` and `Counter.read()` returns `Uint<64>`, providing type-safe bounded operations.

See `examples/counter.compact` for a complete example.

### Private Authentication Pattern

Prove identity without revealing it using hash-based key derivation:

```compact
export ledger authority: Bytes<32>;

witness local_secret_key(): Bytes<32>;

circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:pk:"), sk
  ]);
}

export circuit authorize(): [] {
  const sk = local_secret_key();
  const pk = get_public_key(sk);
  // disclose() needed: pk is derived from witness data
  assert(disclose(pk == authority), "Not authorized");
}
```

### Commitment-Based Pattern

Hide values on-chain using commitments, prove membership using Merkle trees:

```compact
export ledger deposits: HistoricMerkleTree<32, Bytes<32>>;
export ledger spentNullifiers: Set<Bytes<32>>;

witness get_secret(): Bytes<32>;
witness get_randomness(): Bytes<32>;
witness get_merkle_path(commitment: Bytes<32>): MerkleTreePath<32, Bytes<32>>;

export circuit deposit(amount: Uint<64>): [] {
  const secret = get_secret();
  const rand = get_randomness();
  // Commit to the amount with randomness
  const commitment = persistentCommit<Uint<64>>(amount, rand);
  // MerkleTree.insert() hides the leaf value on-chain
  deposits.insert(disclose(commitment));
}

export circuit withdraw(): [] {
  const secret = get_secret();
  const rand = get_randomness();
  const amount = 100 as Uint<64>;
  const commitment = persistentCommit<Uint<64>>(amount, rand);

  // Prove commitment exists in the tree
  const path = get_merkle_path(commitment);
  const digest = merkleTreePathRoot<32, Bytes<32>>(path);
  // disclose() needed: digest is derived from witness data
  assert(deposits.checkRoot(disclose(digest)), "Deposit not found");

  // Prevent double-spend with nullifier
  const nullifier = persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:nul:"), secret
  ]);
  // disclose() needed: nullifier is derived from witness data
  assert(disclose(!spentNullifiers.member(nullifier)), "Already spent");
  spentNullifiers.insert(disclose(nullifier));
}
```

See `examples/private-vault.compact` for a complete private vault example.

## Important Syntax Notes

- Every `.compact` file needs: `pragma language_version >= 0.16 && <= 0.18;`
- Import: `import CompactStandardLibrary;` (not `import { fn } from "path"`)
- Assert: `assert(condition, "message")` -- parentheses required
- If: `if (condition) { }` -- parentheses required
- For: `for (const i of 0..10) { }` -- `const`, `of` keyword, parentheses required
- Comparisons: `<`, `>`, `<=`, `>=` only work on `Uint<N>`, not `Field`
- `persistentHash` uses SHA-256: `persistentHash<T>(value: T): Bytes<32>`
- Hash multiple values: `persistentHash<Vector<N, Bytes<32>>>([a, b, ...])`
- No `historicMember()` method -- use `merkleTreePathRoot()` + `checkRoot()` pattern
- Map: `.lookup(key)` to read, `.insert(key, value)` to write (no bracket access)
- Set: `.member(value)` to check membership (not `.contains()`)
- Cross-contract calls are not yet fully implemented

## References

| Topic | File |
|-------|------|
| Compact syntax, types, operators, control flow, stdlib usage | `references/compact-syntax.md` |
| Three-phase execution model, state transitions, concurrency | `references/execution-semantics.md` |
| Impact VM architecture, opcodes, value types, gas model | `references/impact-vm.md` |

## Examples

| Example | File | Demonstrates |
|---------|------|-------------|
| Counter with Counter ADT | `examples/counter.compact` | Basic ledger operations, Counter type |
| Private vault with deposits/withdrawals | `examples/private-vault.compact` | Commitments, Merkle proofs, nullifiers |
