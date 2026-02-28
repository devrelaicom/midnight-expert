# compact-privacy-disclosure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a `compact-privacy-disclosure` skill for the compact-core plugin that covers Midnight's privacy model, `disclose()` mechanics, advanced privacy patterns, 6 complete example contracts, and a step-by-step disclosure debugging guide.

**Architecture:** Concept-first structure with SKILL.md entry point, three reference files (disclosure-mechanics, privacy-patterns, debugging-disclosure), and six complete .compact example files. Cross-references existing skills (compact-ledger, compact-structure, compact-standard-library, compact-tokens) for foundations; extends with deep privacy coverage and debugging. All content is researched via the Midnight MCP tools.

**Tech Stack:** Midnight Compact language, Midnight MCP tools (midnight-search-compact, midnight-search-docs, midnight-fetch-docs, midnight-compile-contract), Claude Code plugin system (SKILL.md frontmatter)

---

### Task 1: Scaffold directory structure and update plugin manifest

**Files:**
- Create: `plugins/compact-core/skills/compact-privacy-disclosure/SKILL.md` (empty placeholder)
- Create: `plugins/compact-core/skills/compact-privacy-disclosure/references/` (directory)
- Create: `plugins/compact-core/skills/compact-privacy-disclosure/examples/` (directory)
- Modify: `plugins/compact-core/.claude-plugin/plugin.json`

**Step 1: Create the directory structure**

```bash
mkdir -p plugins/compact-core/skills/compact-privacy-disclosure/references
mkdir -p plugins/compact-core/skills/compact-privacy-disclosure/examples
touch plugins/compact-core/skills/compact-privacy-disclosure/SKILL.md
```

**Step 2: Add privacy keywords to plugin.json**

Read `plugins/compact-core/.claude-plugin/plugin.json` and add these keywords to the existing array:

```json
"privacy",
"disclosure",
"disclose",
"witness-protection",
"commitment",
"nullifier",
"selective-disclosure",
"commit-reveal",
"anonymous-auth",
"merkle-proof"
```

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-privacy-disclosure/ plugins/compact-core/.claude-plugin/plugin.json
git commit -m "feat(compact-core): scaffold compact-privacy-disclosure skill directory structure"
```

---

### Task 2: Write references/disclosure-mechanics.md

**Files:**
- Create: `plugins/compact-core/skills/compact-privacy-disclosure/references/disclosure-mechanics.md`

**Research:** Use these MCP tools before writing:
- `midnight-fetch-docs` with path `/compact/reference/explicit_disclosure` — the authoritative source for disclosure mechanics
- `midnight-search-compact` for `disclose` to find real-world usage patterns
- `midnight-search-docs` for `witness protection program abstract interpreter` to understand compiler internals

**Content structure:**

```markdown
# Disclosure Mechanics

Deep reference for how `disclose()` works in Compact, what the compiler tracks,
where disclosure is required, and how to place it correctly.

## What disclose() Actually Does
```

Cover these sections, drawing from the MCP research and existing skill content:

1. **What disclose() Actually Does** — It is a compiler annotation, not a runtime operation. It tells the Witness Protection Program to treat the wrapped expression's value as if it does not contain witness data. It does not encrypt, hash, or transform the value in any way. Placing `disclose(x)` simply marks `x` as "okay to make public." Include the code example from the official docs:

```compact
// Without disclose — compiler rejects:
balance = getBalance();  // ERROR

// With disclose — compiler accepts:
balance = disclose(getBalance());  // OK: programmer acknowledges public disclosure
```

2. **Sources of Witness Data** — Witness data enters a circuit from three sources:
   - `witness` function return values
   - Exported circuit parameters (from transaction submitter)
   - Constructor parameters
   - Any value derived from the above (arithmetic, field access, circuit calls, casts)

3. **The Witness Protection Program** — The compiler's abstract interpreter. Explain:
   - It tracks which values contain witness data at each point in the program
   - When it encounters an undeclared disclosure point, it halts and reports the full path
   - It follows data through arithmetic, struct construction, circuit calls, type casts, and lambda captures
   - It reports ALL disclosure violations, not just the first one

4. **Exhaustive Disclosure Contexts** — Table format:

| Context | Example | Why Disclosure Occurs |
|---------|---------|----------------------|
| Ledger write (direct) | `owner = disclose(pk)` | Value becomes public on-chain |
| Ledger write (ADT method) | `map.insert(disclose(key), val)` | Arguments to ADT ops are public |
| Conditional (`if`) | `if (disclose(x == y)) { ... }` | Branch choice reveals information |
| Conditional (`assert`) | `assert(disclose(x > 0), "msg")` | Assertion result is observable |
| Return from exported circuit | `return disclose(value)` | Return value leaves the ZK proof |
| Cross-contract call | Calling another contract's circuit | Arguments cross trust boundary |
| Constructor sealed field | `owner = disclose(pk)` in constructor | Sealed values are set publicly |

5. **Where Disclosure Is NOT Required** — Table:

| Context | Example | Why No Disclosure |
|---------|---------|------------------|
| Pure witness computation | `const h = persistentHash(sk)` | Result stays within circuit |
| Internal circuit calls | `helper(witness_val)` | Non-exported, stays in proof |
| Intermediate variables | `const x = a + b` | No public boundary crossed |

6. **Safe Stdlib Routines** — Critical distinction:

| Function | Clears Witness Taint? | Why |
|----------|----------------------|-----|
| `persistentCommit<T>(value, rand)` | **Yes** | Commitment cryptographically hides input |
| `transientCommit<T>(value, rand)` | **Yes** | Same hiding property, different algorithm |
| `persistentHash<T>(value)` | **No** | Hash output could theoretically be brute-forced |
| `transientHash<T>(value)` | **No** | Same reasoning as persistentHash |

Include important nuance: even though commits clear taint, the commitment *result* still needs `disclose()` when written to ledger — the compiler just won't trace the *input* witness through it.

```compact
// Commitment clears witness taint on the INPUT:
const commitment = persistentCommit<Field>(secretValue, randomness);
// But the result still needs disclose when stored:
storedCommitment = disclose(commitment);  // disclose() for ledger write, not for witness tracking
```

7. **Best Practices for Placement** — Where to put disclose():
   - As close to the disclosure point as possible (not at the witness call site)
   - For structured values (structs, vectors), only wrap the witness-containing fields
   - Exception: if a witness always returns non-private data, put disclose() at the call site
   - Never wrap more than necessary — over-disclosure is an anti-pattern

8. **Indirect Disclosure Tracking** — The compiler follows witness data through:
   - Arithmetic: `witness_val + 73` is still witness data
   - Type casts: `witness_val as Bytes<32>` is still witness data
   - Struct construction: `S { x: witness_val }` makes the struct contain witness data
   - Struct field access: `s.x` where `s` contains witness data
   - Circuit calls: passing witness data into a helper circuit
   - Lambda captures: a closure capturing a witness variable

Include the indirect obfuscation example from official docs showing the full error path.

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-privacy-disclosure/references/disclosure-mechanics.md
git commit -m "feat(compact-core): add disclosure-mechanics reference for compact-privacy-disclosure"
```

---

### Task 3: Write references/privacy-patterns.md

**Files:**
- Create: `plugins/compact-core/skills/compact-privacy-disclosure/references/privacy-patterns.md`

**Research:** Use these MCP tools before writing:
- `midnight-search-compact` for `commitment nullifier merkle` — find real contract patterns
- `midnight-search-compact` for `zerocash coin_info derive_nullifier` — zerocash implementation
- `midnight-search-compact` for `election vote commit reveal` — voting patterns
- `midnight-search-docs` for `privacy selective disclosure zero knowledge` — conceptual docs
- `midnight-fetch-docs` with path `/compact/writing` — the lock contract tutorial showing round-based auth

**Content structure:**

```markdown
# Privacy Patterns

Advanced privacy-preserving patterns for Compact smart contracts. For basic
visibility rules per ledger operation, see `compact-ledger/references/privacy-and-visibility.md`.
For basic authentication and commit-reveal snippets, see
`compact-structure/references/patterns.md`. This reference extends those
foundations with deeper mechanics, composition strategies, and threat analysis.
```

Cover these sections:

1. **Commitment Schemes** (~40 lines)
   - `persistentCommit<T>(value, randomness)` vs `persistentHash<T>(value)` — commit has blinding factor, hash does not
   - When to use commit vs hash: commit when you need to reveal later and need hiding; hash when binding is sufficient
   - `transientCommit` vs `persistentCommit` — transient for in-circuit intermediates, persistent for ledger storage
   - Salt/randomness management: use witness functions to provide off-chain randomness, never reuse salts
   - Binding property: a commitment binds the committer to the value — they cannot later open it to a different value
   - Code example showing commit with proper salt management

2. **Nullifier Construction** (~50 lines)
   - Purpose: prevent double-actions without revealing which action is being prevented
   - Derivation pattern: `persistentHash<Vector<N, Bytes<32>>>([pad(32, "domain:"), secret, ...])`
   - Domain separation is critical: nullifiers for different purposes MUST use different domain prefixes
   - Nullifier vs commitment must be uncorrelatable: use different domain separators or derive from different inputs
   - Multi-round nullifiers: incorporate a round counter to allow per-round actions
   - Storage: nullifiers go in `Set<Bytes<32>>` (visible on-chain — this is by design, they're already derived)
   - Code examples from zerocash pattern: separate commitment and nullifier derivation
   - Include the real Midnight pattern from zerocash.compact:
   ```compact
   circuit derive_nullifier(coin: coin_info, sk: zk_secret_key): nullifier {
     return nullifier{ bytes: disclose(persistentHash<Vector<4, Bytes<32>>>([
       pad(32, "lares:zerocash:commit"),
       coin.nonce.bytes,
       coin.opening.bytes,
       sk.bytes
     ]))};
   }
   ```

3. **Merkle Tree Anonymous Authentication** (~50 lines)
   - Why HistoricMerkleTree over MerkleTree: proofs remain valid after new insertions
   - The on-chain/off-chain dance:
     1. Admin inserts commitments into HistoricMerkleTree (leaf values hidden on-chain)
     2. User's witness provides MerkleTreePath from off-chain state
     3. Circuit computes root via `merkleTreePathRoot<N, T>(path)`
     4. Circuit verifies root against tree via `tree.checkRoot(root)`
   - Privacy property: observer sees *that* someone proved membership, but not *which* member
   - Combining with nullifiers: after proving membership, insert a nullifier to prevent reuse
   - Code example showing the full flow
   - Include note: HistoricMerkleTree has capacity 2^N, plan accordingly

4. **Round-Based Unlinkability** (~30 lines)
   - Mechanism: derive public keys incorporating a round counter
   - `publicKey(round, sk) = persistentHash([domain, round_as_bytes, sk])`
   - Each transaction increments the round and updates the authority hash
   - Observer sees different hashes each round — cannot link them to the same user
   - Limitation: the *first* transaction initializes the authority, which is a unique event
   - When to use: single-user actions where you want to break tx-to-tx linkability
   - Reference the lock contract pattern from official docs

5. **Multi-Phase Protocols** (~30 lines)
   - Commit-reveal with multiple participants:
     - Phase 1: all participants submit commitments
     - Phase 2: all participants reveal values
   - Ordering considerations: use state machine (enum) to enforce phase transitions
   - Timeout handling: combine with `blockTimeGte`/`blockTimeLt` for deadlines
   - Concurrent security: each participant needs their own salt/secret — don't share

6. **Selective Disclosure** (~25 lines)
   - Pattern: prove a property (e.g., "balance > threshold") without revealing the value
   - Use `disclose()` on the boolean result of a comparison, not on the value itself
   - Range-like proofs: `assert(disclose(value >= minimum && value <= maximum), "Out of range")`
   - Selective field disclosure: disclose some struct fields but not others
   - Code example

7. **Threat Model: What an On-Chain Observer Can See** (~40 lines)
   - **Always visible:** which exported circuit was called, which contract was called, the number of ledger operations, the timing of transactions, Counter increment amounts, Map/Set operation arguments
   - **Hidden by ZK proofs:** witness values, internal circuit computations, values passed to MerkleTree.insert()
   - **Correlation attacks:**
     - Timing: if only one user is registered, their transactions are trivially identifiable
     - Amount patterns: if amounts are unique, they can fingerprint users
     - Tree size: number of MerkleTree insertions reveals the member count
     - Nullifier timing: when a nullifier appears reveals when the member acted
   - **MerkleTree leaf guessing:** if the set of possible leaves is small, an observer can verify guesses against the tree
   - Mitigation strategies: add dummy operations, use larger anonymity sets, add delays

8. **Anti-Patterns** (~30 lines) — Table format:

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Using `Set` for private membership | Reveals which element is being checked | Use `MerkleTree` + ZK path proof |
| Missing domain separator on nullifiers | Different contracts' nullifiers can be correlated | Always prefix with unique `pad(32, "contract:purpose:")` |
| Disclosing at witness call site | Over-discloses — ALL downstream uses lose privacy | Disclose as close to the disclosure point as possible |
| Same derivation for commitment and nullifier | Linking attack: observer matches commitments to nullifiers | Use different domain separators or different inputs |
| Storing raw secrets in sealed fields | Sealed values are visible on-chain at constructor time | Store hash or commitment of the secret instead |
| Reusing salts across commitments | Breaks hiding — same value+salt = same commitment | Use unique randomness per commitment (witness-provided) |
| Using `Map<address, balance>` for private balances | All transfers visible on-chain | Use shielded tokens (zswap) from compact-tokens |

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-privacy-disclosure/references/privacy-patterns.md
git commit -m "feat(compact-core): add privacy-patterns reference for compact-privacy-disclosure"
```

---

### Task 4: Write references/debugging-disclosure.md

**Files:**
- Create: `plugins/compact-core/skills/compact-privacy-disclosure/references/debugging-disclosure.md`

**Research:** Use these MCP tools before writing:
- `midnight-fetch-docs` with path `/compact/reference/explicit_disclosure` — the full disclosure reference with error message examples
- `midnight-search-docs` for `disclosure error message compiler` — find error reporting details
- `midnight-compile-contract` — compile a few broken examples to get real error messages

To generate real error messages, compile these test contracts with `midnight-compile-contract`:

Test 1 — Direct write without disclose:
```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;
witness getBalance(): Bytes<32>;
export ledger balance: Bytes<32>;
export circuit recordBalance(): [] {
  balance = getBalance();
}
```

Test 2 — Indirect via arithmetic:
```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;
witness getSecret(): Field;
export ledger result: Field;
export circuit compute(): [] {
  const x = getSecret() + 42;
  result = x;
}
```

Test 3 — Conditional on witness:
```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;
witness getFlag(): Boolean;
export ledger value: Field;
export circuit check(): [] {
  if (getFlag()) {
    value = 1;
  }
}
```

Test 4 — Return from exported circuit:
```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;
witness getBalance(): Uint<64>;
export circuit balanceExceeds(n: Uint<64>): Boolean {
  return getBalance() > n;
}
```

**Content structure:**

```markdown
# Debugging Disclosure Errors

Step-by-step guide for understanding and fixing the Compact compiler's
disclosure errors. When the compiler reports "potential witness-value disclosure
must be declared but is not", this guide will help you diagnose the issue and
apply the correct fix.
```

Cover these sections:

1. **Anatomy of a Disclosure Error** (~30 lines)
   - Show a real error message from `midnight-compile-contract`
   - Break it down into three parts:
     - **Witness source:** "witness value potentially disclosed: the return value of witness X at line Y"
     - **Nature of disclosure:** "ledger operation might disclose the witness value" (or "comparison involving", "value returned from exported circuit")
     - **Path through program:** "via this path through the program: ..." — the exact chain from witness to disclosure point
   - The path is the most valuable part — it shows exactly how witness data flows

2. **The 5-Step Debugging Process** (~40 lines)
   - **Step 1: Read the witness source** — Which witness function or circuit parameter is the source? Find it in the error message after "witness value potentially disclosed."
   - **Step 2: Read the disclosure path** — Follow "via this path through the program:" — this shows every binding, circuit call, and computation the data passes through from source to disclosure point.
   - **Step 3: Ask "Is this disclosure intentional?"** — If you meant to make this value public (e.g., writing a public key to ledger, checking a condition for access control), proceed to Step 4. If you did NOT intend to disclose (e.g., you're accidentally leaking a secret), proceed to Step 5.
   - **Step 4: Place disclose() at the right location** — Best practice: wrap as close to the disclosure point as possible. For structured values, only wrap the witness-containing portion. For examples:
     ```compact
     // Direct write: wrap at the assignment
     balance = disclose(getBalance());

     // Conditional: wrap the condition
     if (disclose(getFlag())) { ... }

     // Return: wrap the return expression
     return disclose(computedValue);
     ```
   - **Step 5: Restructure to avoid the leak** — If you did NOT intend to disclose, you need to restructure. Common approaches:
     - Use a commitment instead of the raw value: `storedHash = disclose(persistentCommit(secret, rand))`
     - Use a MerkleTree instead of a Set (insert hides the leaf)
     - Move the computation inside the proof (don't write intermediates to ledger)
     - Use an internal circuit instead of returning from an exported circuit

3. **Common Error Patterns with Fixes** (~80 lines) — Table per pattern:

   **Pattern 1: Direct ledger write**
   ```compact
   // ERROR: balance = getBalance();
   // FIX:
   balance = disclose(getBalance());
   ```

   **Pattern 2: Indirect via arithmetic/cast**
   ```compact
   // ERROR: result = getSecret() + 42;
   // FIX: wrap at the assignment, not at the call
   result = disclose(getSecret() + 42);
   ```

   **Pattern 3: Conditional on witness value**
   ```compact
   // ERROR: if (getFlag()) { ... }
   // FIX:
   if (disclose(getFlag())) { ... }
   ```

   **Pattern 4: Return from exported circuit**
   ```compact
   // ERROR: return getBalance() > n;
   // FIX:
   return disclose(getBalance() > n);
   ```

   **Pattern 5: Struct field containing witness data**
   ```compact
   // ERROR: storedConfig = Config { threshold: getThreshold(), admin: admin };
   // FIX: disclose only the witness-containing field
   storedConfig = Config { threshold: disclose(getThreshold()), admin: admin };
   ```

   **Pattern 6: ADT method with witness argument**
   ```compact
   // ERROR: balances.insert(get_public_key(local_secret_key()), amount);
   // FIX:
   balances.insert(disclose(get_public_key(local_secret_key())), disclose(amount));
   ```

   **Pattern 7: Standard library call forwarding witness data**
   ```compact
   // ERROR: mintShieldedToken(domain, amount, nonce, recipient);
   // (where amount and recipient come from witnesses)
   // FIX:
   mintShieldedToken(domain, disclose(amount), nonce, disclose(recipient));
   ```

4. **Where NOT to Put disclose()** (~20 lines)
   - Don't disclose at the witness call site unless the witness always returns public data
   - Don't disclose a whole struct when only one field is witness-derived
   - Don't disclose inside a helper circuit if the caller also discloses — that's redundant
   - Don't use disclose to "fix" errors without understanding what you're making public

5. **Verifying Your Fix** (~15 lines)
   - Use `midnight-compile-contract` to verify the fix compiles
   - After fixing, audit: "What am I making public?" — trace what the observer can now see
   - Check if there's a privacy-preserving alternative (commitment, MerkleTree, etc.)

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-privacy-disclosure/references/debugging-disclosure.md
git commit -m "feat(compact-core): add debugging-disclosure reference for compact-privacy-disclosure"
```

---

### Task 5: Write examples/CommitRevealScheme.compact

**Files:**
- Create: `plugins/compact-core/skills/compact-privacy-disclosure/examples/CommitRevealScheme.compact`

**Research:** Use these MCP tools:
- `midnight-search-compact` for `commit reveal persistentCommit salt` — find real commit-reveal patterns
- Review `compact-structure/references/patterns.md` for the existing basic commit-reveal

**Content:** A complete, commented contract demonstrating the commit-reveal pattern.

The contract should:
- Have a header comment block explaining the pattern, what's private, what's public
- Use `persistentCommit<T>` (not just `persistentHash`) for proper hiding with randomness
- Include phases: commit (store commitment hash), reveal (verify and expose value)
- Use `sealed ledger` for the commitment owner
- Include a witness for salt/randomness
- Include inline comments on every `disclose()` call
- End with a Privacy Analysis comment block

Validate: After writing, compile with `midnight-compile-contract` (skipZk=true). Fix any errors.

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-privacy-disclosure/examples/CommitRevealScheme.compact
git commit -m "feat(compact-core): add CommitRevealScheme example for compact-privacy-disclosure"
```

---

### Task 6: Write examples/NullifierDoubleSpend.compact

**Files:**
- Create: `plugins/compact-core/skills/compact-privacy-disclosure/examples/NullifierDoubleSpend.compact`

**Research:** Use these MCP tools:
- `midnight-search-compact` for `nullifier derive_nullifier coin_info commitment` — zerocash patterns
- `midnight-search-compact` for `HistoricMerkleTree checkRoot merkleTreePathRoot` — Merkle proof patterns

**Content:** A complete contract demonstrating commitment+nullifier for single-use tokens.

The contract should:
- Use `HistoricMerkleTree` for storing commitments (insert hides leaf values)
- Use `Set<Bytes<32>>` for spent nullifiers (public by design)
- Include an `issue()` circuit that creates a commitment and inserts it into the tree
- Include a `spend()` circuit that:
  1. Gets the user's secret from witness
  2. Derives the commitment from the secret
  3. Gets the Merkle path from witness
  4. Verifies the path against the tree root
  5. Derives a nullifier (with different domain separator than commitment)
  6. Checks the nullifier hasn't been used
  7. Inserts the nullifier
- Use domain-separated hashing for both commitments and nullifiers
- Include the Privacy Analysis comment block

Validate: After writing, compile with `midnight-compile-contract` (skipZk=true). Fix any errors.

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-privacy-disclosure/examples/NullifierDoubleSpend.compact
git commit -m "feat(compact-core): add NullifierDoubleSpend example for compact-privacy-disclosure"
```

---

### Task 7: Write examples/PrivateVoting.compact

**Files:**
- Create: `plugins/compact-core/skills/compact-privacy-disclosure/examples/PrivateVoting.compact`

**Research:** Use these MCP tools:
- `midnight-search-compact` for `election vote commit reveal nullifier eligible` — find the official election patterns
- `midnight-search-compact` for `micro-dao committed_votes committed_participants` — the DAO voting example
- `midnight-fetch-docs` with path `/compact/writing` — the lock contract with round-based auth

**Content:** The most complex example — combines MerkleTree membership + nullifiers + commit-reveal.

The contract should:
- Use `HistoricMerkleTree` for eligible voters (private membership)
- Use `HistoricMerkleTree` for committed votes (private vote content)
- Use `Set<Bytes<32>>` for commitment nullifiers (prevents double-commit)
- Use `Set<Bytes<32>>` for reveal nullifiers (prevents double-reveal)
- Use enum for phases: `setup`, `commit`, `reveal`, `final`
- Include circuits for:
  - `registerVoter(voterPk)` — admin registers voters in setup phase
  - `commitVote(ballot)` — voter proves eligibility via Merkle proof, commits hidden vote
  - `revealVote()` — voter reveals their committed vote with proof
- Use separate domain separators for commitment nullifiers and reveal nullifiers (from the real election.compact pattern: `"lares:election:cm-nul:"` and `"lares:election:rv-nul:"`)
- Include Counter for yes/no tallying
- Include the Privacy Analysis comment block

Validate: After writing, compile with `midnight-compile-contract` (skipZk=true). Fix any errors.

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-privacy-disclosure/examples/PrivateVoting.compact
git commit -m "feat(compact-core): add PrivateVoting example for compact-privacy-disclosure"
```

---

### Task 8: Write examples/UnlinkableAuth.compact

**Files:**
- Create: `plugins/compact-core/skills/compact-privacy-disclosure/examples/UnlinkableAuth.compact`

**Research:** Use these MCP tools:
- `midnight-fetch-docs` with path `/compact/writing` — the official lock contract example
- Review `compact-structure/references/patterns.md` for the round-based unlinkability pattern
- Review `compact-ledger/references/privacy-and-visibility.md` Pattern 4: Round-Based Unlinkability

**Content:** A complete contract demonstrating round-based key rotation.

The contract should:
- Use `Counter` for round tracking
- Use `ledger authority: Bytes<32>` for the current round's public key hash
- Derive keys as `persistentHash([domain, round_as_bytes, sk])` — incorporating the round number
- Include `constructor` that sets initial authority
- Include an `authenticate()` circuit that:
  1. Gets secret key from witness
  2. Derives public key for current round
  3. Asserts the derived key matches stored authority
  4. Increments round
  5. Computes and stores the new round's authority
- Include a `setValue()` circuit showing authenticated action with round rotation
- Include `sealed ledger` for immutable contract metadata
- Include the Privacy Analysis comment block

Validate: After writing, compile with `midnight-compile-contract` (skipZk=true). Fix any errors.

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-privacy-disclosure/examples/UnlinkableAuth.compact
git commit -m "feat(compact-core): add UnlinkableAuth example for compact-privacy-disclosure"
```

---

### Task 9: Write examples/SelectiveDisclosure.compact

**Files:**
- Create: `plugins/compact-core/skills/compact-privacy-disclosure/examples/SelectiveDisclosure.compact`

**Research:** Use these MCP tools:
- `midnight-search-docs` for `selective disclosure prove property range` — conceptual docs
- `midnight-search-compact` for `assert disclose comparison threshold` — real patterns

**Content:** A contract demonstrating proving properties without revealing values.

The contract should:
- Model a "credit score" or "balance threshold" verification
- Store a committed credential on-chain (hash of real value)
- Include a `verifyThreshold(threshold)` circuit that:
  1. Gets the real value from witness
  2. Recomputes the commitment and verifies it matches on-chain
  3. Discloses only the boolean result of `value >= threshold`, not the value itself
- Include a `verifyRange(min, max)` circuit for range proofs
- Include a `verifyProperty()` circuit showing selective field disclosure from a struct
- Include the Privacy Analysis: observer learns "value meets threshold" but not the actual value

Validate: After writing, compile with `midnight-compile-contract` (skipZk=true). Fix any errors.

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-privacy-disclosure/examples/SelectiveDisclosure.compact
git commit -m "feat(compact-core): add SelectiveDisclosure example for compact-privacy-disclosure"
```

---

### Task 10: Write examples/ShieldedAuction.compact

**Files:**
- Create: `plugins/compact-core/skills/compact-privacy-disclosure/examples/ShieldedAuction.compact`

**Research:** Use these MCP tools:
- `midnight-search-compact` for `blockTimeGte blockTimeLt auction bid` — time-based patterns
- `midnight-search-compact` for `commit reveal phase enum state` — state machine patterns
- Review `compact-structure/references/patterns.md` for the state machine pattern

**Content:** The most practical example — sealed-bid auction combining multiple patterns.

The contract should:
- Use enum for phases: `bidding`, `reveal`, `finalized`
- Use `Map<Bytes<32>, Bytes<32>>` for bid commitments (bidder hash → commitment hash)
- Use `blockTimeGte`/`blockTimeLt` for phase deadlines
- Include circuits for:
  - `placeBid(amount)` — commit hidden bid amount during bidding phase
  - `revealBid(amount)` — reveal bid during reveal phase, verify against commitment
  - `finalize()` — determine winner after reveal phase ends
- Track highest bid and winner
- Use `persistentCommit` for bid hiding with salt from witness
- Include the Privacy Analysis: during bidding, amounts are hidden; after reveal, winning bid is public

Validate: After writing, compile with `midnight-compile-contract` (skipZk=true). Fix any errors.

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-privacy-disclosure/examples/ShieldedAuction.compact
git commit -m "feat(compact-core): add ShieldedAuction example for compact-privacy-disclosure"
```

---

### Task 11: Write complete SKILL.md

**Files:**
- Create: `plugins/compact-core/skills/compact-privacy-disclosure/SKILL.md` (overwrite placeholder)

**Dependencies:** All reference files and examples must be written first, as SKILL.md references them.

**Content:** Follow the design doc SKILL.md Structure section exactly. Include:

1. **Frontmatter** — name and description exactly as specified in design doc

2. **Opening paragraph** — Scope definition with cross-references to other skills

3. **Midnight's Privacy Model** — Privacy-by-default, witness protection program, disclose() as explicit annotation

4. **Privacy Decision Tree** — The 7-row table from the design doc

5. **Disclosure Rules Quick Reference** — When required vs when not required, table format

6. **Safe Stdlib Routines** — The persistentCommit/transientCommit vs hash distinction

7. **Common Disclosure Mistakes** — Quick-reference table matching other skills' format:

| Wrong | Correct | Why |
|-------|---------|-----|
| `balance = getBalance()` | `balance = disclose(getBalance())` | Ledger write requires disclosure |
| `if (getFlag()) { ... }` | `if (disclose(getFlag())) { ... }` | Conditional requires disclosure |
| `return computeResult()` | `return disclose(computeResult())` | Exported circuit return requires disclosure |
| `disclose(getBalance()); ...; balance = x` | `balance = disclose(x)` | Disclose at disclosure point, not at source |
| `Set` for private membership | `MerkleTree` + ZK path proof | Set reveals which element is tested |
| Same domain for commitment and nullifier | Different domains | Same domain enables linking attack |
| `persistentHash(secret)` to "hide" witness | `persistentCommit(secret, rand)` | Hash doesn't clear witness taint; commit does |

8. **Reference Routing Table**

| Topic | Reference File |
|-------|---------------|
| How disclose() works, Witness Protection Program, safe routines, placement best practices | `references/disclosure-mechanics.md` |
| Commitments, nullifiers, MerkleTree auth, unlinkability, threat model, anti-patterns | `references/privacy-patterns.md` |
| Fixing disclosure compiler errors step-by-step, common error patterns | `references/debugging-disclosure.md` |

9. **Examples Routing Table**

| Example | File | Pattern |
|---------|------|---------|
| Two-phase commit-reveal with salt-based commitments | `examples/CommitRevealScheme.compact` | Commit-Reveal |
| Single-use tokens with commitment + nullifier | `examples/NullifierDoubleSpend.compact` | Nullifiers |
| Anonymous voting with Merkle proofs and commit-reveal | `examples/PrivateVoting.compact` | Private Voting |
| Round-based key rotation for unlinkable actions | `examples/UnlinkableAuth.compact` | Unlinkable Auth |
| Proving properties without revealing values | `examples/SelectiveDisclosure.compact` | Selective Disclosure |
| Sealed-bid auction with time constraints | `examples/ShieldedAuction.compact` | Shielded Auction |

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-privacy-disclosure/SKILL.md
git commit -m "feat(compact-core): write complete SKILL.md for compact-privacy-disclosure"
```

---

### Task 12: Final review and validation

**Files:**
- Review: all files in `plugins/compact-core/skills/compact-privacy-disclosure/`
- Review: `plugins/compact-core/.claude-plugin/plugin.json`

**Step 1: Validate all example contracts compile**

Use `midnight-compile-contract` (skipZk=true) for each of the 6 .compact files. Fix any compilation errors.

**Step 2: Cross-reference check**

Verify all cross-references between files are correct:
- SKILL.md references to `references/*.md` and `examples/*.compact`
- References to other skills (`compact-ledger`, `compact-structure`, `compact-standard-library`, `compact-tokens`)
- Internal links within reference files

**Step 3: Content consistency check**

- All `disclose()` examples use the same patterns
- Function signatures match `compact-standard-library` (e.g., `persistentCommit<T>(value, rand)` not some other signature)
- Domain separator patterns are consistent (e.g., `pad(32, "domain:")` format)
- Error message examples match real compiler output

**Step 4: Commit any fixes**

```bash
git add -A plugins/compact-core/skills/compact-privacy-disclosure/
git commit -m "fix(compact-core): address review findings in compact-privacy-disclosure"
```
