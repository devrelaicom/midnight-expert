# Testing Adequacy Review Checklist

Review checklist for the **Testing Adequacy** category. This covers test coverage for exported circuits, edge case and boundary testing, negative/failure-path testing, private state verification, witness mock correctness, and integration test patterns. Apply every item below to the test files accompanying the contract under review.

## Test Coverage Checklist

Check that the test suite provides baseline coverage for every exported circuit and constructor.

- [ ] **Every exported circuit has at least one test.** Each `export circuit` in the Compact contract must have a corresponding test that invokes it and verifies its observable effects (ledger state changes, return values, emitted events). An untested circuit is an unverified circuit — it may compile but behave incorrectly at runtime. List every exported circuit and check each one off against the test file.

  ```compact
  // Contract declares three exported circuits
  export circuit initialize(authority: Bytes<32>): [] { /* ... */ }
  export circuit deposit(amount: Uint<64>): [] { /* ... */ }
  export circuit withdraw(amount: Uint<64>): [] { /* ... */ }
  ```

  ```typescript
  // BAD — only tests initialize; deposit and withdraw are untested
  describe("Vault contract", () => {
    it("should initialize with authority", async () => {
      const tx = await contract.initialize(authorityKey);
      expect(tx.public.state).toBeDefined();
    });
    // deposit — MISSING
    // withdraw — MISSING
  });

  // GOOD — every exported circuit has at least one test
  describe("Vault contract", () => {
    it("should initialize with authority", async () => {
      const tx = await contract.initialize(authorityKey);
      expect(tx.public.state).toBeDefined();
    });

    it("should accept deposits", async () => {
      await contract.initialize(authorityKey);
      const tx = await contract.deposit(100n);
      expect(tx.public.balance).toBe(100n);
    });

    it("should process withdrawals", async () => {
      await contract.initialize(authorityKey);
      await contract.deposit(500n);
      const tx = await contract.withdraw(200n);
      expect(tx.public.balance).toBe(300n);
    });
  });
  ```

- [ ] **Constructor tested with expected initial state.** The contract constructor (typically the `deploy` or `initialize` circuit) sets the initial ledger state. A test must verify that all ledger fields are initialized to their expected values after construction. Missing constructor tests allow incorrect initialization to go undetected, causing all subsequent circuit calls to operate on wrong state.

  ```typescript
  // BAD — calls constructor but does not verify initial state
  describe("Token contract", () => {
    it("should deploy", async () => {
      const contract = await deployContract();
      // No assertions on initial state
    });
  });

  // GOOD — verifies all initial state fields
  describe("Token contract", () => {
    it("should initialize with correct state", async () => {
      const contract = await deployContract({
        initialAuthority: authorityPk,
        tokenName: "TestToken",
      });

      const ledgerState = await contract.getLedgerState();
      expect(ledgerState.authority).toEqual(authorityPk);
      expect(ledgerState.totalSupply).toBe(0n);
      expect(ledgerState.state).toBe(State.INITIALIZED);
    });
  });
  ```

- [ ] **Happy path tested for each circuit.** Beyond mere invocation, each exported circuit needs a test that walks the expected success path: valid inputs, correct authorization, proper state preconditions. The test must verify the expected outcome — ledger state changes, return values, and private state updates. A test that calls a circuit without asserting outcomes is not a test; it only verifies the call does not throw.

  ```typescript
  // BAD — invokes circuit but asserts nothing about the outcome
  it("should transfer tokens", async () => {
    await contract.transfer(recipientPk, 50n);
    // No assertions — what did the transfer actually do?
  });

  // GOOD — verifies the full happy-path outcome
  it("should transfer tokens and update balances", async () => {
    await contract.mint(senderPk, 100n);

    const tx = await contract.transfer(recipientPk, 50n);

    const senderBalance = await contract.getBalance(senderPk);
    const recipientBalance = await contract.getBalance(recipientPk);
    expect(senderBalance).toBe(50n);
    expect(recipientBalance).toBe(50n);
    expect(tx.public.totalSupply).toBe(100n); // Supply unchanged
  });
  ```

- [ ] **Error/revert cases tested (assert failures).** Every `assert()` in the Compact contract represents a condition that should cause transaction failure when violated. Each assertion must have a corresponding test that triggers the failure and verifies the transaction reverts. Without these tests, assertion guards may be wrong (e.g., inverted condition) or missing entirely.

  ```compact
  // Contract has these assertions
  export circuit withdraw(amount: Uint<64>): [] {
    assert(state == State.ACTIVE, "Contract not active");
    assert(balance >= amount, "Insufficient balance");
    assert(amount > 0, "Amount must be positive");
    balance = balance - amount;
  }
  ```

  ```typescript
  // GOOD — tests each assertion independently
  describe("withdraw assertions", () => {
    it("should revert when contract is not active", async () => {
      // Contract starts in INITIALIZED state, not ACTIVE
      await expect(contract.withdraw(10n)).rejects.toThrow(
        "Contract not active",
      );
    });

    it("should revert when balance is insufficient", async () => {
      await activateContract();
      await contract.deposit(50n);
      await expect(contract.withdraw(100n)).rejects.toThrow(
        "Insufficient balance",
      );
    });

    it("should revert on zero amount", async () => {
      await activateContract();
      await contract.deposit(50n);
      await expect(contract.withdraw(0n)).rejects.toThrow(
        "Amount must be positive",
      );
    });
  });
  ```

## Edge Case Checklist

Check that the test suite covers boundary values and degenerate inputs that often expose arithmetic or logic bugs.

- [ ] **Zero values tested: amount=0, empty bytes, zero-valued fields.** Zero is the most common source of edge-case bugs in smart contracts. A transfer of zero tokens should either be rejected or handled as a no-op. An empty `Bytes<32>` (all zeros) used as an address or key may collide with uninitialized storage. Test zero for every numeric parameter and empty/zero for every bytes parameter.

  ```typescript
  // GOOD — explicit zero-value tests
  describe("zero value edge cases", () => {
    it("should reject zero-amount transfer", async () => {
      await expect(contract.transfer(recipientPk, 0n)).rejects.toThrow(
        "Amount must be positive",
      );
    });

    it("should reject zero-address recipient", async () => {
      const zeroAddress = new Uint8Array(32); // All zeros
      await expect(contract.transfer(zeroAddress, 50n)).rejects.toThrow(
        "Invalid recipient",
      );
    });

    it("should handle zero balance query without error", async () => {
      const balance = await contract.getBalance(newAccountPk);
      expect(balance).toBe(0n);
    });
  });
  ```

- [ ] **Maximum values tested: max Uint<64>, max Uint<128>, field maximum.** Arithmetic overflow is silent in ZK circuits — it wraps around without error. Tests must verify behavior at the upper boundary of each numeric type. For `Uint<64>`, the maximum is `2^64 - 1` (`18446744073709551615n`). For `Uint<128>`, it is `2^128 - 1`. Minting or transferring the maximum value, and then attempting one more, should be tested.

  ```typescript
  const MAX_UINT64 = (1n << 64n) - 1n;   // 18446744073709551615n
  const MAX_UINT128 = (1n << 128n) - 1n;

  describe("maximum value edge cases", () => {
    it("should handle minting up to max supply", async () => {
      const tx = await contract.mint(recipientPk, MAX_UINT64);
      expect(tx.public.totalSupply).toBe(MAX_UINT64);
    });

    it("should reject minting beyond max supply (overflow)", async () => {
      await contract.mint(recipientPk, MAX_UINT64);
      // Minting 1 more would overflow Uint<64>
      await expect(contract.mint(recipientPk, 1n)).rejects.toThrow();
    });

    it("should handle transfer of max amount", async () => {
      await contract.mint(senderPk, MAX_UINT64);
      const tx = await contract.transfer(recipientPk, MAX_UINT64);
      expect(await contract.getBalance(senderPk)).toBe(0n);
      expect(await contract.getBalance(recipientPk)).toBe(MAX_UINT64);
    });
  });
  ```

- [ ] **Boundary values tested: exactly at limit, one above, one below.** For any contract-defined limit (max supply, max participants, minimum stake), test exactly at the limit, one unit below, and one unit above. The "off-by-one" error is the most common boundary bug.

  ```typescript
  const MAX_PARTICIPANTS = 100n; // Contract-defined limit

  describe("boundary value tests", () => {
    it("should accept participant at limit", async () => {
      // Register 100 participants (exactly at limit)
      for (let i = 0n; i < MAX_PARTICIPANTS; i++) {
        await contract.register(generateKey(i));
      }
      const count = await contract.getParticipantCount();
      expect(count).toBe(MAX_PARTICIPANTS);
    });

    it("should reject participant above limit", async () => {
      // Register 100, then try 101st
      for (let i = 0n; i < MAX_PARTICIPANTS; i++) {
        await contract.register(generateKey(i));
      }
      await expect(
        contract.register(generateKey(MAX_PARTICIPANTS)),
      ).rejects.toThrow("Max participants reached");
    });

    it("should accept participant below limit", async () => {
      // Register 99 (one below limit) — should succeed
      for (let i = 0n; i < MAX_PARTICIPANTS - 1n; i++) {
        await contract.register(generateKey(i));
      }
      const count = await contract.getParticipantCount();
      expect(count).toBe(MAX_PARTICIPANTS - 1n);
    });
  });
  ```

- [ ] **Empty collections tested: empty Map lookup, empty List head, empty Set membership.** Ledger data structures may be empty before any data is inserted. Tests must verify that the contract handles empty-collection operations correctly — either by asserting membership before lookup or by handling the missing-key case gracefully.

  ```typescript
  describe("empty collection edge cases", () => {
    it("should handle balance lookup on empty map", async () => {
      // Contract just deployed — no balances exist
      await expect(contract.getBalance(unknownPk)).rejects.toThrow(
        "Account not found",
      );
    });

    it("should report non-membership on empty set", async () => {
      const isMember = await contract.checkMembership(unknownPk);
      expect(isMember).toBe(false);
    });

    it("should handle proposal query when no proposals exist", async () => {
      await expect(contract.getLatestProposal()).rejects.toThrow(
        "No proposals",
      );
    });
  });
  ```

- [ ] **Double operations tested: calling same circuit twice, double-spend attempt.** Idempotency and replay protection are critical in smart contracts. Test what happens when the same operation is performed twice in sequence. For circuits protected by nullifiers, the second call with the same nullifier must fail. For circuits without replay protection, verify whether double-call is intended behavior.

  ```typescript
  describe("double operation tests", () => {
    it("should prevent double-voting with same nullifier", async () => {
      await contract.vote(proposalId, voteValue, secretKey);
      // Second vote with same secret key produces same nullifier
      await expect(
        contract.vote(proposalId, voteValue, secretKey),
      ).rejects.toThrow("Nullifier already used");
    });

    it("should prevent double-spend of same commitment", async () => {
      await contract.deposit(100n);
      await contract.withdraw(100n);
      // Second withdraw with same proof should fail
      await expect(contract.withdraw(100n)).rejects.toThrow(
        "Insufficient balance",
      );
    });

    it("should allow double deposit (not idempotent)", async () => {
      await contract.deposit(50n);
      await contract.deposit(50n);
      const balance = await contract.getBalance(senderPk);
      expect(balance).toBe(100n); // Both deposits should apply
    });

    it("should prevent double initialization", async () => {
      await contract.initialize(authorityKey);
      await expect(contract.initialize(authorityKey)).rejects.toThrow(
        "Already initialized",
      );
    });
  });
  ```

## Negative Testing Checklist

Check that the test suite verifies the contract correctly rejects invalid inputs, unauthorized callers, and illegal state transitions.

- [ ] **Unauthorized access tested: calling admin circuits without authorization.** Every circuit that modifies privileged state (minting, pausing, ownership transfer, configuration changes) must be tested with an unauthorized caller. The test must verify that the transaction reverts with the expected error. Without this test, an access control bug is invisible.

  ```typescript
  describe("unauthorized access tests", () => {
    it("should reject mint from non-authority", async () => {
      // Deploy with authority = adminKey
      await contract.initialize(adminKey);

      // Switch to non-admin caller context
      const nonAdminContext = createWitnessContext(nonAdminSecretKey);
      await expect(
        contract.mint(recipientPk, 1000n, { witnessContext: nonAdminContext }),
      ).rejects.toThrow("Not authorized");
    });

    it("should reject pause from non-owner", async () => {
      const nonOwnerContext = createWitnessContext(nonOwnerSecretKey);
      await expect(
        contract.pause({ witnessContext: nonOwnerContext }),
      ).rejects.toThrow("Not authorized");
    });

    it("should reject config update from non-admin", async () => {
      const userContext = createWitnessContext(userSecretKey);
      await expect(
        contract.updateConfig(newConfig, { witnessContext: userContext }),
      ).rejects.toThrow("Not authorized");
    });
  });
  ```

- [ ] **Invalid state transitions tested: calling circuits out of sequence.** For contracts with state machines (commit-reveal, propose-vote-execute, lock-unlock), test what happens when phases are called out of order. Each invalid transition must revert with the appropriate state guard error.

  ```typescript
  describe("invalid state transition tests", () => {
    it("should reject reveal before commit", async () => {
      // Contract in INITIALIZED state, not COMMITTED
      await expect(
        contract.reveal(secretValue, salt),
      ).rejects.toThrow("Must be in COMMITTED state");
    });

    it("should reject execute before vote concludes", async () => {
      await contract.propose(proposalData);
      // Skip voting phase entirely
      await expect(contract.execute(proposalId)).rejects.toThrow(
        "Voting not concluded",
      );
    });

    it("should reject second commit without reveal", async () => {
      await contract.commit(commitment1);
      // Attempt another commit without revealing the first
      await expect(contract.commit(commitment2)).rejects.toThrow(
        "Already committed",
      );
    });

    it("should reject unlock when not locked", async () => {
      // Contract starts unlocked
      await expect(contract.unlock()).rejects.toThrow("Not locked");
    });
  });
  ```

- [ ] **Insufficient balance tested: transfer more than available.** This is the most basic financial safety test. Every token-handling circuit must be tested with an amount exceeding the available balance. The test must verify that both the sender's and receiver's balances remain unchanged after a failed transfer (no partial execution).

  ```typescript
  describe("insufficient balance tests", () => {
    it("should reject transfer exceeding balance", async () => {
      await contract.mint(senderPk, 100n);
      await expect(contract.transfer(recipientPk, 150n)).rejects.toThrow(
        "Insufficient balance",
      );

      // Verify balances unchanged after failed transfer
      expect(await contract.getBalance(senderPk)).toBe(100n);
      expect(await contract.getBalance(recipientPk)).toBe(0n);
    });

    it("should reject withdrawal exceeding balance", async () => {
      await contract.deposit(50n);
      await expect(contract.withdraw(51n)).rejects.toThrow(
        "Insufficient balance",
      );

      // Verify balance unchanged
      expect(await contract.getBalance(senderPk)).toBe(50n);
    });

    it("should reject burn exceeding supply", async () => {
      await contract.mint(holderPk, 100n);
      await expect(contract.burn(holderPk, 101n)).rejects.toThrow(
        "Insufficient balance",
      );
    });
  });
  ```

- [ ] **Already-used nullifiers tested: replay attack attempt.** Nullifiers are the primary mechanism for preventing double-spending and double-voting in privacy-preserving contracts. A test must verify that submitting a transaction with an already-used nullifier is rejected. This tests both the nullifier computation determinism and the on-chain set membership check.

  ```typescript
  describe("nullifier replay tests", () => {
    it("should reject replayed vote nullifier", async () => {
      // First vote succeeds
      await contract.vote(proposalId, 1n, voterSecretKey);

      // Same voter tries to vote again — same secret key produces same nullifier
      await expect(
        contract.vote(proposalId, 0n, voterSecretKey),
      ).rejects.toThrow("Nullifier already used");
    });

    it("should reject replayed withdrawal nullifier", async () => {
      await contract.deposit(commitmentData, 100n);
      await contract.withdraw(proof, nullifier, 100n);

      // Attempt to reuse the same withdrawal proof
      await expect(
        contract.withdraw(proof, nullifier, 100n),
      ).rejects.toThrow("Nullifier already used");
    });

    it("should allow different voters on same proposal", async () => {
      // Different secret keys produce different nullifiers
      await contract.vote(proposalId, 1n, voter1SecretKey);
      await contract.vote(proposalId, 0n, voter2SecretKey);
      // Both votes should succeed — distinct nullifiers
      const tally = await contract.getTally(proposalId);
      expect(tally.total).toBe(2n);
    });
  });
  ```

- [ ] **Wrong type/format inputs tested.** While the Compact type system enforces types within circuits, the TypeScript test layer can pass malformed data to witness functions. Tests should verify that the witness layer or proof generation rejects inputs with wrong sizes (e.g., 16-byte value for a `Bytes<32>` parameter), wrong types, or invalid encodings.

  ```typescript
  describe("wrong input format tests", () => {
    it("should reject short byte array for Bytes<32> parameter", async () => {
      const shortKey = new Uint8Array(16); // 16 bytes instead of 32
      await expect(contract.register(shortKey)).rejects.toThrow();
    });

    it("should reject negative amount encoded as bigint", async () => {
      // Compact Uint<64> is unsigned — negative values should be rejected
      // at the witness or proof generation layer
      await expect(contract.deposit(-1n)).rejects.toThrow();
    });

    it("should reject oversized byte array", async () => {
      const longKey = new Uint8Array(64); // 64 bytes instead of 32
      await expect(contract.register(longKey)).rejects.toThrow();
    });
  });
  ```

## Private State Testing Checklist

Check that tests verify the correctness of private (witness-side) state across circuit invocations.

- [ ] **Private state correctly initialized.** The initial private state passed to the witness context must be verified in tests. If the initial state is wrong (missing fields, wrong types, incorrect defaults), all subsequent witness calls operate on a broken foundation. Test that the private state initializer creates the expected structure.

  ```typescript
  describe("private state initialization", () => {
    it("should initialize private state with all required fields", () => {
      const initialState = createInitialPrivateState(secretKey);

      expect(initialState.secretKey).toEqual(secretKey);
      expect(initialState.nonce).toBe(0n);
      expect(initialState.balances).toBeInstanceOf(Map);
      expect(initialState.balances.size).toBe(0);
      expect(initialState.commitments).toEqual([]);
    });

    it("should create distinct private state per secret key", () => {
      const state1 = createInitialPrivateState(key1);
      const state2 = createInitialPrivateState(key2);

      expect(state1.secretKey).not.toEqual(state2.secretKey);
    });
  });
  ```

- [ ] **Private state correctly updated after each circuit call.** After a circuit invocation that modifies private state (through a witness returning updated state), the test must verify that the private state reflects the expected changes. This typically means inspecting the witness context after the transaction.

  ```typescript
  describe("private state updates", () => {
    it("should update private balance after deposit", async () => {
      const initialState = createInitialPrivateState(secretKey);
      const witnessContext = createWitnessContext(initialState);

      await contract.deposit(100n, { witnessContext });

      // Verify private state was updated
      const updatedState = witnessContext.getPrivateState();
      expect(updatedState.balances.get(accountHex)).toBe(100n);
    });

    it("should increment nonce after each operation", async () => {
      const initialState = createInitialPrivateState(secretKey);
      const witnessContext = createWitnessContext(initialState);

      await contract.deposit(50n, { witnessContext });
      expect(witnessContext.getPrivateState().nonce).toBe(1n);

      await contract.deposit(50n, { witnessContext });
      expect(witnessContext.getPrivateState().nonce).toBe(2n);
    });
  });
  ```

- [ ] **Private state immutability verified: spread operator creates new object.** Tests should verify that witness functions do not mutate the input private state. The easiest approach is to capture the state before a circuit call and compare it after the call to confirm the original reference was not modified. This catches the common bug of mutating `privateState` in place instead of returning a new object via spread.

  ```typescript
  describe("private state immutability", () => {
    it("should not mutate the original private state object", async () => {
      const originalState = createInitialPrivateState(secretKey);
      const originalBalances = new Map(originalState.balances);
      const originalNonce = originalState.nonce;

      // Capture a reference to the original object
      const stateRef = originalState;

      const witnessContext = createWitnessContext(originalState);
      await contract.deposit(100n, { witnessContext });

      // The original state reference should be unchanged
      expect(stateRef.nonce).toBe(originalNonce);
      expect(stateRef.balances).toEqual(originalBalances);

      // The updated state should be a different object
      const newState = witnessContext.getPrivateState();
      expect(newState).not.toBe(stateRef);
    });

    it("should not share nested object references between old and new state", async () => {
      const originalState = createInitialPrivateState(secretKey);
      originalState.balances.set("account1", 50n);
      const originalBalancesRef = originalState.balances;

      const witnessContext = createWitnessContext(originalState);
      await contract.deposit(100n, { witnessContext });

      const newState = witnessContext.getPrivateState();
      // Nested Map should be a new instance
      expect(newState.balances).not.toBe(originalBalancesRef);
      // Original Map should be unchanged
      expect(originalBalancesRef.get("account1")).toBe(50n);
    });
  });
  ```

- [ ] **Private state persistence verified: state carries between circuit calls.** Private state is passed through a chain of witness calls. A test must verify that state changes from one circuit call are visible to the next. This confirms that the witness context properly threads state through sequential operations.

  ```typescript
  describe("private state persistence across calls", () => {
    it("should carry deposit state into withdrawal", async () => {
      const witnessContext = createWitnessContext(
        createInitialPrivateState(secretKey),
      );

      // First operation: deposit
      await contract.deposit(200n, { witnessContext });
      expect(witnessContext.getPrivateState().balances.get(accountHex)).toBe(
        200n,
      );

      // Second operation: withdraw — should see the deposited balance
      await contract.withdraw(75n, { witnessContext });
      expect(witnessContext.getPrivateState().balances.get(accountHex)).toBe(
        125n,
      );
    });

    it("should persist commitment list across multiple commits", async () => {
      const witnessContext = createWitnessContext(
        createInitialPrivateState(secretKey),
      );

      await contract.commit(value1, { witnessContext });
      expect(
        witnessContext.getPrivateState().commitments.length,
      ).toBe(1);

      await contract.commit(value2, { witnessContext });
      expect(
        witnessContext.getPrivateState().commitments.length,
      ).toBe(2);

      // Both commitments should be present
      const commitments = witnessContext.getPrivateState().commitments;
      expect(commitments[0]).toBeDefined();
      expect(commitments[1]).toBeDefined();
    });
  });
  ```

## Witness Mock Correctness Checklist

Check that witness mocks in tests accurately represent the runtime witness behavior and use correct types and return shapes.

- [ ] **Witness mocks return `[PrivateState, ReturnValue]` tuple, not just the return value.** This is the most common witness mock bug. The runtime expects every witness to return a two-element tuple where the first element is the (potentially updated) private state and the second is the value. A mock that returns only the value will cause the test to pass but the actual runtime to fail, or vice versa.

  ```typescript
  // BAD — mock returns only the value (not a tuple)
  const mockWitnesses = {
    local_secret_key: (
      { privateState }: WitnessContext<Ledger, MyState>,
    ): Uint8Array => {
      return privateState.secretKey; // WRONG: runtime expects [MyState, Uint8Array]
    },
  };

  // GOOD — mock returns the correct tuple
  const mockWitnesses = {
    local_secret_key: (
      { privateState }: WitnessContext<Ledger, MyState>,
    ): [MyState, Uint8Array] => {
      return [privateState, privateState.secretKey];
    },
  };
  ```

- [ ] **Witness mocks handle `WitnessContext` correctly.** Mock witness functions must accept `WitnessContext<Ledger, PrivateState>` as their first parameter, just like production witnesses. A mock that skips the context parameter or destructures it incorrectly will receive arguments in the wrong positions, causing silent data corruption in tests.

  ```typescript
  // BAD — mock skips WitnessContext; receives context object as 'amount'
  const mockWitnesses = {
    get_balance: (amount: bigint): [MyState, bigint] => {
      // 'amount' is actually the WitnessContext object — silently wrong
      return [defaultState, 0n];
    },
  };

  // GOOD — mock correctly accepts WitnessContext as first parameter
  const mockWitnesses = {
    get_balance: (
      { privateState }: WitnessContext<Ledger, MyState>,
      account: Uint8Array,
    ): [MyState, bigint] => {
      const balance = privateState.balances.get(toHex(account)) ?? 0n;
      return [privateState, balance];
    },
  };
  ```

- [ ] **Mock type mappings match the Compact-to-TypeScript type table.** Mock witness functions must use the same TypeScript types as the production witnesses. A mock that uses `number` instead of `bigint` for `Field`/`Uint<N>`, or `string` instead of `Uint8Array` for `Bytes<N>`, may pass tests but masks type errors that will fail at runtime.

  | Compact Type | Correct Mock Type | Common Mock Mistake |
  |---|---|---|
  | `Field` | `bigint` | `number` (loses precision) |
  | `Uint<N>` | `bigint` | `number` |
  | `Bytes<N>` | `Uint8Array` | `string` or `Buffer` |
  | `Boolean` | `boolean` | `number` (0/1) |
  | `Maybe<T>` | `{ is_some: boolean; value: T }` | `T \| null` |
  | `Either<L, R>` | `{ tag: "left"; value: L } \| { tag: "right"; value: R }` | `L \| R` |
  | Enum | `bigint` (variant index) | `string` (variant name) |

  ```typescript
  // BAD — mock uses number and string instead of correct types
  const mockWitnesses = {
    get_record: (
      { privateState }: WitnessContext<Ledger, MyState>,
      id: string, // WRONG: should be Uint8Array for Bytes<32>
    ): [MyState, number] => { // WRONG: should be bigint for Uint<64>
      return [privateState, 42]; // number, not bigint
    },
  };

  // GOOD — mock uses correct type mappings
  const mockWitnesses = {
    get_record: (
      { privateState }: WitnessContext<Ledger, MyState>,
      id: Uint8Array, // Correct: Bytes<32> → Uint8Array
    ): [MyState, bigint] => { // Correct: Uint<64> → bigint
      return [privateState, 42n]; // bigint
    },
  };
  ```

- [ ] **`Maybe<T>` mocked as `{ is_some: boolean; value: T }`, not `null` or `undefined`.** The Compact `Maybe<T>` type is represented in TypeScript as a tagged object with explicit `is_some` and `value` fields. Mocks that use JavaScript `null`/`undefined` for absent values will silently produce incorrect proof inputs. When `is_some` is `false`, the `value` field must still be present with a zero/default value of the correct type.

  ```typescript
  // BAD — using null for Maybe<Uint<64>> when value is absent
  const mockWitnesses = {
    find_balance: (
      { privateState }: WitnessContext<Ledger, MyState>,
      account: Uint8Array,
    ): [MyState, bigint | null] => {
      const balance = privateState.balances.get(toHex(account));
      return [privateState, balance ?? null]; // WRONG: runtime expects tagged object
    },
  };

  // GOOD — using tagged object for Maybe<Uint<64>>
  const mockWitnesses = {
    find_balance: (
      { privateState }: WitnessContext<Ledger, MyState>,
      account: Uint8Array,
    ): [MyState, { is_some: boolean; value: bigint }] => {
      const balance = privateState.balances.get(toHex(account));
      if (balance !== undefined) {
        return [privateState, { is_some: true, value: balance }];
      }
      return [privateState, { is_some: false, value: 0n }];
    },
  };
  ```

- [ ] **`Either<L, R>` mocked with tagged union, not bare union.** The Compact `Either<L, R>` type maps to a discriminated union using a `tag` field. Mocks that return `L | R` without the tag field produce incorrect proof inputs because the runtime cannot determine which variant is active.

  ```typescript
  // BAD — bare union with no tag
  const mockWitnesses = {
    classify: (
      { privateState }: WitnessContext<Ledger, MyState>,
      data: Uint8Array,
    ): [MyState, bigint | boolean] => {
      return [privateState, isNumeric(data) ? toBigInt(data) : false];
    },
  };

  // GOOD — tagged discriminated union
  const mockWitnesses = {
    classify: (
      { privateState }: WitnessContext<Ledger, MyState>,
      data: Uint8Array,
    ): [MyState, { tag: "left"; value: bigint } | { tag: "right"; value: boolean }] => {
      if (isNumeric(data)) {
        return [privateState, { tag: "left", value: toBigInt(data) }];
      }
      return [privateState, { tag: "right", value: false }];
    },
  };
  ```

## Integration Test Patterns Checklist

Check that the test suite covers multi-step workflows, concurrent user scenarios, and state consistency across operations.

- [ ] **Multi-step flows tested end-to-end.** Contracts with multi-phase protocols (commit-reveal, mint-transfer-burn, propose-vote-execute) must have integration tests that walk through the entire flow in sequence. Each step must verify both ledger state and private state at each transition point. Testing individual steps in isolation misses bugs that only appear when the full sequence runs.

  ```typescript
  describe("commit-reveal end-to-end flow", () => {
    it("should complete full commit → reveal cycle", async () => {
      const secretValue = 42n;
      const salt = crypto.getRandomValues(new Uint8Array(32));
      const witnessContext = createWitnessContext(
        createInitialPrivateState(secretKey),
      );

      // Step 1: Commit
      const commitTx = await contract.commit(secretValue, salt, {
        witnessContext,
      });
      expect(commitTx.public.state).toBe(State.COMMITTED);
      expect(commitTx.public.commitment).toBeDefined();
      const storedCommitment = commitTx.public.commitment;

      // Step 2: Reveal
      const revealTx = await contract.reveal(secretValue, salt, {
        witnessContext,
      });
      expect(revealTx.public.state).toBe(State.REVEALED);
      expect(revealTx.public.revealedValue).toBe(secretValue);
    });
  });

  describe("token lifecycle end-to-end flow", () => {
    it("should complete full mint → transfer → burn cycle", async () => {
      // Step 1: Mint
      await contract.mint(alicePk, 1000n);
      expect(await contract.getBalance(alicePk)).toBe(1000n);
      expect(await contract.getTotalSupply()).toBe(1000n);

      // Step 2: Transfer
      await contract.transfer(alicePk, bobPk, 400n);
      expect(await contract.getBalance(alicePk)).toBe(600n);
      expect(await contract.getBalance(bobPk)).toBe(400n);
      expect(await contract.getTotalSupply()).toBe(1000n); // Supply unchanged

      // Step 3: Burn
      await contract.burn(bobPk, 100n);
      expect(await contract.getBalance(bobPk)).toBe(300n);
      expect(await contract.getTotalSupply()).toBe(900n); // Supply decreased
    });
  });
  ```

- [ ] **Concurrent user scenarios tested.** When two or more users interact with the same contract, contention and ordering issues can emerge. Tests should simulate two users acting on shared state — both depositing, one transferring while another withdraws, or two users voting on the same proposal. These tests catch concurrency bugs that single-user tests miss.

  ```typescript
  describe("concurrent user scenarios", () => {
    it("should handle two users depositing to same contract", async () => {
      const aliceContext = createWitnessContext(
        createInitialPrivateState(aliceSecretKey),
      );
      const bobContext = createWitnessContext(
        createInitialPrivateState(bobSecretKey),
      );

      await contract.deposit(100n, { witnessContext: aliceContext });
      await contract.deposit(200n, { witnessContext: bobContext });

      // Both deposits reflected in contract state
      expect(await contract.getTotalDeposited()).toBe(300n);
    });

    it("should handle concurrent voting on same proposal", async () => {
      await contract.propose(proposalData);

      const voter1Context = createWitnessContext(
        createInitialPrivateState(voter1Key),
      );
      const voter2Context = createWitnessContext(
        createInitialPrivateState(voter2Key),
      );

      // Both voters submit votes
      await contract.vote(proposalId, 1n, { witnessContext: voter1Context });
      await contract.vote(proposalId, 0n, { witnessContext: voter2Context });

      const tally = await contract.getTally(proposalId);
      expect(tally.yesVotes).toBe(1n);
      expect(tally.noVotes).toBe(1n);
      expect(tally.totalVotes).toBe(2n);
    });

    it("should handle transfer between two users", async () => {
      await contract.mint(alicePk, 500n);

      const aliceContext = createWitnessContext(
        createInitialPrivateState(aliceSecretKey),
      );

      await contract.transfer(bobPk, 200n, { witnessContext: aliceContext });

      expect(await contract.getBalance(alicePk)).toBe(300n);
      expect(await contract.getBalance(bobPk)).toBe(200n);
    });
  });
  ```

- [ ] **State consistency verified after multiple operations.** After a sequence of operations, the test must verify that the contract's state is internally consistent. This means checking invariants such as: total supply equals sum of all balances, counter matches number of operations performed, all merkle tree insertions are reflected in the root. These invariant checks catch subtle state corruption bugs.

  ```typescript
  describe("state consistency after multiple operations", () => {
    it("should maintain supply invariant after mixed operations", async () => {
      // Perform a series of operations
      await contract.mint(alicePk, 1000n);
      await contract.mint(bobPk, 500n);
      await contract.transfer(alicePk, bobPk, 200n);
      await contract.burn(alicePk, 100n);
      await contract.transfer(bobPk, alicePk, 50n);

      // Verify invariant: total supply == sum of all balances
      const totalSupply = await contract.getTotalSupply();
      const aliceBalance = await contract.getBalance(alicePk);
      const bobBalance = await contract.getBalance(bobPk);
      expect(aliceBalance + bobBalance).toBe(totalSupply);
      expect(totalSupply).toBe(1400n); // 1000 + 500 - 100 = 1400
    });

    it("should maintain correct vote count after multiple votes", async () => {
      await contract.propose(proposalData);
      const voterKeys = [voter1Key, voter2Key, voter3Key, voter4Key, voter5Key];

      for (const key of voterKeys) {
        const ctx = createWitnessContext(createInitialPrivateState(key));
        await contract.vote(proposalId, 1n, { witnessContext: ctx });
      }

      const tally = await contract.getTally(proposalId);
      expect(tally.totalVotes).toBe(BigInt(voterKeys.length));
    });

    it("should maintain merkle tree consistency after multiple inserts", async () => {
      const leaves: Uint8Array[] = [];
      for (let i = 0; i < 10; i++) {
        const leaf = generateLeaf(i);
        leaves.push(leaf);
        await contract.addMember(leaf);
      }

      // Verify all inserted leaves are valid members
      for (const leaf of leaves) {
        const isMember = await contract.verifyMembership(leaf);
        expect(isMember).toBe(true);
      }

      // Verify a non-inserted leaf is not a member
      const nonMember = generateLeaf(999);
      const isMember = await contract.verifyMembership(nonMember);
      expect(isMember).toBe(false);
    });
  });
  ```

## Anti-Patterns Table

Quick reference of common testing anti-patterns in Compact contract test suites.

| Anti-Pattern | Why It's Wrong | Correct Approach |
|---|---|---|
| Exported circuit with no test | Untested code is unverified code; bugs only discovered in production when real funds are at risk | Write at least one happy-path test and one failure-path test per exported circuit |
| Test calls circuit but asserts nothing | Only verifies the call does not throw; does not verify correctness of state changes, return values, or side effects | Assert all expected outcomes: ledger state, return values, private state changes |
| No zero-value tests | Zero amounts can bypass arithmetic checks, cause no-op transactions, or collide with uninitialized storage | Explicitly test zero for every numeric parameter and empty/zero for every bytes parameter |
| No maximum-value tests | Arithmetic overflow wraps silently in ZK circuits; untested max values hide overflow vulnerabilities | Test at `MAX_UINT64`, `MAX_UINT128`, and contract-defined limits |
| No unauthorized-caller tests | Access control bugs are invisible without negative tests; the circuit may accept anyone | Test every privileged circuit with a non-authorized witness context |
| No out-of-order state transition tests | State machine guards may be missing or incorrect; protocol can be subverted by calling phases out of sequence | Test every invalid phase transition (reveal before commit, execute before vote, etc.) |
| Witness mock returns only the value | Production witnesses return `[PrivateState, Value]` tuples; a mock returning just the value silently passes tests but the real witness behaves differently | Every mock witness must return `[privateState, returnValue]` |
| Mock uses `null` for `Maybe<T>` | Runtime expects `{ is_some: boolean; value: T }` tagged object; `null`/`undefined` causes proof generation failure | Mock with `{ is_some: false, value: defaultValue }` for absent values |
| Mock uses `number` for `Field`/`Uint<N>` | `number` loses precision above 2^53; tests pass with small values but production values overflow | Always use `bigint` in mocks for `Field` and `Uint<N>` types |
| No integration tests for multi-step flows | Individual circuit tests pass but full workflows fail due to state threading, ordering, or intermediate state corruption | Test complete flows end-to-end: commit-reveal, mint-transfer-burn, propose-vote-execute |
| No concurrent user tests | Single-user tests miss contention, ordering, and shared-state bugs that emerge when multiple users interact simultaneously | Test two or more users acting on the same contract in sequence |
| No state invariant checks | Subtle corruption (supply != sum of balances, counter drift) accumulates across operations and goes undetected | After multi-operation sequences, verify contract invariants hold |
