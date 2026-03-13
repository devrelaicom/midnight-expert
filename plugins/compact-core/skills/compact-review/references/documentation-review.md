# Documentation Review Checklist

Review checklist for the **Documentation** category. This covers contract-level documentation, circuit documentation, ledger state documentation, witness documentation, and privacy documentation. Well-documented contracts are easier to audit, maintain, and integrate with. Poor documentation hides intent, makes review harder, and increases the chance that bugs go unnoticed because reviewers cannot tell what the code is supposed to do. Apply every item below to the contract under review.

## Required MCP Tools

Run these tools before starting your review. Reference their output when evaluating checklist items.

| Tool | Label | Purpose |
|------|-------|---------|
| `midnight-compile-contract` | `[shared]` | Compilation output reveals contract structure for documentation completeness analysis |
| `midnight-extract-contract-structure` | `[shared]` | Lists all exported circuits, ledger variables, witnesses — the definitive inventory for documentation coverage |
| `midnight-analyze-contract` | `[shared]` | Static analysis of contract patterns and structure |
| `midnight-get-latest-syntax` | `[shared]` | Authoritative reference for verifying documentation accuracy |

Tools marked `[shared]` are pre-run by the orchestrator — their output is in your prompt.

## Contract-Level Documentation Checklist

Check that the contract file includes top-level documentation explaining its purpose, design, deployment requirements, and dependencies.

- [ ] **Contract purpose is clearly stated at the top of the file.** The first comment in the contract should explain what the contract does in one to three sentences. A reviewer opening the file for the first time should immediately understand the contract's role. Without this, the reviewer must reverse-engineer intent from the code, which is error-prone and time-consuming.

  ```compact
  // BAD — no top-level documentation; reviewer has no context
  export ledger authority: Bytes<32>;
  export ledger members: HistoricMerkleTree<16, Bytes<32>>;
  export ledger usedNullifiers: Set<Bytes<32>>;

  witness localSecretKey(): Bytes<32>;

  export circuit register(commitment: Bytes<32>): [] {
    // ...
  }

  // GOOD — purpose stated clearly at the top
  // Anonymous voting contract for community governance proposals.
  // Members register by inserting a commitment into a Merkle tree.
  // Votes are cast anonymously using zero-knowledge membership proofs
  // with nullifiers to prevent double-voting.

  export ledger authority: Bytes<32>;
  export ledger members: HistoricMerkleTree<16, Bytes<32>>;
  export ledger usedNullifiers: Set<Bytes<32>>;

  witness localSecretKey(): Bytes<32>;

  export circuit register(commitment: Bytes<32>): [] {
    // ...
  }
  ```

- [ ] **Overall architecture and design are explained.** For contracts with multiple modules, state machines, or multi-phase protocols (e.g., commit-reveal, propose-vote-execute), a brief architectural overview should describe how the pieces fit together. This helps reviewers understand the intended flow before diving into individual circuits.

  ```compact
  // BAD — multi-phase protocol with no architectural explanation
  enum State { Setup, Commit, Reveal, Finalized }
  export ledger state: State;
  export ledger commitments: Map<Bytes<32>, Bytes<32>>;
  export ledger reveals: Map<Bytes<32>, Field>;

  // GOOD — architecture documented before the code
  // Commit-Reveal Auction Contract
  //
  // Architecture:
  //   Phase 1 (Setup): Owner deploys and sets auction parameters.
  //   Phase 2 (Commit): Bidders submit blinded commitments of their bids.
  //   Phase 3 (Reveal): Bidders reveal their bids; contract verifies against commitments.
  //   Phase 4 (Finalized): Highest bidder wins; funds are distributed.
  //
  // State transitions: Setup -> Commit -> Reveal -> Finalized
  // Only the owner can advance phases via advancePhase().

  enum State { Setup, Commit, Reveal, Finalized }
  export ledger state: State;
  export ledger commitments: Map<Bytes<32>, Bytes<32>>;
  export ledger reveals: Map<Bytes<32>, Field>;
  ```

- [ ] **Deployment requirements are documented.** The constructor parameters, their expected values, and any deployment preconditions should be documented near the constructor. A deployer reading the contract should know exactly what values to provide and in what format.

  ```compact
  // BAD — constructor with no documentation; deployer must guess parameter meanings
  constructor(key: Bytes<32>, depth: Field, threshold: Field) {
    authority = key;
    voteThreshold = threshold;
  }

  // GOOD — constructor parameters documented
  // Constructor Parameters:
  //   key: The public key of the contract administrator. Derived from
  //        persistentHash<Vector<2, Bytes<32>>>([pad(32, "myapp:pk:"), secretKey]).
  //   depth: Unused in current version; reserved for future MerkleTree sizing.
  //   threshold: Minimum number of votes required to pass a proposal.
  constructor(key: Bytes<32>, depth: Field, threshold: Field) {
    authority = key;
    voteThreshold = threshold;
  }
  ```

- [ ] **Dependencies are documented.** If the contract imports modules, uses cross-contract calls, or depends on external contracts or off-chain services, these dependencies should be listed. A reviewer needs to know the trust boundaries.

  ```compact
  // BAD — imports with no explanation of what they provide
  import TokenModule prefix $;
  import GovernanceModule prefix #;

  // GOOD — imports documented with their purpose
  // Dependencies:
  //   TokenModule: Provides token minting and transfer logic.
  //     Imported with prefix $ (e.g., $mint, $transfer).
  //   GovernanceModule: Provides proposal creation and voting logic.
  //     Imported with prefix # (e.g., #propose, #vote).
  import TokenModule prefix $;
  import GovernanceModule prefix #;
  ```

## Circuit Documentation Checklist

Check that every exported circuit and complex internal circuit has documentation explaining its purpose, parameters, return value, side effects, access control, and requirements.

- [ ] **Every exported circuit has a comment explaining its purpose.** An `export circuit` is part of the contract's public API. Anyone interacting with the contract needs to understand what each circuit does. The comment should describe the high-level action, not repeat the code line-by-line.

  > **Tool:** `midnight-extract-contract-structure` lists all exported circuits. Use this as your definitive checklist — every exported circuit must have documentation.

  ```compact
  // BAD — no documentation on exported circuit
  export circuit transfer(to: Bytes<32>, amount: Field): [] {
    const sk = localSecretKey();
    const pk = disclose(publicKey(sk));
    assert(balances.member(pk), "Sender not found");
    const senderBalance = balances.lookup(pk);
    assert(senderBalance >= amount, "Insufficient balance");
    balances.insert(pk, senderBalance - amount);
    const toBalance = balances.member(to) ? balances.lookup(to) : 0;
    balances.insert(to, toBalance + amount);
  }

  // GOOD — purpose, params, side effects, access control documented
  // Transfers tokens from the caller's account to a recipient.
  //
  // Parameters:
  //   to: Public key of the recipient account.
  //   amount: Number of tokens to transfer. Must be > 0.
  //
  // Side effects:
  //   - Decrements sender's balance in the balances map.
  //   - Increments (or creates) recipient's balance in the balances map.
  //
  // Access control: Caller must possess the secret key corresponding
  //   to a registered public key in the balances map.
  //
  // Requirements:
  //   - Sender must exist in the balances map.
  //   - Sender balance must be >= amount.
  export circuit transfer(to: Bytes<32>, amount: Field): [] {
    const sk = localSecretKey();
    const pk = disclose(publicKey(sk));
    assert(balances.member(pk), "Sender not found");
    const senderBalance = balances.lookup(pk);
    assert(senderBalance >= amount, "Insufficient balance");
    balances.insert(pk, senderBalance - amount);
    const toBalance = balances.member(to) ? balances.lookup(to) : 0;
    balances.insert(to, toBalance + amount);
  }
  ```

- [ ] **Circuit parameters are documented with their meaning and constraints.** Each parameter should have a brief description explaining what it represents, its expected format, and any constraints. This is especially important for `Bytes<32>` parameters where the semantic meaning (public key, commitment, nullifier, hash) is not obvious from the type alone.

  ```compact
  // BAD — parameter types convey no semantic meaning
  export circuit act(
    path: MerkleTreePath<16, Bytes<32>>,
    data: Bytes<32>,
    value: Field
  ): [] {
    // ...
  }

  // GOOD — parameters documented with semantic meaning
  // Parameters:
  //   path: Merkle proof of membership in the members tree.
  //   data: The member's secret key, used to derive nullifier.
  //   value: The vote choice (0 = no, 1 = yes).
  export circuit act(
    path: MerkleTreePath<16, Bytes<32>>,
    data: Bytes<32>,
    value: Field
  ): [] {
    // ...
  }
  ```

- [ ] **Return value is documented with its meaning.** If an exported circuit returns a value, the documentation should explain what the return value represents and how callers should interpret it. This is critical for circuits that return computed results rather than simple confirmations.

  ```compact
  // BAD — return value undocumented; caller does not know what Field means
  export circuit getVoteResult(proposalId: Field): Field {
    // ...
    return disclose(result);
  }

  // GOOD — return value explained
  // Returns the total vote count for the given proposal.
  // The returned Field represents the number of "yes" votes cast.
  // Returns 0 if the proposal does not exist.
  export circuit getVoteResult(proposalId: Field): Field {
    // ...
    return disclose(result);
  }
  ```

- [ ] **Side effects are documented: which ledger state is modified.** Every ledger write (map insert, set insert, counter increment, MerkleTree insert, sealed or direct field assignment) should be mentioned in the circuit documentation. A reviewer should be able to determine the full state impact of a circuit without reading the implementation.

  ```compact
  // BAD — circuit modifies three ledger variables but docs do not mention it
  export circuit register(commitment: Bytes<32>): [] {
    members.insert(disclose(commitment));
    memberCount.increment(1);
    lastRegistration = disclose(commitment);
  }

  // GOOD — all ledger modifications listed
  // Registers a new member by inserting their commitment.
  //
  // Side effects:
  //   - Inserts commitment into the members MerkleTree.
  //   - Increments memberCount by 1.
  //   - Updates lastRegistration to the new commitment.
  export circuit register(commitment: Bytes<32>): [] {
    members.insert(disclose(commitment));
    memberCount.increment(1);
    lastRegistration = disclose(commitment);
  }
  ```

- [ ] **Access control is documented: who can call this circuit.** If the circuit includes authorization checks (public key verification, role checks, state guards), the documentation should state who is allowed to call it. If there is no access control, that should also be explicitly stated so a reviewer can determine whether this is intentional.

  ```compact
  // BAD — circuit has access control but it is not documented
  export circuit mint(amount: Field): [] {
    const sk = localSecretKey();
    const pk = disclose(publicKey(sk));
    assert(authority == pk, "Not authorized");
    token.mint(amount);
  }

  // GOOD — access control clearly stated
  // Mints new tokens. Only the contract authority can call this circuit.
  // Access control: Caller must possess the secret key for the authority public key.
  export circuit mint(amount: Field): [] {
    const sk = localSecretKey();
    const pk = disclose(publicKey(sk));
    assert(authority == pk, "Not authorized");
    token.mint(amount);
  }
  ```

- [ ] **Requirements and assertions are documented: what must hold for the circuit to succeed.** List the preconditions that must be true for the circuit to execute successfully. This includes state machine guards, balance requirements, membership checks, and any other assertions. A caller should know in advance what conditions will cause the transaction to fail.

  ```compact
  // BAD — multiple assertions with no summary of requirements
  export circuit reveal(value: Field, salt: Bytes<32>): [] {
    assert(state == State.Committed, "Wrong state");
    assert(commitments.member(callerPk), "No commitment");
    const expected = persistentCommit<Field>(value, salt);
    assert(commitments.lookup(callerPk) == disclose(expected), "Mismatch");
    state = State.Revealed;
  }

  // GOOD — requirements listed upfront
  // Reveals a previously committed value.
  //
  // Requirements:
  //   - Contract must be in State.Committed.
  //   - Caller must have a stored commitment in the commitments map.
  //   - The revealed value and salt must match the stored commitment.
  export circuit reveal(value: Field, salt: Bytes<32>): [] {
    assert(state == State.Committed, "Wrong state");
    assert(commitments.member(callerPk), "No commitment");
    const expected = persistentCommit<Field>(value, salt);
    assert(commitments.lookup(callerPk) == disclose(expected), "Mismatch");
    state = State.Revealed;
  }
  ```

- [ ] **Complex internal circuits are also documented.** While exported circuits are the public API, complex internal (non-exported) circuits also benefit from documentation. If an internal circuit performs a non-trivial computation (nullifier derivation, Merkle path verification, multi-step validation), a brief comment explaining its purpose and expected inputs/outputs helps reviewers understand the code.

  ```compact
  // BAD — complex internal circuit with no documentation
  circuit deriveNullifier(round: Field, sk: Bytes<32>): Bytes<32> {
    return persistentHash<Vector<3, Bytes<32>>>(
      [pad(32, "myapp:vote-nul:"), round as Field as Bytes<32>, sk]
    );
  }

  // GOOD — internal circuit documented
  // Derives a deterministic nullifier for a vote in a given round.
  // The nullifier is unique per (round, secret key) pair and uses
  // domain separation to prevent cross-protocol collisions.
  // Used by both commit() and reveal() to ensure consistent nullifier derivation.
  circuit deriveNullifier(round: Field, sk: Bytes<32>): Bytes<32> {
    return persistentHash<Vector<3, Bytes<32>>>(
      [pad(32, "myapp:vote-nul:"), round as Field as Bytes<32>, sk]
    );
  }
  ```

## Ledger State Documentation Checklist

Check that every ledger variable has documentation explaining its purpose, visibility rationale, invariants, and relationships with other state.

- [ ] **Every ledger variable has a comment explaining its purpose.** Ledger variables are the persistent state of the contract. Each one should have a brief comment explaining what it stores and why. Type alone does not convey purpose: a `Map<Bytes<32>, Field>` could be balances, vote counts, bid amounts, or timestamps. The comment disambiguates.

  > **Tool:** `midnight-extract-contract-structure` lists all ledger variable declarations with their types and visibility modifiers. Use this as your checklist for documentation coverage.

  ```compact
  // BAD — ledger variables with no documentation; purpose unclear
  export ledger authority: Bytes<32>;
  export ledger data: Map<Bytes<32>, Field>;
  export ledger count: Counter;
  export ledger tree: HistoricMerkleTree<16, Bytes<32>>;
  export ledger flags: Set<Bytes<32>>;
  export ledger state: Field;

  // GOOD — every ledger variable documented
  // Public key of the contract administrator; set at deployment, used for authorization.
  export sealed ledger authority: Bytes<32>;

  // Maps member public keys to their token balances.
  export ledger data: Map<Bytes<32>, Field>;

  // Total number of registered members; incremented on each registration.
  export ledger count: Counter;

  // Merkle tree of member commitments; supports anonymous membership proofs.
  export ledger tree: HistoricMerkleTree<16, Bytes<32>>;

  // Set of spent nullifiers; prevents double-voting.
  export ledger flags: Set<Bytes<32>>;

  // Current protocol phase (0 = setup, 1 = active, 2 = finalized).
  export ledger state: Field;
  ```

- [ ] **Visibility rationale is explained: why `export` vs `sealed` vs internal.** Each ledger variable's visibility should be a conscious choice, not an accident. If a variable is `export`, the documentation should explain why external parties need to query it. If it is `sealed`, the documentation should explain why immutability is required. If it is internal (no modifier), the documentation should explain why it does not need external access.

  ```compact
  // BAD — visibility modifiers present but no rationale
  export ledger voteCount: Counter;
  sealed ledger maxVotes: Field;
  ledger internalState: Field;

  // GOOD — visibility rationale documented
  // Total votes cast; exported so the DApp can display the current count.
  export ledger voteCount: Counter;

  // Maximum allowed votes per proposal; sealed because it is a deployment-time
  // configuration that must never change after the contract is live.
  export sealed ledger maxVotes: Field;

  // Internal flag tracking whether the current round has been initialized.
  // Not exported because it is only used for internal state machine logic
  // and should not be part of the public API.
  ledger internalState: Field;
  ```

- [ ] **State invariants are documented: what constraints must always hold.** If ledger variables have constraints that must always be maintained (e.g., a counter must equal the number of entries in a map, a balance must never go negative, a state variable must only increase), these invariants should be documented. Invariants help reviewers verify that every circuit maintains them.

  ```compact
  // BAD — implicit invariant that reviewers might miss
  export ledger memberCount: Counter;
  export ledger members: HistoricMerkleTree<16, Bytes<32>>;
  export ledger usedNullifiers: Set<Bytes<32>>;

  // GOOD — invariants explicitly stated
  // Total registered members. Invariant: memberCount == number of leaves
  // inserted into the members tree.
  export ledger memberCount: Counter;

  // Merkle tree of member commitments. Invariant: every leaf is a unique
  // commitment derived from a distinct secret key.
  export ledger members: HistoricMerkleTree<16, Bytes<32>>;

  // Spent nullifiers. Invariant: each nullifier appears at most once;
  // a nullifier in this set means the corresponding member has already
  // acted in the current round.
  export ledger usedNullifiers: Set<Bytes<32>>;
  ```

- [ ] **Relationships between ledger variables are documented.** When ledger variables are semantically related (e.g., a counter tracks the number of entries in a map, a state enum controls which circuits are callable, a sealed authority controls who can modify other variables), these relationships should be documented. Without this, a reviewer may not realize that modifying one variable requires updating another.

  ```compact
  // BAD — related variables with no documented relationship
  export ledger proposals: Map<Field, Bytes<32>>;
  export ledger proposalCount: Counter;
  export ledger state: State;
  export ledger currentRound: Field;

  // GOOD — relationships between variables documented
  // Active proposals keyed by proposal ID (0-indexed).
  // Related: proposalCount tracks the next available proposal ID.
  export ledger proposals: Map<Field, Bytes<32>>;

  // Next proposal ID to assign. Invariant: proposalCount == number of
  // entries in the proposals map.
  export ledger proposalCount: Counter;

  // Current protocol phase. Controls which circuits are callable:
  //   State.Setup -> only initialize() is callable
  //   State.Active -> propose(), vote() are callable
  //   State.Finalized -> only getResult() is callable
  export ledger state: State;

  // Current voting round. Incremented when the state transitions from
  // Active to Finalized. Used as input to nullifier derivation to ensure
  // nullifiers are unique per round.
  export ledger currentRound: Field;
  ```

- [ ] **Enum types used for ledger state have documented variant meanings.** If a ledger variable uses an enum type, the documentation should explain what each variant represents and when the contract enters that state. This is especially important for state machine contracts where the enum controls the protocol flow.

  ```compact
  // BAD — enum variants with no explanation
  enum Phase { A, B, C, D }

  // GOOD — enum variants documented
  // Protocol phases for the commit-reveal auction.
  //   Setup: Initial phase; owner configures auction parameters.
  //   Commit: Bidders submit blinded bid commitments.
  //   Reveal: Bidders reveal bids; contract verifies against commitments.
  //   Finalized: Auction concluded; winner determined.
  enum Phase { Setup, Commit, Reveal, Finalized }
  ```

## Witness Documentation Checklist

Check that every witness declaration in the Compact contract has documentation explaining what data it provides, its expected behavior, return type semantics, private state requirements, and any preconditions or side effects.

- [ ] **Every witness declaration has a comment explaining what data it provides.** A witness declaration in Compact is a function signature with no body. The implementation lives in TypeScript. Without documentation on the Compact side, a reviewer must switch to the TypeScript file to understand what the witness does. Each witness should have a brief comment explaining what data it supplies and from where.

  > **Tool:** `midnight-extract-contract-structure` lists all witness declarations. Use this to verify every witness has documentation. `midnight-search-docs` can provide context on standard witness patterns and WitnessContext documentation.

  ```compact
  // BAD — witness declarations with no documentation
  witness localSecretKey(): Bytes<32>;
  witness getMerklePath(leaf: Bytes<32>): MerkleTreePath<16, Bytes<32>>;
  witness getBalance(account: Bytes<32>): Uint<64>;

  // GOOD — witness declarations documented
  // Returns the caller's secret key from local private state.
  // Used for authorization (deriving the public key for identity checks).
  witness localSecretKey(): Bytes<32>;

  // Returns a Merkle path proving that the given leaf (commitment) is a
  // member of the members tree. The path is precomputed from the latest
  // tree state stored in private state.
  witness getMerklePath(leaf: Bytes<32>): MerkleTreePath<16, Bytes<32>>;

  // Returns the private token balance for the given account from
  // the caller's local state. Used for off-chain balance verification
  // before on-chain assertions.
  witness getBalance(account: Bytes<32>): Uint<64>;
  ```

- [ ] **Expected behavior and return type semantics are documented.** The return type of a witness (e.g., `Bytes<32>`, `Field`, `MerkleTreePath<16, Bytes<32>>`) does not convey what the value represents. The documentation should explain what a valid return value looks like and what happens if the witness cannot produce one (e.g., throws an error, returns a default).

  ```compact
  // BAD — return type alone does not explain what the Field means
  witness getProposalVotes(proposalId: Field): Field;

  // GOOD — return value semantics explained
  // Returns the number of votes the caller has privately tracked for
  // the given proposal. Returns 0 if the proposal is unknown.
  // The TypeScript implementation should throw an error if the
  // private state is corrupted rather than returning a garbage value.
  witness getProposalVotes(proposalId: Field): Field;
  ```

- [ ] **Private state requirements are documented.** If a witness depends on specific private state being present (e.g., a secret key must have been generated, a Merkle path must have been precomputed, a balance record must exist), these requirements should be documented. This helps the DApp developer ensure the private state is properly initialized before invoking circuits that call the witness.

  ```compact
  // BAD — witness requires precomputed data but does not say so
  witness getMerklePath(commitment: Bytes<32>): MerkleTreePath<16, Bytes<32>>;

  // GOOD — private state prerequisites documented
  // Returns a Merkle path for the given commitment.
  //
  // Private state requirement: The DApp must call prepareMerkleProofs()
  // before invoking any circuit that uses this witness. The Merkle paths
  // are precomputed from the current on-chain tree state and stored in
  // privateState.merkleProofs. If no precomputed path exists for the
  // given commitment, the TypeScript implementation throws an error.
  witness getMerklePath(commitment: Bytes<32>): MerkleTreePath<16, Bytes<32>>;
  ```

- [ ] **Preconditions and side effects are documented.** Some witnesses have preconditions (e.g., must be called after another witness has populated state) or side effects (e.g., updates private state to track that a nonce has been used). These should be documented so reviewers and DApp developers understand the full behavior.

  ```compact
  // BAD — witness has a side effect (stores nonce) but does not document it
  witness generateNonce(): Bytes<32>;

  // GOOD — side effects documented
  // Generates a random nonce for use in commitment schemes.
  //
  // Side effect: The generated nonce is stored in privateState.lastNonce
  // so that it can be retrieved later during the reveal phase without
  // re-generating (which would produce a different value).
  //
  // Precondition: None. Can be called at any time.
  witness generateNonce(): Bytes<32>;
  ```

- [ ] **Witness parameters are documented with their meaning.** Just as circuit parameters need documentation, witness parameters should explain what the caller is passing. This is especially important because the circuit invokes the witness with specific arguments, and the TypeScript implementation must know what to expect.

  ```compact
  // BAD — witness parameter has no documented meaning
  witness lookupRecord(key: Bytes<32>, flag: Boolean): Field;

  // GOOD — witness parameters documented
  // Looks up a record in the caller's private database.
  //
  // Parameters:
  //   key: The record identifier (typically a hash of the record's public fields).
  //   flag: If true, include expired records in the search. If false, only
  //         return active records.
  //
  // Returns the record's value, or throws if not found.
  witness lookupRecord(key: Bytes<32>, flag: Boolean): Field;
  ```

## Privacy Documentation Checklist

Check that the contract includes documentation explaining its privacy model: what is private, what is disclosed, what guarantees are provided, and what limitations exist.

- [ ] **Which data is private and why.** The contract should document which pieces of data remain private (never disclosed, never written to public ledger) and the reason for their privacy. This helps reviewers verify that the implementation matches the privacy intent.

  ```compact
  // BAD — no privacy documentation; reviewer must infer from code
  witness localSecretKey(): Bytes<32>;
  witness getVoteChoice(): Field;

  export circuit vote(path: MerkleTreePath<16, Bytes<32>>): [] {
    const sk = localSecretKey();
    const choice = getVoteChoice();
    // ...
  }

  // GOOD — privacy model documented
  // Privacy Model:
  //   Private data (never disclosed):
  //     - Secret key (sk): The voter's identity. Kept private to ensure
  //       anonymous voting. Only the derived nullifier is disclosed.
  //     - Vote choice: The actual vote (yes/no) remains private.
  //       Only a commitment to the vote is stored on-chain.
  //
  //   This ensures that:
  //     1. No observer can determine which member cast a particular vote.
  //     2. No observer can determine how any member voted.

  witness localSecretKey(): Bytes<32>;
  witness getVoteChoice(): Field;

  export circuit vote(path: MerkleTreePath<16, Bytes<32>>): [] {
    const sk = localSecretKey();
    const choice = getVoteChoice();
    // ...
  }
  ```

- [ ] **Which data is disclosed and why.** Every `disclose()` call and every value written to a public ledger variable should have a documented rationale. The reviewer needs to understand why each piece of data is public so they can assess whether the disclosure is necessary or excessive.

  ```compact
  // BAD — disclosures present but no rationale
  export circuit register(sk: Bytes<32>): [] {
    const pk = disclose(publicKey(sk));
    authority = pk;
    memberCount.increment(1);
  }

  // GOOD — disclosure rationale documented
  // register: Creates the contract authority.
  //
  // Disclosed data:
  //   - pk (derived from sk): The authority's public key must be stored
  //     on the public ledger so that future authorization checks can
  //     compare against it. The secret key remains private; only the
  //     derived public key is disclosed.
  //   - memberCount increment: The count is inherently public (Counter
  //     operations are always visible). This is acceptable because knowing
  //     the total member count does not compromise individual privacy.
  export circuit register(sk: Bytes<32>): [] {
    const pk = disclose(publicKey(sk));
    authority = pk;
    memberCount.increment(1);
  }
  ```

- [ ] **Privacy guarantees the contract provides are explicitly stated.** The contract should document the privacy properties it claims to provide. These are the promises to users. Common guarantees include: voter anonymity, transaction amount confidentiality, membership privacy, and unlinkability between actions.

  ```compact
  // BAD — no stated privacy guarantees; users cannot evaluate the contract's promises
  // (no documentation)

  // GOOD — privacy guarantees explicitly listed
  // Privacy Guarantees:
  //   1. Voter anonymity: An observer cannot determine which registered
  //      member cast any particular vote. Votes use MerkleTree membership
  //      proofs with nullifiers; the observer sees only a valid proof
  //      and an opaque nullifier.
  //   2. Vote confidentiality: Individual vote choices (yes/no) are never
  //      disclosed. Only the aggregate tally is public after finalization.
  //   3. Unlinkability: A voter's registration transaction cannot be linked
  //      to their voting transaction because different domain-separated
  //      values are used for registration commitments and vote nullifiers.
  ```

- [ ] **Privacy limitations or caveats are documented.** Every privacy system has limitations. The contract should honestly document what is NOT private, what can be inferred by an observer, and what trust assumptions exist. Common caveats include: transaction timing correlation, observable circuit names, visible state change patterns, and counter/set operation visibility.

  ```compact
  // BAD — no mention of privacy limitations; users may have false expectations

  // GOOD — limitations honestly documented
  // Privacy Limitations:
  //   1. Transaction timing: An observer can correlate registration and
  //      voting timing. If only one member registers and then votes
  //      within a short window, anonymity is effectively broken.
  //   2. Circuit name visibility: The name of the called circuit (e.g.,
  //      "vote", "register") is always visible on-chain. An observer
  //      knows WHAT action was taken, just not by whom.
  //   3. Counter visibility: The memberCount and voteCount values are
  //      public. An observer can track participation rates.
  //   4. Set size: The usedNullifiers set size reveals how many unique
  //      voters have participated, even though individual identities
  //      are hidden.
  //   5. Single-voter deanonymization: If the set of registered members
  //      is small (e.g., 2-3 people), the anonymity set is too small
  //      to provide meaningful privacy. This contract is designed for
  //      groups of 10+ members.
  ```

- [ ] **Privacy documentation covers the full data lifecycle.** Privacy analysis should cover data at rest (ledger state), data in motion (circuit parameters, return values, disclosed values), and data derivation (what can be inferred from public state changes over time). A common oversight is documenting what is private within a single transaction but ignoring what can be inferred from observing multiple transactions over time.

  > **Tool:** `midnight-extract-contract-structure` identifies all `disclose()` calls, ledger writes, and data flow patterns. Use this to verify the privacy documentation covers every disclosure point. `midnight-search-docs` has guidance on documenting privacy models.

  ```compact
  // BAD — privacy documented only for individual circuits, not lifecycle

  // GOOD — lifecycle privacy documented
  // Data Lifecycle Privacy Analysis:
  //
  // Registration (register circuit):
  //   - Input: commitment (public) — derived from secret key + nonce
  //   - On-chain: commitment inserted into MerkleTree (leaf value visible on-chain)
  //   - Observable: a new leaf was inserted (tree size increased by 1)
  //
  // Voting (vote circuit):
  //   - Input: Merkle path (private), nullifier (disclosed)
  //   - On-chain: nullifier inserted into usedNullifiers set
  //   - Observable: a new nullifier appeared (one more voter participated)
  //
  // Cross-transaction inference:
  //   - An observer tracking registration timestamps and subsequent vote
  //     timestamps may narrow the anonymity set. Mitigation: users should
  //     wait a random delay between registration and voting.
  //   - If the total number of registrations equals the total number of
  //     votes, all members voted, which is itself information.
  ```

## Anti-Patterns Table

Quick reference of common documentation anti-patterns in Compact contracts.

| Anti-Pattern | Why It's Wrong | Correct Approach |
|---|---|---|
| No top-level comment explaining contract purpose | Reviewer must reverse-engineer intent from code; increases review time and error rate | First comment in file should explain what the contract does in 1-3 sentences |
| Exported circuit with no documentation | Part of the public API with no explanation; callers and reviewers cannot understand intent | Document purpose, parameters, return value, side effects, access control, and requirements |
| Ledger variable with no comment | Type alone (e.g., `Map<Bytes<32>, Field>`) does not convey purpose; could mean balances, scores, timestamps, or anything else | Brief comment explaining what the variable stores and why |
| Missing visibility rationale | Reviewer cannot tell if `export` vs `sealed` vs internal was a conscious choice or an accident | Document why each visibility modifier was chosen |
| Undocumented state invariants | Invariants exist implicitly but reviewers do not know to check them; bugs slip through when a circuit breaks an unstated invariant | Explicitly document constraints like "counter == map size" or "balance >= 0" |
| Witness declaration with no comment | Reviewer must find the TypeScript implementation to understand what the witness provides; slows down review | Document what data the witness provides, from where, and any prerequisites |
| No privacy model documentation | Users cannot evaluate what privacy the contract provides; may have false expectations of confidentiality | Document what is private, what is disclosed, guarantees provided, and limitations |
| Privacy guarantees stated without limitations | Gives users a false sense of security; every privacy system has caveats (timing, set size, observable metadata) | Honestly document both guarantees and limitations |
| Documentation only covers happy path | No mention of what happens when assertions fail, when state is missing, or when preconditions are not met | Document failure modes, error conditions, and edge cases |
| Stale documentation that contradicts the code | Worse than no documentation; misleads reviewers into believing incorrect behavior | Update documentation whenever code changes; review docs as part of code review |

## Tool Reference

| Tool | Description |
|------|-------------|
| `midnight-compile-contract` | Compile contract with hosted compiler. Reveals complete contract structure. |
| `midnight-extract-contract-structure` | Lists all exported circuits, ledger variables, witnesses, and data flow — the definitive inventory for documentation coverage analysis. |
| `midnight-analyze-contract` | Static analysis of contract patterns for architectural documentation. |
| `midnight-get-latest-syntax` | Authoritative Compact syntax reference for verifying technical accuracy of documentation. |
| `midnight-search-docs` | Full-text search across official Midnight documentation for documentation standards and privacy model guidance. |
