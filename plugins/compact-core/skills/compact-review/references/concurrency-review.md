# Concurrency & Contention Review Checklist

Review checklist for the **Concurrency & Contention** category. Midnight processes transactions concurrently, and two transactions that read-then-write the same ledger state will conflict — only the first to land succeeds, and the rest fail. This review identifies contention-prone patterns and recommends conflict-free alternatives. Apply every item below to the contract under review.

## Read-Then-Write Contention Checklist

Check every exported circuit for patterns where state is read and then written back with a value derived from the read. These are the primary source of transaction contention.

- [ ] **Counter read-then-set pattern.** Reading a `Counter` value and then manually setting it to `value + n` is the textbook contention pattern. If two transactions execute concurrently, both read the same value (e.g., `1`), and both attempt to write `2`. Only the first transaction succeeds; the second fails because the value it read is no longer current. Use `Counter.increment(n)` instead, which is a commutative operation that does not conflict.

  > Consider a simple counter contract, where users increment a publicly stored counter. A naive implementation may a) read the current value, and b) set the new value to the read value + 1. This can be a problem if the steps are recorded separately in the transaction, say as `[read 1, write 2]`. If two of these transactions get submitted simultaneously, they will conflict, and only the first will succeed. For the others, the value read is no longer `1`, so the transaction will fail. If instead the transaction is structured to contain a single-step increment — for instance `[incr 1]` — then all transactions can succeed.

  ```compact
  // BAD — read-then-write causes contention
  export circuit increment_counter(): [] {
    const val = counter.read();
    // Two concurrent transactions both read the same val
    // Both try to write val + 1; only one can succeed
    counter = val + 1;
  }

  // GOOD — atomic increment, conflict-free
  export circuit increment_counter(): [] {
    counter.increment(1);
  }
  ```

- [ ] **Map read-modify-write pattern.** Reading a value from a `Map`, computing a new value from it, and writing it back to the same key creates contention when two transactions target the same key. Both transactions read the same value, compute derived values, and race to write — only one succeeds.

  ```compact
  // BAD — read-modify-write on same Map key; contention when concurrent
  export circuit add_score(player: Bytes<32>, points: Field): [] {
    assert(scores.member(player), "Player not found");
    const current = scores.lookup(player);
    scores.insert(player, current + points);
  }

  // GOOD — if the value is a counter-like accumulator, use a per-key Counter
  // or restructure so concurrent users modify different keys
  export circuit add_score(points: Field): [] {
    const sk = local_secret_key();
    const player = disclose(publicKey(sk));
    // Each player modifies only their own key — no cross-user contention
    const current = scores.member(player) ? scores.lookup(player) : 0;
    scores.insert(player, current + points);
  }
  ```

- [ ] **General read-then-write on any exported circuit.** Any `export circuit` that reads a ledger variable and then writes a value derived from the read to the same variable is contention-prone. The pattern is: (1) read state, (2) compute new value from the read, (3) write new value back. If two transactions do this concurrently, they conflict.

  ```compact
  // BAD — reads global_total, derives new value, writes it back
  export circuit contribute(amount: Field): [] {
    const current_total = global_total.read();
    global_total = current_total + amount;
  }

  // GOOD — use Counter for commutative accumulation
  // export ledger global_total: Counter;
  export circuit contribute(amount: Field): [] {
    global_total.increment(amount);
  }
  ```

## ADT Contention Properties Checklist

Check each ledger data structure usage for its inherent contention characteristics. Different ADTs have different conflict profiles.

- [ ] **`Counter.increment(n)` — conflict-free.** `Counter.increment(n)` and `Counter.decrement(n)` are commutative operations. Multiple concurrent transactions can all increment or decrement the same counter without conflicting because the operations can be applied in any order and produce the same result. This is the preferred pattern for any accumulator.

  ```compact
  // Counter operations and their contention properties:
  counter.increment(1);      // Conflict-free (commutative)
  counter.decrement(1);      // Conflict-free (commutative)
  counter.lessThan(1);       // Read-only comparison, no write contention
  counter.read();            // Read-only, no write contention by itself
  counter.resetToDefault();  // CAUSES CONTENTION — overwrites the value
  ```

- [ ] **`Counter.read()` followed by manual set — CAUSES CONTENTION.** When `counter.read()` is used to obtain the current value and then that value is used to compute a new state that is written back, the read creates a dependency on the current value. Concurrent transactions that both read the same value will conflict. Prefer `increment()` or `decrement()` which do not depend on the current value.

  ```compact
  // BAD — read creates dependency; concurrent transactions conflict
  export circuit double_counter(): [] {
    const val = counter.read();
    counter = val * 2;
    // Two transactions both read the same val and try to write val * 2
  }

  // If you need the current value for logic OTHER than writing back,
  // reading is fine — the contention arises only when the read
  // determines the write value.
  ```

- [ ] **`Map.insert(key, value)` — conflicts only when the same key is modified concurrently.** Map insertions conflict when two transactions insert to the same key simultaneously, because both are writing to the same storage slot. Insertions to different keys do not conflict. Design contracts so concurrent users modify different keys (e.g., per-user entries keyed by public key).

  ```compact
  // LOW CONTENTION — each user writes to their own key
  export circuit update_profile(name: Field): [] {
    const sk = local_secret_key();
    const pk = disclose(publicKey(sk));
    profiles.insert(pk, name);
  }

  // HIGH CONTENTION — all users write to the same key
  export circuit update_global_config(value: Field): [] {
    config.insert(pad(32, "global"), value);
  }
  ```

- [ ] **`Set.insert(value)` — conflicts only when the same value is inserted concurrently.** Two transactions inserting different values into a Set do not conflict. However, two transactions inserting the same value will conflict. This is generally low contention for use cases like nullifier sets where each value is unique.

- [ ] **`MerkleTree.insert(leaf)` — conflicts when concurrent inserts occur.** Every insertion into a MerkleTree changes the root hash. If two transactions insert leaves concurrently, the second transaction's proof was computed against the old root and is now invalid. Use `HistoricMerkleTree` to mitigate this for membership proofs (old roots remain valid), but concurrent inserts themselves still contend on the tree structure.

  ```compact
  // CONTENTION-PRONE — concurrent inserts change the root
  export ledger members: MerkleTree<16, Bytes<32>>;

  export circuit register(commitment: Bytes<32>): [] {
    members.insert(disclose(commitment));
    // If two users register concurrently, one transaction fails
  }

  // BETTER for membership verification — HistoricMerkleTree retains old roots
  // so that verification paths obtained before concurrent inserts remain valid
  export ledger members: HistoricMerkleTree<16, Bytes<32>>;
  ```

- [ ] **`List.push(value)` — conflicts when concurrent pushes occur.** List ordering is significant. When two transactions push concurrently, they conflict because the resulting list depends on insertion order. If ordering is not important, consider whether a Set or Map would be more appropriate.

## Design Patterns for Low Contention Checklist

Check the contract design for patterns that minimize transaction conflicts under concurrent load.

- [ ] **Prefer `Counter.increment()` over read-then-set for counters.** Whenever a contract needs to accumulate a value (vote counts, deposit totals, participation counters), use `Counter` with `increment()` or `decrement()`. These are commutative operations that never conflict. Reading and manually setting is the most common contention anti-pattern.

  ```compact
  // BAD — contention on every concurrent vote
  export circuit vote(): [] {
    const current = vote_count.read();
    vote_count = current + 1;
  }

  // GOOD — all concurrent votes succeed
  // export ledger vote_count: Counter;
  export circuit vote(): [] {
    vote_count.increment(1);
  }
  ```

- [ ] **Use per-user Map entries rather than a single global value.** When each user needs to store state, use a Map keyed by user identity (public key or derived identifier). This ensures concurrent transactions from different users write to different keys, eliminating cross-user contention.

  ```compact
  // BAD — single global value; every user transaction contends
  export ledger last_action: Field;

  export circuit perform_action(action: Field): [] {
    last_action = disclose(action);
  }

  // GOOD — per-user entries; no cross-user contention
  export ledger user_actions: Map<Bytes<32>, Field>;

  export circuit perform_action(action: Field): [] {
    const sk = local_secret_key();
    const pk = disclose(publicKey(sk));
    user_actions.insert(pk, disclose(action));
  }
  ```

- [ ] **Design circuits so concurrent users modify different state entries.** Structure the contract so that each user's transaction touches only state that belongs to that user. Shared state (global counters, configuration) should use conflict-free operations. The ideal is that two concurrent transactions from different users have zero state overlap in their writes.

  ```compact
  // GOOD — each user's deposit modifies only their own balance entry
  // and the shared counter uses conflict-free increment
  export ledger balances: Map<Bytes<32>, Field>;
  export ledger total_deposits: Counter;

  export circuit deposit(amount: Field): [] {
    const sk = local_secret_key();
    const pk = disclose(publicKey(sk));
    const current = balances.member(pk) ? balances.lookup(pk) : 0;
    balances.insert(pk, current + disclose(amount));
    total_deposits.increment(disclose(amount));
  }
  ```

- [ ] **Use `MerkleTree` for membership proofs rather than `Set` when high throughput is needed.** While both `Set` and `MerkleTree` can represent membership, `MerkleTree` (especially `HistoricMerkleTree`) allows membership proofs to remain valid even after concurrent insertions change the root. With `Set`, a `member()` check depends on the current set state, and concurrent modifications can invalidate pending transactions.

  ```compact
  // LOWER THROUGHPUT — Set membership check depends on current state
  export ledger allowlist: Set<Bytes<32>>;

  export circuit check_member(id: Bytes<32>): [] {
    assert(allowlist.member(disclose(id)), "Not in allowlist");
  }

  // HIGHER THROUGHPUT — HistoricMerkleTree allows older proofs to succeed
  export ledger allowlist: HistoricMerkleTree<16, Bytes<32>>;

  export circuit check_member(path: MerkleTreePath<16, Bytes<32>>): [] {
    const root = merkleTreePathRoot<16, Bytes<32>>(path);
    assert(allowlist.checkRoot(disclose(root)), "Not in allowlist");
  }
  ```

## Red Flags Checklist

Check the contract for high-contention anti-patterns that will cause transaction failures at scale.

- [ ] **Any exported circuit that calls both `.read()` and modifies the same ledger variable.** This is the fundamental contention pattern. Search for `export circuit` bodies that contain a `.read()` call on a ledger variable followed by a write to the same variable. Every such circuit will fail under concurrent load.

  ```compact
  // RED FLAG — reads and writes same variable
  export circuit process(): [] {
    const val = state_var.read();    // Read
    state_var = val + 1;             // Write derived from read
    // Under concurrent load, most transactions fail
  }
  ```

- [ ] **Global state (single variable) updated by every user transaction.** If a contract has a ledger variable that every user transaction writes to (e.g., a global counter stored as a `Field`, a single status flag, a "last updated by" field), every concurrent transaction will contend on that variable. Either remove the global state, move it to a per-user Map, or use a `Counter` if the update is additive.

  ```compact
  // RED FLAG — every user transaction writes to the same global variable
  export ledger total_contributions: Field;

  export circuit contribute(amount: Field): [] {
    const current = total_contributions;
    total_contributions = current + disclose(amount);
    // Every concurrent contribute() call conflicts
  }

  // FIX — use Counter for the shared accumulator
  export ledger total_contributions: Counter;

  export circuit contribute(amount: Field): [] {
    total_contributions.increment(disclose(amount));
    // All concurrent contribute() calls succeed
  }
  ```

- [ ] **Auction/voting patterns where all users write to the same field.** Auctions where every bid writes to a `highest_bid` field, or voting contracts where every vote writes to a shared `results` variable, are inherently contention-prone. Under load, most transactions will fail.

  ```compact
  // RED FLAG — every bid writes to the same highest_bid field
  export ledger highest_bid: Field;
  export ledger highest_bidder: Bytes<32>;

  export circuit place_bid(amount: Field): [] {
    assert(disclose(amount) > highest_bid, "Bid too low");
    highest_bid = disclose(amount);
    highest_bidder = disclose(publicKey(local_secret_key()));
    // Only one bid can succeed per block; all others fail
  }

  // BETTER — store each bid separately, determine winner off-chain or in a finalize step
  export ledger bids: Map<Bytes<32>, Field>;
  export ledger bid_count: Counter;

  export circuit place_bid(amount: Field): [] {
    const sk = local_secret_key();
    const pk = disclose(publicKey(sk));
    assert(disclose(amount) > 0, "Bid must be positive");
    bids.insert(pk, disclose(amount));
    bid_count.increment(1);
  }
  ```

- [ ] **Commit-reveal scheme where reveal phase reads global commitment state.** In a commit-reveal protocol, if the reveal phase reads a shared state variable that is also modified by other commits, concurrent reveals will contend. Structure the protocol so each user's commitment is stored independently (e.g., in a Map keyed by user identity) and the reveal reads only that user's entry.

  ```compact
  // RED FLAG — single shared commitment variable; only one user at a time
  export ledger current_commitment: Bytes<32>;

  export circuit commit(c: Bytes<32>): [] {
    current_commitment = disclose(c);
  }

  // BETTER — per-user commitments; no cross-user contention
  export ledger commitments: Map<Bytes<32>, Bytes<32>>;

  export circuit commit(c: Bytes<32>): [] {
    const sk = local_secret_key();
    const pk = disclose(publicKey(sk));
    commitments.insert(pk, disclose(c));
  }
  ```

## Anti-Patterns Table

Quick reference of common concurrency anti-patterns in Compact contracts.

| Anti-Pattern | Why It Fails | Correct Approach |
|---|---|---|
| `const val = counter.read(); counter = val + 1` | Two concurrent transactions both read the same value and both try to write the same result; only one succeeds, the rest fail | `counter.increment(1)` — commutative operation that never conflicts regardless of concurrency |
| Single global `Field` variable updated by every transaction | Every concurrent transaction writes to the same storage slot; only one can succeed per block | Use `Counter` for additive updates, or `Map` with per-user keys for individual state |
| `highest_bid = amount` in auction circuit | Every bidder writes to the same field; under load, almost all bids fail | Store bids in a `Map` keyed by bidder identity; determine the winner in a separate finalize step |
| `scores.insert(key, scores.lookup(key) + points)` on shared key | Read-modify-write on the same Map key; concurrent updates to the same key conflict | Use per-user keys so each user modifies only their own entry, or use `Counter` for additive accumulation |
| `MerkleTree.insert()` under high concurrent load | Every insert changes the root; concurrent inserts invalidate each other's proofs | Use `HistoricMerkleTree` for membership verification (old roots stay valid); accept that concurrent inserts still contend |
| `List.push()` from many concurrent users | Pushes conflict because list ordering depends on insertion sequence | Use `Map` or `Set` if ordering is not required; accept contention if strict ordering is necessary |
| Single status flag (`state = State.ACTIVE`) set by every user | All concurrent transactions write to the same enum variable; only one succeeds | Redesign so the status is derived from per-user state, or limit state transitions to a single admin |
