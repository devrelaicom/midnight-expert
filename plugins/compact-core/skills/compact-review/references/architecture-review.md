# Architecture, State Design & Composability Review Checklist

Review checklist for the **Architecture, State Design & Composability** category. This covers ADT selection, MerkleTree depth planning, ledger visibility, contract decomposition, circuit vs witness boundary design, and state initialization. Apply every item below to the contract under review.

## Required MCP Tools

Run these tools before starting your review. Reference their output when evaluating checklist items.

| Tool | Label | Purpose |
|------|-------|---------|
| `midnight-compile-contract` | `[shared]` | Compilation output reveals structural issues |
| `midnight-extract-contract-structure` | `[shared]` | Identifies all data structure declarations, visibility modifiers, modules |
| `midnight-analyze-contract` | `[shared]` | Static analysis of contract architecture |
| `midnight-get-latest-syntax` | `[shared]` | Authoritative reference for ADT types, visibility modifiers, module syntax |

Tools marked `[shared]` are pre-run by the orchestrator — their output is in your prompt.

## ADT Selection Checklist

Check every ledger variable for correct abstract data type choice. Choosing the wrong ADT leads to privacy leaks, contention issues, or unnecessary complexity.

- [ ] **ADT Selection Decision Tree.** For each piece of ledger state, verify the chosen data type is appropriate for the use case. Refer to this decision table:

  | Need | Best ADT | Why Not Others |
  |------|----------|----------------|
  | Counting occurrences | `Counter` | Conflict-free increments; `Field` would need read-modify-write |
  | Key-value store (public keys) | `Map<K, V>` | Direct lookup; Set can't store values |
  | Unique membership (public) | `Set<T>` | Built-in member check; Map wastes value slot |
  | Anonymous membership (private) | `MerkleTree<N, T>` | Membership proofs hide which leaf; Set reveals members |
  | Anonymous + historic proofs | `HistoricMerkleTree<N, T>` | Root doesn't change on insert; regular MerkleTree invalidates existing proofs |
  | Ordered history | `List<T>` | Preserves insertion order; Set is unordered |
  | Single value | Direct `ledger var: T` | Simplest; no ADT overhead |

  > **Tool:** `midnight-extract-contract-structure` lists all ledger variable declarations with their types. Cross-reference each declaration against the ADT selection decision tree above.

- [ ] **Using `Field` as a counter instead of `Counter`.** If a ledger variable of type `Field` is incremented by reading its current value and writing back the incremented result, it should be a `Counter`. The `Counter` ADT provides conflict-free `increment()` and `decrement()` operations. A `Field` used as a counter causes read-modify-write contention under concurrent load.

  ```compact
  // BAD — Field used as a counter; read-modify-write contention
  export ledger vote_count: Field;

  export circuit vote(): [] {
    const current = vote_count;
    vote_count = current + 1;
  }

  // GOOD — Counter with conflict-free increment
  export ledger vote_count: Counter;

  export circuit vote(): [] {
    vote_count.increment(1);
  }
  ```

- [ ] **Using `Map<K, V>` where `Set<T>` suffices.** If a Map's values are never read (e.g., `Map<Bytes<32>, Boolean>` used only for membership checks), it wastes a value slot. Use `Set<T>` when only membership matters.

  ```compact
  // BAD — Map used only for membership; value is always true
  export ledger allowlist: Map<Bytes<32>, Boolean>;

  export circuit check(addr: Bytes<32>): [] {
    assert(allowlist.member(addr), "Not allowed");
  }

  // GOOD — Set is the right ADT for pure membership
  export ledger allowlist: Set<Bytes<32>>;

  export circuit check(addr: Bytes<32>): [] {
    assert(allowlist.member(addr), "Not allowed");
  }
  ```

- [ ] **Using `Set<T>` where `MerkleTree<N, T>` is needed for privacy.** If membership should be anonymous (the observer should not learn which member acted), `Set` is the wrong choice because Set operations reveal the exact element. Use `MerkleTree` (or `HistoricMerkleTree`) with a nullifier pattern instead.

  ```compact
  // BAD — Set reveals member identity
  export ledger members: Set<Bytes<32>>;

  export circuit act(pk: Bytes<32>): [] {
    assert(members.member(disclose(pk)), "Not a member");
  }

  // GOOD — MerkleTree hides member identity
  export ledger members: HistoricMerkleTree<16, Bytes<32>>;
  export ledger usedNullifiers: Set<Bytes<32>>;

  export circuit act(
    path: MerkleTreePath<16, Bytes<32>>,
    sk: Bytes<32>
  ): [] {
    const digest = merkleTreePathRoot<16, Bytes<32>>(path);
    assert(members.checkRoot(disclose(digest)), "Not a member");
    const nullifier = persistentHash<Vector<2, Bytes<32>>>(
      [pad(32, "app:act-nul:"), sk]
    );
    assert(!usedNullifiers.member(disclose(nullifier)), "Already acted");
    usedNullifiers.insert(disclose(nullifier));
  }
  ```

- [ ] **Using `MerkleTree` where `HistoricMerkleTree` is needed.** If a contract uses `MerkleTree` for membership proofs and members may join concurrently, existing proofs become invalid when a new leaf is inserted (root changes). `HistoricMerkleTree` retains previous roots so older paths remain valid. Use `HistoricMerkleTree` when membership proofs must persist across state changes.

  ```compact
  // BAD — concurrent inserts invalidate existing proofs
  export ledger members: MerkleTree<16, Bytes<32>>;

  // GOOD — old proofs remain valid after new inserts
  export ledger members: HistoricMerkleTree<16, Bytes<32>>;
  ```

- [ ] **Using `List<T>` when insertion order is not needed.** `List` preserves insertion order but is contention-prone under concurrent pushes. If ordering does not matter, `Set` or `Map` is a better choice. Use `List` only when ordered history is a genuine requirement.

## MerkleTree Depth Planning Checklist

Check every MerkleTree and HistoricMerkleTree declaration for appropriate depth sizing. Depth determines maximum capacity (2^depth leaves) and directly affects proof generation cost.

- [ ] **MerkleTree depth matches expected capacity.** Refer to this planning table:

  | Expected Entries | Minimum Depth | Recommended Depth | Notes |
  |-----------------|---------------|-------------------|-------|
  | < 100 | 7 | 10 | Small application |
  | < 10,000 | 14 | 16 | Medium application |
  | < 1,000,000 | 20 | 22 | Large application |
  | < 1B | 30 | 32 | Maximum practical size |

  Note: depth 1 is invalid. The minimum valid depth is 2.

  > **Tool:** `midnight-extract-contract-structure` shows all MerkleTree declarations with their depth parameters. Verify each depth against the planning table.

- [ ] **Depth is not excessively large for the expected number of entries.** A tree with depth 32 supports ~4 billion entries but requires 32 hash operations per proof. If the contract will never have more than a few thousand entries, depth 16 is sufficient. Over-sizing wastes proof generation time and circuit resources.

  ```compact
  // BAD — depth 32 for a contract expecting at most 1,000 members
  export ledger members: MerkleTree<32, Bytes<32>>;

  // GOOD — depth 16 gives 65,536 capacity with reasonable proof cost
  export ledger members: MerkleTree<16, Bytes<32>>;
  ```

- [ ] **Depth is not too small for expected growth.** Under-sizing a MerkleTree means it will run out of capacity. Consider future growth, not just current needs. Once deployed, the tree depth cannot be changed.

  ```compact
  // BAD — depth 4 supports only 16 entries; will fill up quickly
  export ledger members: MerkleTree<4, Bytes<32>>;

  // GOOD — depth 10 supports 1,024 entries with room to grow
  export ledger members: MerkleTree<10, Bytes<32>>;
  ```

- [ ] **Depth is at least 2.** Depth 1 is invalid in Compact. Any MerkleTree declaration with depth less than 2 will fail to compile.

## Visibility Checklist

Check every ledger variable for correct visibility modifiers. Visibility determines what external parties and DApps can observe and query.

- [ ] **Visibility reference.** Understand the available modifiers:
  - `export ledger` — readable by anyone, queryable by DApps
  - `sealed ledger` — set only in constructor, immutable after deployment
  - `ledger` (no modifier) — internal, not directly queryable but state changes are visible on-chain

  > **Tool:** `midnight-extract-contract-structure` shows the visibility modifier for each ledger variable. `midnight-list-examples` provides reference architectures showing idiomatic visibility patterns.

- [ ] **Missing `export` on ledger variables that the DApp needs to query.** If the DApp front-end needs to read a ledger variable (e.g., to display the current state, check balances, show voting results), the variable must be `export ledger`. Without `export`, the DApp cannot directly query the value.

  ```compact
  // BAD — DApp cannot query the current state
  ledger state: Field;

  // GOOD — DApp can read the state
  export ledger state: Field;
  ```

- [ ] **Unnecessary `export` on ledger variables that should be internal.** If a ledger variable is used only for internal contract logic and does not need to be queried by external parties, `export` unnecessarily exposes it. While the data is on-chain regardless, `export` makes it trivially accessible and signals it as part of the public API.

- [ ] **Missing `sealed` on configuration values set at deployment.** Values that are set once in the constructor and never modified (e.g., owner address, token name, protocol parameters) should be `sealed`. Without `sealed`, the variable appears mutable, and a bug could accidentally overwrite it. The `sealed` modifier enforces immutability after construction.

  ```compact
  // BAD — authority can be accidentally overwritten after deployment
  export ledger authority: Bytes<32>;

  // GOOD — sealed enforces immutability after constructor
  export sealed ledger authority: Bytes<32>;
  ```

  Real-world pattern from midnames:

  ```compact
  export sealed ledger default_context: Context;
  export sealed ledger default_pubkey: Bytes<32>;
  ```

- [ ] **Every ledger variable: should this be `export` or internal?** Review each ledger variable and ask: does the DApp need to query this value directly? If yes, it needs `export`. If no, keeping it internal reduces the public API surface and avoids misleading external callers into depending on internal state.

## Contract Decomposition Checklist

Check the contract for modularity and appropriate separation of concerns.

- [ ] **Is the contract trying to do too much?** A single contract file handling multiple unrelated concerns (e.g., token management, governance, and user profiles) is harder to audit, test, and maintain. Consider splitting into separate modules.

- [ ] **Module system used for separation of concerns.** Compact supports `module Name { ... }` for grouping related state and logic. If the contract has multiple logical subsystems, they should be organized into modules.

  ```compact
  module karol {
    export ledger round: Counter;
    export ledger fooBar: Map<Field, Field>;
  }

  import karol prefix $;

  constructor() {
      const p = $round;
      const z = $fooBar.lookup(1);
  }
  ```

  > **Tool:** `midnight-extract-contract-structure` identifies module structure and imports. `midnight-search-compact` can find reference examples of module decomposition patterns.

- [ ] **Shared types defined at the top level or in a shared module.** If multiple modules use the same types (enums, structs), those types should be defined at the top level or in a dedicated shared module, not duplicated across modules.

- [ ] **Re-export pattern for public interface.** If internal modules contain circuits that should be part of the contract's public API, import the module and re-export the desired functions.

  ```compact
  // Re-export pattern for public interface
  import InternalModule;
  export { func };
  ```

- [ ] **Module boundaries align with trust boundaries.** If different parts of the contract have different access control requirements (e.g., admin functions vs user functions), they should be in separate modules. This makes it easier to audit access control by module boundary.

## Circuit vs Witness Boundary Checklist

Check the division of logic between circuit (on-chain verification) and witness (off-chain computation) for correctness and efficiency.

- [ ] **Circuit contains only verification logic.** The circuit (on-chain code) should contain the minimum logic needed to verify correctness: state reads, assertions, state updates, and disclosure. Heavy computation should be performed in the witness (off-chain) and verified in the circuit.

  ```compact
  // BAD — complex computation inside circuit increases proof cost
  export circuit process(data: Vector<100, Field>): [] {
    // Every fold iteration unrolls into gates, multiplying proof cost
    const sum = fold(data, 0, (acc: Field, item: Field): Field {
      return acc + item;
    });
    result_field = disclose(sum as Field);
  }

  // GOOD — witness computes, circuit verifies
  export circuit process(expected_sum: Field): [] {
    // Witness computed the sum off-chain
    // Circuit only verifies and stores the result
    result = disclose(expected_sum);
  }
  ```

- [ ] **Witness handles off-chain computation and private data access.** Witnesses should perform complex algorithms, access external data sources, read local secret keys, and prepare data for the circuit. The circuit then verifies the results.

- [ ] **Rule of thumb: minimum logic in circuit, maximum in witness.** The circuit only verifies what the witness computed. Every operation in a circuit adds to proof generation time and cost. Move computation to the witness whenever possible, and have the circuit assert correctness of the result.

- [ ] **Constructor witness usage is valid but uncommon.** Constructors in Compact can access witness functions, but the typical pattern is to pass initialization values as constructor parameters. If a constructor calls a witness, verify that the witness is implemented correctly in the TypeScript provider and that the deployment workflow supports witness execution at deploy time.

  Real-world pattern from micro-dao (parameters preferred over witnesses for clarity):

  ```compact
  constructor(organizer_secret_key: Bytes<32>, costs_param: Costs) {
    organizer = persistentHash<Vector<2, Bytes<32>>>([pad(32, "dao:org:"), organizer_secret_key]);
    state = LedgerState.setup;
    costs = disclose(costs_param);
  }
  ```

- [ ] **Private data never passed directly to circuit parameters.** Circuits receive their private inputs through witness functions. If a circuit parameter appears to be a secret (e.g., a secret key), verify it arrives through a witness call within the circuit body, not as an `export circuit` parameter visible to the caller.

## State Initialization Checklist

Check the constructor and ledger variable declarations for correct and complete initialization.

- [ ] **All ledger variables must have deterministic initial values.** Ledger state must be deterministic at deployment. Every ledger variable should have a known initial value set in the constructor or provided by the ADT's default behavior.

- [ ] **Constructor must initialize all non-ADT ledger variables.** Simple types (`Field`, `Uint<N>`, `Bytes<N>`, `Boolean`, enums) do not auto-initialize. The constructor must explicitly set them or use `default<T>`.

  ```compact
  // BAD — non-ADT ledger variable not initialized in constructor
  export ledger owner: Bytes<32>;
  export ledger state: Field;

  constructor() {
    // owner and state are never set — undefined initial values
  }

  // GOOD — all non-ADT ledger variables initialized
  export ledger owner: Bytes<32>;
  export ledger state: Field;

  constructor(owner_key: Bytes<32>) {
    owner = owner_key;
    state = 0;
  }
  ```

- [ ] **ADTs auto-initialize to empty.** `Counter`, `Map`, `Set`, `MerkleTree`, `HistoricMerkleTree`, and `List` auto-initialize to their empty state. They do not need explicit initialization in the constructor. Adding unnecessary initialization code for ADTs is harmless but clutters the constructor.

  ```compact
  // These auto-initialize — no constructor code needed
  export ledger vote_count: Counter;
  export ledger balances: Map<Bytes<32>, Field>;
  export ledger members: Set<Bytes<32>>;
  export ledger tree: MerkleTree<16, Bytes<32>>;
  ```

- [ ] **`Field`, `Uint`, `Bytes`, `Boolean`: must be explicitly set or use `default<T>`.** For primitive types, either initialize them in the constructor with a specific value or use `default<T>` to get the zero/false default. Leaving them uninitialized is a bug.

- [ ] **Sealed ledger variables initialized in constructor.** Every `sealed ledger` variable must be set in the constructor. After construction, sealed variables cannot be modified. If a sealed variable is not set in the constructor, it remains at its default value permanently.

  ```compact
  export sealed ledger token_name: Bytes<32>;
  export sealed ledger max_supply: Field;

  constructor(name: Bytes<32>, supply: Field) {
    token_name = name;
    max_supply = supply;
  }
  ```

## Anti-Patterns Table

Quick reference of common architecture anti-patterns in Compact contracts.

| Anti-Pattern | Why It's Wrong | Correct Approach |
|---|---|---|
| `Field` used as a counter | Read-modify-write causes contention under concurrent load; also lacks semantic clarity | Use `Counter` with `increment()` and `decrement()` for conflict-free accumulation |
| `Map<K, Boolean>` for membership | Wastes a value slot; less idiomatic; `member()` check works the same on both but Map carries unnecessary data | Use `Set<T>` for pure membership checks where values are not needed |
| `Set<T>` for anonymous membership | Set operations reveal which element is being checked or inserted; no privacy for members | Use `MerkleTree` or `HistoricMerkleTree` with nullifier pattern for anonymous membership |
| `MerkleTree` when proofs must survive concurrent inserts | Regular MerkleTree invalidates existing proofs when root changes on insert | Use `HistoricMerkleTree` which retains previous roots so older paths remain valid |
| MerkleTree depth 32 for < 1,000 entries | 32 hash operations per proof when 10 would suffice; wastes proof generation time | Size depth to expected capacity: depth 10 for < 1,000, depth 16 for < 10,000 |
| Missing `sealed` on deployment-time constants | Value appears mutable; a bug could accidentally overwrite owner address or protocol parameters | Use `sealed ledger` for values set once in constructor and never modified |
| All logic in circuit, nothing in witness | Circuit operations are expensive (proof generation cost); complex computation in circuit bloats proof time | Move computation to witness; circuit only verifies the result with assertions |
| Complex witness calls in constructor | Constructors can access witnesses, but complex witness logic at deployment time complicates the deployment workflow and is harder to test | Prefer passing initialization values as constructor parameters for simplicity and testability |
| Non-ADT ledger variable not initialized in constructor | Variable has undefined initial value; behavior on first read is unpredictable | Explicitly initialize all `Field`, `Uint`, `Bytes`, `Boolean`, and enum ledger variables in the constructor |
| Single monolithic contract with unrelated concerns | Harder to audit, test, and maintain; access control review becomes complex | Split into modules using `module Name { ... }` with clear separation of concerns |

## Tool Reference

| Tool | Description |
|------|-------------|
| `midnight-compile-contract` | Compile contract with hosted compiler. Use `skipZk=true` for syntax validation. |
| `midnight-extract-contract-structure` | Deep structural analysis: data structure declarations, visibility modifiers, module organization. |
| `midnight-analyze-contract` | Static analysis of contract architecture and patterns. |
| `midnight-get-latest-syntax` | Authoritative Compact syntax reference including ADT types and module syntax. |
| `midnight-list-examples` | List available example contracts for reference architectures and idiomatic patterns. |
| `midnight-search-compact` | Semantic search across Compact code for architectural patterns. |
