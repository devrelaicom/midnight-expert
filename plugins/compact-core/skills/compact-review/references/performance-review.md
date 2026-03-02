# Performance & Circuit Efficiency Review Checklist

Review checklist for the **Performance & Circuit Efficiency** category. Every operation in a Compact circuit translates to constraints in the zero-knowledge proof. More constraints mean longer proof generation time and higher resource consumption for the prover. This review identifies unnecessary computational overhead, oversized data structures, and operations that could be moved off-chain. Apply every item below to the contract under review.

## Required MCP Tools

Run these tools before starting your review. Reference their output when evaluating checklist items.

| Tool | Label | Purpose |
|------|-------|---------|
| `midnight-compile-contract` | `[shared]` | Syntax validation and basic compilation checks |
| `midnight-extract-contract-structure` | `[shared]` | Identifies data structure declarations, loop patterns, type casts |
| `midnight-analyze-contract` | `[shared]` | Static analysis of circuit complexity patterns |
| `midnight-get-latest-syntax` | `[shared]` | Authoritative reference for pure circuit syntax and type cast rules |
| `midnight-compile-contract` (fullCompile) | `[category-specific]` | **Run this yourself** with `fullCompile=true` to get full ZK compilation including circuit size metrics. This reveals proof generation cost. |

Tools marked `[shared]` are pre-run by the orchestrator — their output is in your prompt.
Tools marked `[category-specific]` must be run by you during your review.

## Proof Generation Cost Checklist

Check every circuit for unnecessary arithmetic, redundant computations, and expressions that could be simplified. Every operation adds constraints to the ZK proof — fewer constraints mean faster proof generation.

- [ ] **Unnecessary arithmetic operations that could be simplified.** Look for arithmetic expressions that perform extra steps when a simpler equivalent exists. Each arithmetic operation (addition, multiplication, comparison) adds constraints. Algebraic simplification directly reduces proof generation cost.

  ```compact
  // BAD — unnecessary multiplication and addition; 4 operations
  export circuit compute(x: Field, y: Field): Field {
    const a = x * 2;
    const b = y * 2;
    const c = a + b;
    return disclose(c);
  }

  // GOOD — simplified to a single multiplication; 2 operations
  export circuit compute(x: Field, y: Field): Field {
    const result = (x + y) * 2;
    return disclose(result);
  }
  ```

- [ ] **Redundant computations that compute the same value multiple times.** If the same expression is evaluated more than once within a circuit, each evaluation generates its own set of constraints. Extract the result into a `const` and reuse it. This is especially important for expensive operations like hash computations.

  ```compact
  // BAD — same hash computed twice; double the constraints
  export circuit verify_and_store(sk: Bytes<32>): [] {
    const pk1 = persistentHash<Vector<2, Bytes<32>>>([pad(32, "app:pk:"), sk]);
    assert(authority == disclose(pk1), "Not authorized");
    const pk2 = persistentHash<Vector<2, Bytes<32>>>([pad(32, "app:pk:"), sk]);
    records.insert(disclose(pk2), disclose(1 as Field));
  }

  // GOOD — compute once, reuse the result
  export circuit verify_and_store(sk: Bytes<32>): [] {
    const pk = persistentHash<Vector<2, Bytes<32>>>([pad(32, "app:pk:"), sk]);
    assert(authority == disclose(pk), "Not authorized");
    records.insert(disclose(pk), disclose(1 as Field));
  }
  ```

- [ ] **Complex expressions that could be simplified algebraically.** Review mathematical expressions for algebraic identities that reduce operations. Common simplifications include factoring common subexpressions, reducing `x * 1` to `x`, replacing `x * 2` with `x + x` (if addition is cheaper in the constraint system), and simplifying boolean expressions.

  ```compact
  // BAD — redundant computation of (a * b) in both branches
  export circuit calculate(a: Field, b: Field, c: Field): Field {
    const term1 = a * b + c;
    const term2 = a * b - c;
    const result = term1 + term2;
    return disclose(result);
  }

  // GOOD — algebraically simplified: (ab + c) + (ab - c) = 2ab
  export circuit calculate(a: Field, b: Field, c: Field): Field {
    const result = (a * b) + (a * b);
    return disclose(result);
  }
  ```

- [ ] **Unnecessary intermediate type conversions in arithmetic chains.** Each type cast in an arithmetic chain adds constraints. If a value flows through multiple casts before being used, check whether the initial declaration could match the target type directly, eliminating the casts entirely.

  ```compact
  // BAD — declares as Uint, casts to Field for arithmetic, casts back
  const x: Uint<64> = 42;
  const y: Uint<64> = 10;
  const result = ((x as Field) + (y as Field)) as Uint<64>;

  // GOOD — declare as Field if Field arithmetic is the primary use
  const x: Field = 42;
  const y: Field = 10;
  const result = x + y;
  ```

## Ledger State Read Efficiency Checklist

Check every circuit for redundant or unnecessary ledger reads. Each ledger read translates to constraints in the proof and increases the transaction's state footprint.

- [ ] **Reading the same ledger variable multiple times in one circuit.** Each read of a ledger variable generates constraints. If the same ledger variable is read more than once within a single circuit, cache the value in a `const` and reuse it.

  ```compact
  // BAD — reads authority from ledger three times
  export circuit check_and_act(sk: Bytes<32>): [] {
    const pk = disclose(publicKey(sk));
    assert(authority == pk, "Not authorized");
    records.insert(pk, authority);
    log_action(authority);
  }

  // GOOD — read once, cache in const, reuse
  export circuit check_and_act(sk: Bytes<32>): [] {
    const pk = disclose(publicKey(sk));
    const auth = authority;
    assert(auth == pk, "Not authorized");
    records.insert(pk, auth);
    log_action(auth);
  }
  ```

- [ ] **`Map.member()` + `Map.lookup()` with the same key — necessary but note the double read.** The `member()` + `lookup()` pattern is required for safety (see Security checklist), because calling `lookup()` on a non-existent key causes a runtime failure. However, this does mean two ledger reads for the same key. This is an accepted cost for correctness, but flag it if the `member()` check is truly unnecessary (e.g., the key is guaranteed to exist from prior logic).

  ```compact
  // NECESSARY — member() check required before lookup()
  export circuit get_balance(account: Bytes<32>): Field {
    assert(balances.member(account), "Account not found");
    return disclose(balances.lookup(account));
  }

  // UNNECESSARY DOUBLE READ — key is guaranteed to exist from insert above
  export circuit initialize_and_read(account: Bytes<32>): Field {
    balances.insert(account, disclose(100 as Field));
    // account was just inserted; member() check is redundant here
    assert(balances.member(account), "Account not found");
    return disclose(balances.lookup(account));
  }
  ```

- [ ] **Unnecessary ledger reads when the value is not needed.** A circuit that reads a ledger variable but never uses the result in any computation or assertion wastes constraints. Remove any ledger read whose result is not consumed.

  ```compact
  // BAD — reads counter value but never uses it
  export circuit increment_only(): [] {
    const unused = counter.read();
    counter.increment(1);
  }

  // GOOD — only performs the needed operation
  export circuit increment_only(): [] {
    counter.increment(1);
  }
  ```

## MerkleTree Depth Sizing Checklist

Check every `MerkleTree` and `HistoricMerkleTree` declaration for appropriate depth. Merkle trees, exposed in Compact as the `MerkleTree<n, T>` and `HistoricMerkleTree<n, T>` types, are a very useful tool for shielding the values contained in a set. Their key feature is making it possible to assert publicly that some value is contained within the `MerkleTree`, without revealing which value this is. The depth parameter `n` determines the tree's capacity and directly impacts proof generation cost.

- [ ] **Depth determines capacity: `2^depth` leaves.** Verify the depth is appropriate for the expected number of entries. Common depth values and their capacities:

  | Depth | Capacity | Typical Use Case |
  |-------|----------|-----------------|
  | 8 | 256 | Small membership set, testing |
  | 10 | 1,024 | Small to medium membership |
  | 16 | 65,536 | Medium membership set |
  | 20 | ~1M | Large membership set |
  | 24 | ~16M | Very large membership set |
  | 32 | ~4B | Global-scale set |

- [ ] **Oversized depth wastes proof generation time.** Deeper Merkle trees generate more constraints per path verification because each level of the tree adds hash computations to the proof. A depth-32 tree generates roughly 4x the path verification constraints of a depth-8 tree. If the contract will never need more than a few thousand entries, a depth-32 tree wastes significant proof generation resources.

  ```compact
  // BAD — depth 32 for a voting contract with at most 1000 voters
  // Proof verifies 32 hash levels when 10 would suffice
  export ledger voters: HistoricMerkleTree<32, Bytes<32>>;

  // GOOD — depth 10 covers 1024 entries; sufficient with margin
  export ledger voters: HistoricMerkleTree<10, Bytes<32>>;
  ```

  > **Tool:** `midnight-extract-contract-structure` lists all MerkleTree declarations with their depth parameters. Cross-reference each depth against the expected capacity table above.

- [ ] **Undersized depth limits future capacity.** While oversizing wastes resources, undersizing risks running out of capacity. Once a MerkleTree is full, no new leaves can be inserted without deploying a new contract. This is not recoverable.

  ```compact
  // BAD — depth 4 only holds 16 entries; will fill up fast
  export ledger members: MerkleTree<4, Bytes<32>>;

  // GOOD — anticipate growth; use minimum depth with headroom
  export ledger members: MerkleTree<16, Bytes<32>>;
  ```

- [ ] **Rule of thumb: use minimum depth that covers expected maximum entries with 10x margin.** If you expect 500 entries, 10x margin means planning for 5,000. `2^13 = 8192` covers this, so depth 13 is appropriate. Do not default to depth 32 "just in case" — the proof cost is real.

  ```compact
  // Expected: ~200 members
  // 200 * 10 = 2000 → 2^11 = 2048 → depth 11

  // BAD — default depth 32 for a 200-member DAO
  export ledger members: HistoricMerkleTree<32, Bytes<32>>;

  // GOOD — depth 11 covers 2048 entries (10x margin over 200)
  export ledger members: HistoricMerkleTree<11, Bytes<32>>;
  ```

- [ ] **`MerkleTree<1, T>` — minimum depth is 2 (depth 1 is a compile-time error).** A MerkleTree with depth 1 is invalid in Compact and will fail to compile. The minimum valid depth is 2 (4 leaves). If you see depth 1, flag it as a compilation error.

  ```compact
  // BAD — depth 1 is invalid; causes a compile-time error
  export ledger items: MerkleTree<1, Bytes<32>>;

  // GOOD — minimum valid depth is 2
  export ledger items: MerkleTree<2, Bytes<32>>;
  ```

## Loop and Iteration Impact Checklist

Check every `for` loop and `Vector<N, T>` iteration for circuit size impact. Compact loops are unrolled at compile time, so the loop body's constraints are multiplied by the iteration count.

- [ ] **`for` loops in Compact are unrolled at compile time.** A `for` loop over 1000 elements generates 1000 copies of the loop body's constraints. This is not a runtime iteration — it is compile-time duplication. A loop body with 10 constraints iterated 1000 times produces 10,000 constraints. Review whether the iteration count is truly necessary.

  ```compact
  // BAD — 1000 iterations, each with hash computation
  // Generates thousands of constraints from the unrolled loop
  for (const i = 0; i < 1000; i++) {
    const h = persistentHash<Bytes<32>>(data[i]);
    assert(h != pad(32, ""), "Invalid data");
  }

  // BETTER — if only a subset needs validation, reduce the iteration count
  // Or move the validation to witness code and verify the result in circuit
  ```

  > **Tool:** `midnight-compile-contract` with `fullCompile=true` reveals the actual constraint count. Compare against the expected count based on loop iterations and body complexity.

- [ ] **Large `Vector<N, T>` iterations: N directly multiplies circuit size.** When iterating over a `Vector<N, T>`, the loop body is duplicated N times. A `Vector<256, Field>` iteration with a body containing 5 constraints generates 1280 constraints. Consider whether the full vector needs to be processed in-circuit or whether a partial approach is possible.

  ```compact
  // BAD — iterates over 256-element vector in circuit
  // Every element processed adds to proof generation time
  circuit sumVector(v: Vector<256, Field>): Field {
    const total: Field = 0;
    for (const i = 0; i < 256; i++) {
      total = total + v[i];
    }
    return total;
  }

  // BETTER — if the sum can be computed off-chain, do it in witness
  // and verify the result in circuit (see Circuit vs Witness Boundary)
  witness computeSum(v: Vector<256, Field>): Field;

  circuit verifySumCorrect(v: Vector<256, Field>, claimed_sum: Field): Boolean {
    // Verify a property of the sum rather than recomputing it
    // (if verification is cheaper than computation)
    return true;
  }
  ```

- [ ] **Consider whether the operation can be done off-chain in witness code instead.** Any computation whose result can be efficiently verified is a candidate for moving to the witness. The circuit only needs to assert that the witness-provided result is correct. This trades circuit constraints for witness computation, which does not affect proof size.

  ```compact
  // BAD — searching for a value in a vector inside the circuit
  // Unrolls to N comparisons regardless of where the value is found
  circuit findIndex(v: Vector<64, Field>, target: Field): Uint<8> {
    const index: Uint<8> = 0;
    for (const i = 0; i < 64; i++) {
      index = (v[i] == target) ? i as Uint<8> : index;
    }
    return index;
  }

  // GOOD — witness provides the index, circuit just verifies
  witness findIndexOffchain(v: Vector<64, Field>, target: Field): Uint<8>;

  circuit verifyIndex(v: Vector<64, Field>, target: Field, index: Uint<8>): [] {
    assert(v[index] == target, "Witness provided incorrect index");
  }
  ```

## Type Conversion Overhead Checklist

Check for unnecessary or multi-step type casts that add proof constraints without serving a purpose.

- [ ] **Conversion casts add proof constraints; static casts are free.** Type casts that involve actual value conversion (e.g., `Uint<64> → Field`, `Field → Bytes<32>`) generate constraints to prove the conversion is valid. However, static casts that merely reinterpret bits without conversion are free. If a value is declared as one type and then immediately cast via a conversion cast, consider declaring it as the target type from the start.

  ```compact
  // BAD — declares as Uint<64>, immediately casts to Field
  const x: Uint<64> = 42;
  const y = x as Field;
  // The cast adds constraints to prove the conversion is valid

  // GOOD — declare as the type you actually need
  const x: Field = 42;
  ```

- [ ] **Multi-step casts: each step adds constraints.** Patterns like `Uint<64> → Field → Bytes<32>` involve two separate cast operations, each generating its own constraints. While sometimes necessary (Compact requires the intermediate `Field` step for `Uint` to `Bytes` conversion), review whether the initial type choice could avoid the chain entirely.

  ```compact
  // BAD — triple cast chain; each step adds constraints
  const value: Uint<64> = 42;
  const asField = value as Field;
  const asBytes = asField as Bytes<32>;
  const result = persistentHash<Vector<2, Bytes<32>>>([pad(32, "app:"), asBytes]);

  // GOOD — declare as Bytes<32> from the start if that is the final use
  // Or accept the value as Bytes<32> from the witness
  witness get_value_bytes(): Bytes<32>;

  circuit computeHash(): Bytes<32> {
    const value = get_value_bytes();
    return persistentHash<Vector<2, Bytes<32>>>([pad(32, "app:"), value]);
  }
  ```

- [ ] **Repeated casts of the same value.** If a value is cast to the same target type multiple times in a circuit, each cast generates separate constraints. Cache the cast result in a `const` and reuse it.

  ```compact
  // BAD — casts the same value to Field twice
  const amount: Uint<64> = 100;
  const hash_input = amount as Field as Bytes<32>;
  const comparison = amount as Field;

  // GOOD — cast once, reuse the result
  const amount: Uint<64> = 100;
  const amount_as_field = amount as Field;
  const hash_input = amount_as_field as Bytes<32>;
  const comparison = amount_as_field;
  ```

## Circuit vs Witness Boundary Checklist

Check whether expensive computations are correctly placed at the circuit/witness boundary. Expensive computations that do not need to be proved should be in witness TypeScript code, not in the circuit. The circuit should only verify the result.

- [ ] **Expensive computation in circuit that could be in witness.** If a computation is expensive (many constraints) but its result can be verified cheaply, move the computation to the witness and verify the result in the circuit. The proof only needs to demonstrate that the result is correct, not how it was computed.

  ```compact
  // BAD — sorting inside the circuit is extremely expensive
  // A sort of N elements generates O(N^2) comparison constraints
  circuit sortAndProcess(v: Vector<16, Field>): [] {
    // Bubble sort in circuit — 16 * 15 / 2 = 120 comparison constraints
    for (const i = 0; i < 16; i++) {
      for (const j = 0; j < 15; j++) {
        // swap logic generates many constraints per iteration
      }
    }
    // ... process sorted result
  }

  // GOOD — sort in witness, verify sorted order in circuit
  witness sortOffchain(v: Vector<16, Field>): Vector<16, Field>;

  circuit processIfSorted(sorted: Vector<16, Field>): [] {
    // Verify sorted order: O(N) comparisons instead of O(N^2)
    for (const i of 0..14) {
      assert(sorted[i] as Uint<64> <= sorted[i + 1] as Uint<64>,
        "Not sorted");
    }
    // ... process verified sorted result
  }
  ```

  > **Tool:** `midnight-explain-circuit` can explain what a circuit does in plain language, helping identify computations that could be moved to the witness. `midnight-search-docs` has guidance on the circuit vs witness boundary optimization.

- [ ] **Only the verification (assert the result is correct) needs to be in the circuit.** The circuit's job is to constrain the witness output so that only correct results are accepted. The actual computation can happen anywhere — the witness, a server, the user's browser — as long as the circuit can verify the result. This is the fundamental optimization principle for ZK circuits.

  ```compact
  // BAD — computing square root in circuit (expensive iterative computation)
  circuit squareRoot(n: Field): Field {
    // Iterative approximation in circuit — many constraints
    const guess: Field = n;
    for (const i = 0; i < 20; i++) {
      guess = (guess + n / guess) / 2;
    }
    return guess;
  }

  // GOOD — witness computes the root, circuit verifies root * root == n
  witness computeSquareRoot(n: Field): Field;

  circuit verifiedSquareRoot(n: Field): Field {
    const root = computeSquareRoot(n);
    assert(root * root == n, "Invalid square root");
    return root;
  }
  ```

- [ ] **Lookup tables or search operations inside circuit.** Searching through a data structure (finding a value in a list, looking up a key in an array) inside a circuit requires iterating over all elements. Move the search to the witness and have the circuit verify the result at the found index.

  ```compact
  // BAD — linear search in circuit; iterates over all 32 elements
  circuit findOwner(
    entries: Vector<32, Bytes<32>>,
    target: Bytes<32>
  ): Boolean {
    const found: Boolean = false;
    for (const i = 0; i < 32; i++) {
      found = found || (entries[i] == target);
    }
    return found;
  }

  // GOOD — witness provides the index, circuit verifies
  witness findOwnerIndex(
    entries: Vector<32, Bytes<32>>,
    target: Bytes<32>
  ): Uint<8>;

  circuit verifyOwner(
    entries: Vector<32, Bytes<32>>,
    target: Bytes<32>
  ): Boolean {
    const idx = findOwnerIndex(entries, target);
    return entries[idx] == target;
  }
  ```

## `pureCircuit` Optimization Checklist

Check for opportunities to use `pure circuit` for reusable logic that does not access ledger state.

- [ ] **Reusable logic that does not touch ledger state should be `pure circuit`.** A `pure circuit` cannot read or write ledger state. This restriction enforces purity at compile time and enables the circuit to be exported as a `pureCircuits` function callable from TypeScript witness code. If a helper circuit does not access any ledger variables, mark it as `pure circuit`.

  ```compact
  // BAD — regular circuit that does not use ledger state
  circuit computeCommitment(sk: Bytes<32>, value: Field): Bytes<32> {
    return persistentHash<Vector<3, Bytes<32>>>(
      [pad(32, "app:commit:"), sk, value as Field as Bytes<32>]
    );
  }

  // GOOD — pure circuit; enables compiler optimizations and witness reuse
  pure circuit computeCommitment(sk: Bytes<32>, value: Field): Bytes<32> {
    return persistentHash<Vector<3, Bytes<32>>>(
      [pad(32, "app:commit:"), sk, value as Field as Bytes<32>]
    );
  }
  ```

  > **Tool:** `midnight-extract-contract-structure` identifies all circuits and whether they access ledger state. Flag any non-pure circuit that does not read or write ledger variables. `midnight-explain-circuit` can analyze specific circuits to confirm whether they access ledger state.

- [ ] **Pure circuits can be called from TypeScript witness code.** Because `pure circuit` functions have no side effects (no ledger access), they are exported as `pureCircuits` and can be called from witness TypeScript code as well as from other circuits. This enables sharing logic between the on-chain proof and the off-chain witness computation without duplication. Note: the `pure` keyword primarily validates purity and enables TypeScript export — it does not trigger additional compiler optimizations beyond what the compiler already applies to all circuits.

  ```compact
  // GOOD — pure circuit shared between circuit and witness contexts
  pure circuit derivePublicKey(sk: Bytes<32>): Bytes<32> {
    return persistentHash<Vector<2, Bytes<32>>>(
      [pad(32, "app:pk:"), sk]
    );
  }

  // Used in an export circuit for on-chain verification
  export circuit register(): [] {
    const sk = local_secret_key();
    const pk = derivePublicKey(sk);
    authority = disclose(pk);
  }

  // The same derivePublicKey can be called from witness TypeScript code
  // to derive keys off-chain without duplicating the logic
  ```

- [ ] **Non-pure circuit used where a pure circuit would suffice.** If a circuit is declared without the `pure` modifier but does not access ledger state, it should be converted to `pure circuit`. A non-pure circuit cannot be called from witness TypeScript code, missing an opportunity for logic reuse.

  ```compact
  // BAD — circuit does not touch ledger but is not marked pure
  circuit hashPair(a: Bytes<32>, b: Bytes<32>): Bytes<32> {
    return persistentHash<Vector<2, Bytes<32>>>([a, b]);
  }

  // GOOD — marked as pure circuit; same logic, better optimizations
  pure circuit hashPair(a: Bytes<32>, b: Bytes<32>): Bytes<32> {
    return persistentHash<Vector<2, Bytes<32>>>([a, b]);
  }
  ```

## Anti-Patterns Table

Quick reference of common performance anti-patterns in Compact contracts.

| Anti-Pattern | Why It's Costly | Correct Approach |
|---|---|---|
| Same hash computed twice in one circuit | Each hash computation generates its own full set of constraints; duplicating a hash doubles the constraint count | Compute once, store in `const`, reuse the result |
| `MerkleTree<32, T>` for a 200-member set | Depth-32 path verification generates 32 levels of hash constraints; a depth-11 tree covers 2048 entries and generates 1/3 the constraints | Use minimum depth with 10x margin: `MerkleTree<11, T>` for ~200 expected entries |
| `for` loop over 1000 elements in circuit | Loop is unrolled at compile time; 1000 iterations of a 10-constraint body produces 10,000 constraints | Move computation to witness; verify the result in circuit with a single assertion |
| Sorting inside a circuit | O(N^2) comparisons all become constraints; sorting 16 elements generates ~120 comparison constraints | Sort in witness TypeScript code; verify sorted order in circuit with O(N) comparisons |
| `Uint<64>` → `Field` → `Bytes<32>` chain when only `Bytes<32>` is needed | Each cast step adds constraints to prove the conversion is valid; multi-step chains multiply the cost | Declare or accept the value as the target type from the start |
| Reading same ledger variable 3+ times | Each read generates constraints; 3 reads of the same variable triples the read cost | Read once into a `const`, reuse throughout the circuit |
| Helper circuit without `pure` modifier that does not access ledger | Cannot be called from witness TypeScript code; misses the purity enforcement and `pureCircuits` export | Add `pure` modifier: `pure circuit helperName(...)` |
| Linear search inside circuit over `Vector<N, T>` | Iterates all N elements regardless of position; N comparisons become N constraint groups | Witness provides the index; circuit verifies `v[index] == target` in a single comparison |
| `MerkleTree<1, T>` declaration | Depth 1 is invalid and causes a compile-time error | Minimum valid depth is 2: `MerkleTree<2, T>` |
| Unnecessary `counter.read()` when only `increment()` is needed | Read generates constraints for a value that is never used in computation | Remove the read; call `counter.increment(n)` directly |

## Tool Reference

| Tool | Description |
|------|-------------|
| `midnight-compile-contract` | Compile contract with hosted compiler. Use `skipZk=true` for syntax validation, `fullCompile=true` for circuit size metrics and proof generation cost analysis. |
| `midnight-extract-contract-structure` | Deep structural analysis: data structure declarations, loop patterns, type cast chains, pure circuit candidates. |
| `midnight-analyze-contract` | Static analysis of contract structure and common patterns. |
| `midnight-get-latest-syntax` | Authoritative Compact syntax reference including `pure circuit` rules and type cast paths. |
| `midnight-explain-circuit` | Explains what a circuit does in plain language, including ZK proof cost implications. |
| `midnight-search-docs` | Full-text search across official Midnight documentation for performance guidance. |
