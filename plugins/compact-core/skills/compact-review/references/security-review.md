# Security & Cryptographic Correctness Review Checklist

Review checklist for the **Security & Cryptographic Correctness** category. This covers access control, cryptographic primitive usage, Merkle path verification, error handling, and input validation. Apply every item below to the contract under review.

## Shared Evidence

The orchestrator runs `compact compile --skip-zk` on the contract before dispatching reviewers. The resulting `COMPILE_RESULT` (full stdout/stderr from the compiler) is provided in your prompt. Reference this compilation output when evaluating checklist items. Read the contract source files directly to inspect structure, declarations, and patterns.

## Access Control Checklist

Check every exported circuit for proper authorization and state guards.

- [ ] **Exported circuit with no authorization check.** Any `export circuit` that modifies ledger state (writes to maps, sets, counters, sealed fields, or Merkle trees) must verify the caller's identity. An exported circuit without an authorization check allows anyone to invoke it, which is equivalent to leaving an admin endpoint open to the public.

  ```compact
  // BAD — anyone can call this and reset the contract
  export circuit reset(): [] {
    state = State.UNSET;
    counter.increment(1);
  }

  // GOOD — only the authorized party can reset
  export circuit reset(): [] {
    const sk = local_secret_key();
    const pk = disclose(publicKey(sk));
    assert(authority == pk, "Not authorized to reset");
    state = State.UNSET;
    counter.increment(1);
  }
  ```

  > **Tool:** Read the contract source to list all exported circuits and their structure. Cross-reference each exported circuit that modifies state against the presence of authorization checks.

- [ ] **Missing ownership verification before state-modifying operations.** For contracts with an owner or authority pattern, every state-modifying circuit must verify that the caller holds the correct secret key. Look for `publicKey(secretKey, domain)` or equivalent derivation followed by an `assert` comparing against a stored authority. If the comparison is missing, anyone can modify state.

  ```compact
  // BAD — modifies owner-controlled state without checking ownership
  export circuit set_value(value: Field): [] {
    assert(state == State.SET, "Not initialized");
    stored_value = value;
  }

  // GOOD — verifies ownership before modification
  export circuit set_value(value: Field): [] {
    assert(state == State.SET, "Not initialized");
    const sk = local_secret_key();
    const pk = disclose(publicKey(sk));
    assert(authority == pk, "Not authorized");
    stored_value = value;
  }
  ```

- [ ] **`publicKey()` derivation missing domain separation for different roles.** If a contract has multiple roles (e.g., admin vs user, minter vs burner), each role must use a distinct domain string in the `publicKey` derivation. Without domain separation, a key authorized for one role could be used for another.

  ```compact
  // BAD — same derivation for both roles; admin key = user key
  circuit adminKey(sk: Bytes<32>): Bytes<32> {
    return persistentHash<Vector<2, Bytes<32>>>([pad(32, "myapp:pk:"), sk]);
  }
  circuit userKey(sk: Bytes<32>): Bytes<32> {
    return persistentHash<Vector<2, Bytes<32>>>([pad(32, "myapp:pk:"), sk]);
  }

  // GOOD — distinct domain strings for each role
  circuit adminKey(sk: Bytes<32>): Bytes<32> {
    return persistentHash<Vector<2, Bytes<32>>>([pad(32, "myapp:admin:"), sk]);
  }
  circuit userKey(sk: Bytes<32>): Bytes<32> {
    return persistentHash<Vector<2, Bytes<32>>>([pad(32, "myapp:user:"), sk]);
  }
  ```

- [ ] **Admin or authority function callable by anyone.** Look for circuits that perform privileged operations (minting tokens, updating configuration, pausing the contract, transferring ownership) without an `assert(caller == owner)` or equivalent check. This is a critical vulnerability.

  ```compact
  // BAD — minting without authorization
  export circuit mint(amount: Field): [] {
    token.mint(amount);
  }

  // GOOD — only authority can mint (pattern from lock.compact)
  export circuit mint(amount: Field): [] {
    const sk = secretKey();
    const pk = publicKey(round, sk);
    assert(authority == pk, "Attempted to mint without authorization");
    token.mint(amount);
  }
  ```

- [ ] **Missing state machine guards.** For contracts implementing a multi-phase protocol (e.g., commit-reveal, propose-vote-execute, lock-unlock), each phase transition must assert the current state before proceeding. Calling a later phase before an earlier one has completed can lead to protocol violations.

  ```compact
  // BAD — reveal can be called without a prior commit
  export circuit reveal(value: Field, salt: Bytes<32>): [] {
    const expected = persistentCommit<Field>(value, salt);
    assert(stored_commitment == expected, "Invalid reveal");
    revealed_value = disclose(value);
  }

  // GOOD — state guard ensures correct phase ordering
  export circuit reveal(value: Field, salt: Bytes<32>): [] {
    assert(state == State.COMMITTED, "Must be in COMMITTED state to reveal");
    const expected = persistentCommit<Field>(value, salt);
    assert(stored_commitment == expected, "Invalid reveal");
    revealed_value = disclose(value);
    state = State.REVEALED;
  }
  ```

## Cryptographic Correctness Checklist

Check hash and commitment usage for correctness, determinism, and domain separation.

- [ ] **`persistentHash` vs `persistentCommit` vs `transientHash` vs `transientCommit` — correct usage.** Each primitive has distinct properties and a correct use case. Using the wrong one is a security bug.

  | Primitive | Deterministic? | Clears Taint? | Use For |
  |-----------|---------------|---------------|---------|
  | `persistentHash` | Yes — same input always produces same output | No | Public identifiers, nullifiers, domain-separated keys. Value must be reproducible across transactions. |
  | `persistentCommit` | Yes (with nonce) — same input + nonce produces same output | Yes | Commitments that must be verifiable later. The nonce provides hiding; taint clearing allows on-chain storage. |
  | `transientHash` | Deterministic within a single execution, but not guaranteed across compiler upgrades | No | One-time computations within a single circuit execution. Never store the result on-chain. |
  | `transientCommit` | Deterministic within a single execution (with nonce), but not guaranteed across compiler upgrades | Yes | One-time commitments within a single circuit execution. Never store the result on-chain. |

  ```compact
  // BAD — using transientHash for a nullifier (not reproducible)
  const nullifier = transientHash<Vector<2, Bytes<32>>>([pad(32, "app:nul:"), sk]);
  // This produces a different value each time; cannot detect double-spend

  // GOOD — using persistentHash for a nullifier (always reproducible)
  const nullifier = persistentHash<Vector<2, Bytes<32>>>([pad(32, "app:nul:"), sk]);
  // Same sk always produces the same nullifier
  ```

  ```compact
  // BAD — using persistentHash to hide a private value on-chain
  const hidden = persistentHash<Vector<2, Bytes<32>>>([pad(32, "app:"), secret]);
  // Does NOT clear witness taint; compiler will reject writing to ledger

  // GOOD — using persistentCommit to hide a private value
  const salt = get_randomness();
  const hidden = persistentCommit<Vector<2, Bytes<32>>>([pad(32, "app:"), secret], salt);
  // Clears taint, hides the value, can be stored on ledger
  ```

  > **Tool:** Read the contract source to identify hash and commit usage. Verify each call uses the correct primitive per the table above. Use `octocode` to search the LFDT-Minokawa/compact repository for reference patterns for correct cryptographic primitive usage.

- [ ] **Domain separation: every hash/commit call should include a unique domain string.** Without domain separation, identical inputs across different protocols or different purposes within the same contract produce the same hash output, enabling cross-protocol replay attacks or unintended hash collisions.

  ```compact
  // BAD — no domain separation; vulnerable to cross-protocol attacks
  const h = persistentHash<Bytes<32>>(sk);

  // GOOD — domain separation prevents cross-protocol collisions
  // (pattern from midnames)
  export circuit publicKey(sk: Bytes<32>): Bytes<32> {
      return persistentHash<Vector<2, Bytes<32>>>(
          [pad(32, "midnames:pk:"), sk]
      );
  }
  ```

  ```compact
  // GOOD — distinct domain strings for different purposes within one contract
  // (pattern from micro-dao)
  circuit commitment_nullifier(sk: Bytes<32>): Bytes<32> {
    return disclose(persistentHash<Vector<3, Bytes<32>>>(
      [pad(32, "lares:udao:cm-nul:"), round as Field as Bytes<32>, sk]
    ));
  }

  circuit reveal_nullifier(sk: Bytes<32>): Bytes<32> {
    return disclose(persistentHash<Vector<3, Bytes<32>>>(
      [pad(32, "lares:udao:rv-nul:"), round as Field as Bytes<32>, sk]
    ));
  }
  ```

  > **Tool:** Use `octocode` to search the LFDT-Minokawa/compact repository for official examples of domain separation patterns to compare against.

- [ ] **Nullifier construction: must be deterministic, include secret key + unique identifier, and use domain separation.** A nullifier is a one-time-use token derived from a secret to prevent double-spending or double-voting. It must satisfy three properties:
  1. **Deterministic** (uses `persistentHash`, not `transientHash`) so the same secret always produces the same nullifier.
  2. **Includes a secret** so that an observer cannot pre-compute nullifiers for other users.
  3. **Domain-separated** so the nullifier cannot collide with nullifiers from other protocols or other purposes in the same contract.

  ```compact
  // BAD — no secret key; anyone can predict the nullifier
  const nullifier = persistentHash<Bytes<32>>(proposalId as Field as Bytes<32>);

  // BAD — no domain separation; could collide with another contract
  const nullifier = persistentHash<Vector<2, Bytes<32>>>([proposalId as Field as Bytes<32>, sk]);

  // GOOD — includes secret, unique identifier, and domain separation
  const nullifier = persistentHash<Vector<3, Bytes<32>>>(
    [pad(32, "myapp:vote-nul:"), proposalId as Field as Bytes<32>, sk]
  );
  ```

- [ ] **Commitment scheme: commitment must use nonce/salt; reveal phase must verify against stored commitment.** A commitment without a nonce is just a hash and can be brute-forced if the input space is small. The reveal phase must recompute the commitment from the revealed value and nonce, then compare against the stored commitment.

  ```compact
  // BAD — commitment without nonce; can be brute-forced
  export circuit commit(value: Field): [] {
    stored_commitment = disclose(persistentHash<Field>(value));
    state = State.COMMITTED;
  }

  // GOOD — commitment with nonce; reveal verifies
  export circuit commit(value: Field): [] {
    const salt = get_randomness();
    stored_commitment = disclose(persistentCommit<Field>(value, salt));
    state = State.COMMITTED;
  }

  export circuit reveal(value: Field, salt: Bytes<32>): [] {
    assert(state == State.COMMITTED, "Must commit first");
    const recomputed = persistentCommit<Field>(value, salt);
    assert(stored_commitment == disclose(recomputed), "Commitment mismatch");
    revealed_value = disclose(value);
    state = State.REVEALED;
  }
  ```

## Merkle Path Verification Checklist

Check Merkle tree operations for correct root verification and data structure choice.

- [ ] **`checkRoot()` called to verify path against current tree root.** After computing a Merkle root from a witness-provided path, the result must be checked against the on-chain tree root using `checkRoot()`. Without this check, a prover can fabricate any path and claim membership.

  ```compact
  // BAD — computes root but never checks it against on-chain state
  const digest = merkleTreePathRoot<16, Bytes<32>>(path);
  // Proceeds as if membership is verified, but it is not

  // GOOD — verifies computed root against on-chain tree root
  const digest = merkleTreePathRoot<16, Bytes<32>>(path);
  assert(members.checkRoot(disclose(digest)), "Merkle root mismatch");
  ```

  > **Tool:** Read the contract source to identify MerkleTree operations. Verify every `merkleTreePathRoot` call is followed by a `checkRoot()` assertion.

- [ ] **Path leaf matches expected value.** A valid Merkle path proves that *some* leaf is in the tree, but the reviewer must verify that the leaf at the base of the path is the expected value (e.g., the user's commitment, the voter's credential). If the contract does not check what leaf the path proves membership for, a user could supply a path for a different leaf.

  ```compact
  // BAD — proves some leaf is in the tree, but not which one
  const root = merkleTreePathRoot<16, Bytes<32>>(path);
  assert(members.checkRoot(disclose(root)), "Not a member");

  // GOOD — verifies the leaf is the expected commitment
  const my_commitment = persistentHash<Vector<2, Bytes<32>>>(
    [pad(32, "app:member:"), sk]
  );
  const root = merkleTreePathRoot<16, Bytes<32>>(path);
  assert(path.leaf == my_commitment, "Path does not prove your membership");
  assert(members.checkRoot(disclose(root)), "Not a member");
  ```

- [ ] **Using `HistoricMerkleTree` when membership must persist across state changes.** A regular `MerkleTree` changes its root every time a new leaf is inserted. If a user obtains a Merkle path and another user inserts a leaf before the first user's transaction lands, the first user's path becomes invalid (root mismatch). `HistoricMerkleTree` retains previous roots, so older paths remain valid.

  ```compact
  // BAD — regular MerkleTree; paths invalidated by concurrent inserts
  export ledger members: MerkleTree<16, Bytes<32>>;

  // GOOD — HistoricMerkleTree; old paths remain valid
  export ledger members: HistoricMerkleTree<16, Bytes<32>>;
  ```

- [ ] **Root comparison done correctly: not just path validity but root matches on-chain state.** Verify that the code does not merely check that a Merkle path is internally consistent (valid hash chain) but also that the resulting root matches the actual on-chain tree root. The `checkRoot()` method on the ledger tree handles this. Manual root comparison must use the correct ledger value.

  ```compact
  // BAD — checks path structure but not against on-chain root
  const root = merkleTreePathRoot<16, Bytes<32>>(path);
  assert(root != pad(32, ""), "Invalid path");  // Only checks non-empty

  // GOOD — checks path against the actual on-chain Merkle root
  const root = merkleTreePathRoot<16, Bytes<32>>(path);
  assert(members.checkRoot(disclose(root)), "Root does not match on-chain tree");
  ```

## Error Handling Security Checklist

Check assertions and error paths for information leakage and missing safety checks.

- [ ] **Assert messages that leak sensitive information.** Error messages in `assert()` statements are visible to anyone observing the transaction failure. If the message includes the expected value, a secret, or private state, it leaks information. Keep error messages generic.

  ```compact
  // BAD — error message reveals the expected authority public key
  assert(caller_pk == authority,
    "Expected authority: " + authority_hex);

  // BAD — error message reveals current balance
  assert(balance >= amount,
    "Balance is only " + balance_str);

  // GOOD — generic error message reveals nothing
  assert(caller_pk == authority, "Not authorized");
  assert(balance >= amount, "Insufficient balance");
  ```

- [ ] **Missing assertions before dangerous operations.** Operations like `map.lookup()` will fail at runtime if the key does not exist. Always check `map.member()` before `map.lookup()`, or use a pattern that handles the missing-key case. Similarly, check set membership before relying on set-derived values.

  ```compact
  // BAD — lookup without membership check; runtime failure if key absent
  export circuit get_balance(account: Bytes<32>): Field {
    return disclose(balances.lookup(account));
  }

  // GOOD — check membership first
  export circuit get_balance(account: Bytes<32>): Field {
    assert(balances.member(account), "Account not found");
    return disclose(balances.lookup(account));
  }
  ```

  > **Tool:** `COMPILE_RESULT` may reveal runtime failures from missing safety checks. Use `octocode` to search the LFDT-Minokawa/compact repository for guidance on safe Map/Set access patterns.

- [ ] **Missing bounds checks before arithmetic operations.** Subtraction underflow, division by zero, and array out-of-bounds access must be guarded with assertions. For `Field` types, arithmetic underflow wraps around silently (modular arithmetic), producing an incorrect but valid-looking result. For `Uint<N>` types: addition and multiplication cannot overflow (the compiler widens the result type), but subtraction underflow causes a runtime error. There is no silent wrapping for `Uint`. In both cases, explicit bounds checks prevent unexpected behavior.

  ```compact
  // BAD — subtraction without underflow check
  // For Field: wraps silently (modular arithmetic)
  // For Uint<N>: causes a runtime error
  export circuit withdraw(amount: Field): [] {
    const current = balances.lookup(account);
    balances.insert(account, current - amount);
  }

  // GOOD — assert sufficient balance before subtraction
  export circuit withdraw(amount: Field): [] {
    assert(balances.member(account), "Account not found");
    const current = balances.lookup(account);
    assert(current >= amount, "Insufficient balance");
    balances.insert(account, current - amount);
  }
  ```

## Input Validation Checklist

Check exported circuit parameters for proper validation.

- [ ] **Exported circuit parameters: are all inputs validated with appropriate assertions?** Every parameter to an `export circuit` is caller-controlled. The contract must validate all inputs before using them. Without validation, a malicious caller can pass crafted values that bypass intended logic.

  ```compact
  // BAD — caller-controlled 'to' and 'amount' used without validation
  export circuit transfer(to: Bytes<32>, amount: Field): [] {
    const from_balance = balances.lookup(from_account);
    balances.insert(from_account, from_balance - amount);
    balances.insert(to, amount);
  }

  // GOOD — validate all caller-controlled inputs
  export circuit transfer(to: Bytes<32>, amount: Field): [] {
    assert(amount > 0, "Amount must be positive");
    assert(balances.member(from_account), "Sender account not found");
    const from_balance = balances.lookup(from_account);
    assert(from_balance >= amount, "Insufficient balance");
    balances.insert(from_account, from_balance - amount);
    const to_balance = balances.member(to) ? balances.lookup(to) : 0;
    balances.insert(to, to_balance + amount);
  }
  ```

- [ ] **Zero-value checks where zero would cause issues.** Zero amounts in token transfers, zero-length inputs, and zero divisors can all cause unexpected behavior. Check for zero explicitly where it matters.

  ```compact
  // BAD — allows zero-amount transfer (no-op that wastes gas, or worse)
  export circuit transfer(to: Bytes<32>, amount: Field): [] {
    // amount could be 0, making this a meaningless transaction
    balances.insert(from_account, from_balance - amount);
    balances.insert(to, to_balance + amount);
  }

  // GOOD — reject zero amounts
  export circuit transfer(to: Bytes<32>, amount: Field): [] {
    assert(amount > 0, "Amount must be non-zero");
    // ... rest of transfer logic
  }
  ```

- [ ] **Boundary condition checks for maximum values and empty collections.** Verify that inputs do not exceed protocol-defined maximums (e.g., max token supply, max tree depth, max participants). Also verify behavior when collections (maps, sets, lists) are empty.

  ```compact
  // BAD — no maximum check; could overflow total supply
  export circuit mint(amount: Field): [] {
    assert(caller_pk == authority, "Not authorized");
    token.mint(amount);
  }

  // GOOD — enforce supply cap
  export circuit mint(amount: Field): [] {
    assert(caller_pk == authority, "Not authorized");
    assert(amount > 0, "Amount must be positive");
    const current_supply = total_supply.read();
    assert(current_supply + amount <= MAX_SUPPLY, "Exceeds maximum supply");
    token.mint(amount);
    total_supply.increment(amount);
  }
  ```

## Anti-Patterns Table

Quick reference of common security anti-patterns in Compact contracts.

| Anti-Pattern | Why It's Wrong | Correct Approach |
|---|---|---|
| `export circuit` with no `assert(caller == owner)` on state change | Anyone can invoke the circuit and modify contract state, leading to unauthorized minting, draining, or resetting | Derive caller identity via `publicKey(secretKey())` and assert against stored authority before any state modification |
| `transientHash` used for nullifier | Non-deterministic; same input produces different outputs each call; double-spend detection fails completely | `persistentHash` with domain separation and secret key inclusion; deterministic output enables reliable duplicate detection |
| Hash/commit call without domain string | Identical inputs from different contracts or different purposes produce the same output; enables cross-protocol replay attacks | Include a unique domain prefix in every hash: `[pad(32, "appname:purpose:"), ...]` |
| Nullifier without secret key | Anyone can pre-compute nullifiers for other users and front-run or block their actions | Include the user's secret key in the nullifier derivation so only the key holder can produce it |
| `map.lookup()` without `map.member()` check | Runtime failure if key does not exist; transaction reverts with an uninformative error | Always check `map.member(key)` before `map.lookup(key)` |
| Commitment without nonce/salt | Just a hash; if the input space is small (boolean, small integer), an observer can brute-force the value | Use `persistentCommit` with a random salt/nonce; hiding property requires the blinding factor |
| Regular `MerkleTree` for concurrent membership | Root changes on every insert; paths obtained before a concurrent insert become invalid | Use `HistoricMerkleTree` which retains previous roots and validates older paths |
| Assert message reveals expected value | Failed transaction error message leaks private state (balance, authority key, expected commitment) to observers | Keep assert messages generic: "Not authorized", "Insufficient balance", "Invalid proof" |
| Missing state machine guard on phase transition | Calling `reveal` before `commit`, or `execute` before `vote`, breaks protocol invariants | Assert current state at the top of each phase-transition circuit: `assert(state == State.COMMITTED, ...)` |
| No bounds check before arithmetic | `Field` subtraction underflow wraps silently (modular arithmetic); `Uint<N>` addition/multiplication widen the result type (no overflow), but subtraction underflow causes a runtime error. There is no silent wrapping for `Uint`. | Assert `a >= b` before computing `a - b`; assert `amount > 0` for all token operations |

