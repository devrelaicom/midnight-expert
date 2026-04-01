# State Design

Design guidance for choosing ledger types, structuring on-chain state, initializing contracts, and composing ADTs in Compact.

## Choosing the Right Type

### Decision Matrix

| Use Case | Recommended Type | Alternative | Why Not the Alternative |
|----------|-----------------|-------------|----------------------|
| Track a count (supply, rounds, votes) | `Counter` | `ledger x: Uint<64>` | Counter has built-in atomic increment/decrement; direct Uint requires read-modify-write |
| Store per-user balances | `Map<Bytes<32>, Uint<64>>` | Multiple `ledger` fields | Dynamic keys; number of users unknown at compile time |
| Track who has voted / allowlist | `Set<Bytes<32>>` | `Map<Bytes<32>, Boolean>` | Set is semantically clearer and slightly more efficient |
| Private membership proof | `MerkleTree<N, Bytes<32>>` | `Set<Bytes<32>>` | Set reveals which element is checked; MerkleTree does not |
| Ordered event log | `List<T>` | `Map<Uint<64>, T>` with counter | List has native push/pop; simpler for queue patterns |
| Private membership + frequent inserts | `HistoricMerkleTree<N, T>` | `MerkleTree<N, T>` | Regular MerkleTree invalidates old proofs on insert |
| Immutable config (owner, threshold) | `sealed ledger x: T` | `ledger x: T` with access control | Compiler-enforced immutability; no runtime checks needed |
| On/off feature flag | `ledger flag: Boolean` | `Counter` + lessThan | Direct type; simpler and more readable |
| State machine phase | `ledger phase: Phase` (enum) | `ledger phase: Uint<8>` | Enum is type-safe; compiler catches invalid values |
| Private balance tracking | Token system (`ShieldedCoinInfo`) | `Map<Bytes<32>, Uint<64>>` | Map operations reveal balances on-chain |

### Counter vs Direct Uint

Use `Counter` when you need atomic increment/decrement across transactions. Use `ledger x: Uint<64>` when you need arbitrary assignment or computation:

```compact
// Counter: good for tallies and round tracking
export ledger totalVotes: Counter;
totalVotes.increment(1);

// Direct Uint: good for computed values
export ledger lastPrice: Uint<64>;
lastPrice = disclose(newPrice);
```

Counter increments are limited to `Uint<16>` per call (0..65535). If you need larger steps, call increment multiple times or use a direct Uint field.

### Map vs Set

Use `Map<K, V>` when you need to associate values with keys. Use `Set<T>` when you only need membership tracking:

```compact
// Map: stores role per user
export ledger roles: Map<Bytes<32>, Role>;
roles.insert(disclose(user), disclose(Role.admin));

// Set: just tracks membership
export ledger allowlist: Set<Bytes<32>>;
allowlist.insert(disclose(user));
```

### MerkleTree vs Set for Membership

Both track membership, but with different privacy properties:

| Property | `Set<T>` | `MerkleTree<N, T>` |
|----------|---------|-------------------|
| Insert privacy | Element visible | **Element hidden** — `insert()` applies `leaf_hash()` before storing; only the hash is in the transcript |
| Membership check | Element visible | **Element hidden** (proven via ZK) |
| Capacity | Unbounded | 2^N leaves |
| Proof complexity | O(1) | O(N) (tree depth) |
| Old proofs valid after insert | N/A | No (use `HistoricMerkleTree`) |

Use `Set` when membership is public information. Use `MerkleTree` when you need to prove membership without revealing which element.

## Constructor Patterns

### Basic Initialization

```compact
export sealed ledger owner: Bytes<32>;
export ledger phase: Phase;

witness local_secret_key(): Bytes<32>;

circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:pk:"), sk
  ]);
}

constructor() {
  owner = disclose(get_public_key(local_secret_key()));
  phase = Phase.registration;
}
```

### Constructor with Parameters

Constructors can accept arguments, allowing the deployer to configure the contract:

```compact
export sealed ledger threshold: Uint<64>;
export sealed ledger admin: Bytes<32>;

constructor(thresh: Uint<64>, adminPk: Bytes<32>) {
  threshold = disclose(thresh);
  admin = disclose(adminPk);
}
```

### Helper Circuits in Constructors

Sealed fields can be set by helper circuits called from the constructor. The compiler tracks reachability -- it is a static error if a sealed field is settable from any exported circuit:

```compact
export sealed ledger config: Bytes<32>;

// This is allowed: helper called only from constructor
circuit initConfig(): [] {
  config = disclose(pad(32, "default-config"));
}

constructor() {
  initConfig();
}

// This would be a compile error if it tried to set config:
// export circuit updateConfig(): [] {
//   config = pad(32, "new");  // Error: sealed field set from exported circuit
// }
```

### ADT Initialization in Constructors

ADT fields start at their default values (Counter at 0, Map/Set/List empty). Use methods to set initial values:

```compact
export ledger round: Counter;
export sealed ledger owner: Bytes<32>;
export ledger admins: Set<Bytes<32>>;

witness local_secret_key(): Bytes<32>;

constructor() {
  const pk = disclose(get_public_key(local_secret_key()));
  owner = pk;
  admins.insert(pk);
  // round starts at 0 (default) -- no initialization needed
}
```

### Common Constructor Pitfalls

| Mistake | Problem | Fix |
|---------|---------|-----|
| No `disclose()` on witness values | Compiler error: witness value flows to ledger | Wrap in `disclose()` |
| Setting sealed field in exported circuit | Static compile error | Move to constructor or constructor-only helper |
| Assigning directly to ADT field | Type error | Use ADT methods (`insert`, `increment`, etc.) |
| Multiple constructors | Only one allowed per contract | Combine into single constructor |
| Forgetting to initialize nested ADTs | `lookup` throws a runtime error (ExpectedCell) if the key does not exist | Use `insert(key, default<V>)` to initialize before calling `lookup` |

## Nested ADT Strategies

### When to Use Nested ADTs

Nested ADTs are useful when your state has a two-level key structure:

```compact
// Per-user token balances (user -> token -> amount)
export ledger balances: Map<Bytes<32>, Map<Bytes<32>, Uint<64>>>;

// Per-user permissions (user -> action -> allowed)
export ledger permissions: Map<Bytes<32>, Map<Bytes<32>, Boolean>>;

// Per-user vote counts (user -> counter)
export ledger voteCounts: Map<Bytes<32>, Counter>;
```

### Initialization and Access Pattern

Always initialize outer entries before accessing inner entries:

```compact
export ledger userTokens: Map<Bytes<32>, Map<Bytes<32>, Uint<64>>>;

export circuit setBalance(user: Bytes<32>, token: Bytes<32>, amount: Uint<64>): [] {
  const d_user = disclose(user);
  const d_token = disclose(token);
  const d_amount = disclose(amount);

  // Initialize outer map entry if missing
  if (!userTokens.member(d_user)) {
    userTokens.insert(d_user, default<Map<Bytes<32>, Uint<64>>>);
  }

  // Now safe to access and set inner value
  userTokens.lookup(d_user).insert(d_token, d_amount);
}
```

### Map of Counters

A common pattern for per-entity counting:

```compact
export ledger userScores: Map<Bytes<32>, Counter>;

export circuit incrementScore(user: Bytes<32>): [] {
  const d_user = disclose(user);

  if (!userScores.member(d_user)) {
    userScores.insert(d_user, default<Counter>);
  }

  userScores.lookup(d_user).increment(1);
}
```

## State Machine Patterns

Use enums to enforce valid state transitions with assertion guards:

```compact
export enum Phase { registration, active, completed }
export ledger phase: Phase;

constructor() {
  phase = Phase.registration;
}

export circuit register(participant: Bytes<32>): [] {
  assert(phase == Phase.registration, "Registration closed");
  // ... registration logic
}

export circuit activate(): [] {
  assert(phase == Phase.registration, "Already activated");
  phase = Phase.active;
}

export circuit complete(): [] {
  assert(phase == Phase.active, "Not active");
  phase = Phase.completed;
}
```

For more complex transitions, combine enum state with Counter for round tracking:

```compact
export enum GamePhase { commit, reveal, resolve }
export ledger gamePhase: GamePhase;
export ledger round: Counter;

export circuit advanceToReveal(): [] {
  assert(gamePhase == GamePhase.commit, "Not in commit phase");
  gamePhase = GamePhase.reveal;
}

export circuit resolveAndAdvance(): [] {
  assert(gamePhase == GamePhase.resolve, "Not in resolve phase");
  round.increment(1);
  gamePhase = GamePhase.commit;
}
```

For complete state machine pattern examples with authentication, see the `compact-structure` skill's `references/patterns.md`.

## Token System Summary

Midnight has a built-in token system powered by the zswap protocol. This provides privacy features beyond what ledger Maps can offer for balance tracking.

### When to Use the Token System vs Ledger Maps

| Approach | Privacy | Complexity |
|----------|---------|-----------|
| `Map<Bytes<32>, Uint<64>>` for balances | Balances visible on-chain | Simple, familiar |
| `ShieldedCoinInfo` + zswap | **Balances hidden** | Requires zswap integration |

Use ledger Maps when balance transparency is acceptable or desired. Use the token system when balance privacy is required.

### Key Token Types

The standard library provides these types for token operations:

| Type | Fields | Purpose |
|------|--------|---------|
| `ShieldedCoinInfo` | `nonce: Bytes<32>`, `color: Bytes<32>`, `value: Uint<128>` | Describes a new shielded coin |
| `QualifiedShieldedCoinInfo` | `nonce: Bytes<32>`, `color: Bytes<32>`, `value: Uint<128>`, `mt_index: Uint<64>` | Fully qualified shielded coin (with Merkle tree index) |
| `ContractAddress` | `bytes: Bytes<32>` | Contract address for token sends |

### Token Operations via Kernel

The `Kernel` ledger type provides minting operations:

```compact
ledger kernel: Kernel;

export circuit mintTokens(amount: Uint<64>): [] {
  kernel.mintShielded(pad(32, "mytoken:"), disclose(amount));
}
```

The standard library also provides circuits for shielded token operations:

| Circuit | Signature |
|---------|-----------|
| `sendShielded` | `(coin: QualifiedShieldedCoinInfo, recipient: Either<ZswapCoinPublicKey, ContractAddress>, value: Uint<128>): ShieldedSendResult` |
| `receiveShielded` | `(coin: ShieldedCoinInfo): []` |
| `sendImmediateShielded` | `(coin: ShieldedCoinInfo, recipient: Either<ZswapCoinPublicKey, ContractAddress>, value: Uint<128>): ShieldedSendResult` |
| `mergeCoin` | `(coin1: QualifiedShieldedCoinInfo, coin2: QualifiedShieldedCoinInfo): ShieldedCoinInfo` |
| `mergeCoinImmediate` | `(coin1: QualifiedShieldedCoinInfo, coin2: ShieldedCoinInfo): ShieldedCoinInfo` |
| `createZswapOutput` | `(coin: ShieldedCoinInfo, recipient: Either<ZswapCoinPublicKey, ContractAddress>): []` |
| `mintShieldedToken` | `(domainSep: Bytes<32>, value: Uint<64>, nonce: Bytes<32>, recipient: Either<ZswapCoinPublicKey, ContractAddress>): ShieldedCoinInfo` |
| `evolveNonce` | `(index: Uint<128>, nonce: Bytes<32>): Bytes<32>` |
| `shieldedBurnAddress` | `(): Either<ZswapCoinPublicKey, ContractAddress>` |

These integrate with the zswap protocol for private token transfers.

For the privacy implications of the token system vs ledger Maps, see `privacy-and-visibility.md`.
