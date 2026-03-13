# Token & Economic Security Review Checklist

Review checklist for the **Token & Economic Security** category. This covers double-spend prevention, arithmetic overflow/underflow, authorization controls, shielded token operations, and unshielded balance safety. Apply every item below to the contract under review.

## Required MCP Tools

Run these tools before starting your review. Reference their output when evaluating checklist items.

| Tool | Label | Purpose |
|------|-------|---------|
| `midnight-compile-contract` | `[shared]` | Compilation errors from type mismatches in token operations |
| `midnight-extract-contract-structure` | `[shared]` | Detects structural issues in token handling, missing checks |
| `midnight-analyze-contract` | `[shared]` | Static analysis of token patterns |
| `midnight-get-latest-syntax` | `[shared]` | Authoritative reference for token operation signatures |

Tools marked `[shared]` are pre-run by the orchestrator — their output is in your prompt.

## Double-Spend Prevention Checklist

Check every token-spending circuit for proper nullifier handling and commitment verification.

- [ ] **Nullifier checked before spending.** Before any coin is consumed, the contract must verify that its nullifier has not already been used. A missing membership check allows the same coin to be spent multiple times, draining value from the system.

  ```compact
  // BAD — spends the coin without checking if nullifier was already used
  export circuit spend(coin: ShieldedCoinInfo, nul: Bytes<32>): [] {
    nullifiers.insert(disclose(nul));
    // ... process spend
  }

  // GOOD — checks nullifier is unused before proceeding
  export circuit spend(coin: ShieldedCoinInfo, nul: Bytes<32>): [] {
    assert(!nullifiers.member(disclose(nul)), "Coin already spent");
    nullifiers.insert(disclose(nul));
    // ... process spend
  }
  ```

- [ ] **Nullifier inserted after validation.** The nullifier must be inserted into the used-nullifier set only after all validity checks pass (commitment path verified, amount validated, authorization confirmed). Inserting the nullifier before validation means a failed transaction could still mark the nullifier as used, permanently locking the coin.

  ```compact
  // BAD — inserts nullifier before validation; failure locks the coin
  export circuit spend(nul: Bytes<32>, path: MerkleTreePath<16, Bytes<32>>, amount: Field): [] {
    nullifiers.insert(disclose(nul));
    const root = merkleTreePathRoot<16, Bytes<32>>(path);
    assert(commitments.checkRoot(disclose(root)), "Invalid commitment");
    assert(amount > 0, "Invalid amount");
    // ... process spend
  }

  // GOOD — validates everything before inserting nullifier
  export circuit spend(nul: Bytes<32>, path: MerkleTreePath<16, Bytes<32>>, amount: Field): [] {
    assert(!nullifiers.member(disclose(nul)), "Coin already spent");
    const root = merkleTreePathRoot<16, Bytes<32>>(path);
    assert(commitments.checkRoot(disclose(root)), "Invalid commitment");
    assert(amount > 0, "Invalid amount");
    nullifiers.insert(disclose(nul));
    // ... process spend
  }
  ```

- [ ] **Nullifier deterministically derived from coin and secret, not random.** A nullifier must be a deterministic function of the coin commitment and the owner's secret key. If the nullifier is random or non-deterministic (e.g., using `transientHash`), the same coin can produce different nullifiers each time, completely defeating double-spend detection.

  ```compact
  // BAD — random nullifier; same coin can produce different nullifiers
  circuit computeNullifier(coin: Bytes<32>): Bytes<32> {
    return transientHash<Bytes<32>>(coin);
  }

  // GOOD — deterministic nullifier derived from coin + secret + domain
  circuit computeNullifier(coin: Bytes<32>, sk: Bytes<32>): Bytes<32> {
    return persistentHash<Vector<3, Bytes<32>>>(
      [pad(32, "mytoken:nul:"), coin, sk]
    );
  }
  ```

  > **Tool:** `midnight-extract-contract-structure` identifies hash function usage. Verify all nullifier derivations use `persistentHash`, not `transientHash`.

- [ ] **Commitment path verified against tree root before spend.** When spending a coin, the prover supplies a Merkle path proving the coin's commitment exists in the commitment tree. The contract must verify this path against the on-chain root using `checkRoot()`. Without this check, a prover can fabricate a commitment for coins that were never minted.

  ```compact
  // BAD — no commitment path verification; prover can invent coins
  export circuit spend(nul: Bytes<32>, amount: Field): [] {
    assert(!nullifiers.member(disclose(nul)), "Already spent");
    nullifiers.insert(disclose(nul));
    // Spends amount without proving the coin exists in the tree
  }

  // GOOD — verifies commitment exists in the tree
  export circuit spend(nul: Bytes<32>, path: MerkleTreePath<16, Bytes<32>>, amount: Field): [] {
    assert(!nullifiers.member(disclose(nul)), "Already spent");
    const root = merkleTreePathRoot<16, Bytes<32>>(path);
    assert(commitments.checkRoot(disclose(root)), "Commitment not in tree");
    nullifiers.insert(disclose(nul));
    // ... process spend with verified amount
  }
  ```

## Overflow/Underflow Checklist

Check all arithmetic operations on token amounts for type sufficiency and bounds safety.

- [ ] **Token amount type: `Uint<64>` vs `Uint<128>` — is the chosen type sufficient?** Compact supports both `Uint<64>` and `Uint<128>` for token amounts. Most shielded operations (`mintShieldedToken`, `sendShielded`, `sendImmediateShielded`) and unshielded send operations (`sendUnshielded`) use `Uint<128>` for amounts. The exception is `mintUnshieldedToken`, which uses `Uint<64>`. Using the wrong type can cause truncation or compilation errors. Verify that the type matches the token operation context.

  ```compact
  // GOOD — Uint<128> for shielded mint value parameter
  export circuit mintShielded(amount: Uint<128>): ShieldedCoinInfo {
    return mintShieldedToken(
      disclose(domainSep), disclose(amount),
      evolveNonce(0 as Uint<64>, disclose(domainSep)),
      left<ZswapCoinPublicKey, ContractAddress>(ownPublicKey())
    );
  }
  ```

  > **Tool:** `midnight-get-latest-syntax` provides the authoritative stdlib function signatures showing the exact `Uint` width for each token operation. `midnight-compile-contract` output will show type mismatch errors if the wrong width is used.

- [ ] **Addition overflow check: total does not exceed maximum value.** When adding to a balance or accumulating amounts, the result must not exceed the maximum representable value for the type. In ZK circuits, overflow wraps silently, producing a small value instead of a large one. Always assert that the addition will not overflow before performing it.

  ```compact
  // BAD — addition could overflow silently, wrapping to a small value
  export circuit deposit(account: Bytes<32>, amount: Uint<128>): [] {
    const current = balances.lookup(account);
    balances.insert(account, current + amount);
  }

  // GOOD — overflow check before addition
  export circuit deposit(account: Bytes<32>, amount: Uint<128>): [] {
    assert(amount > 0, "Deposit must be positive");
    assert(balances.member(account), "Account not found");
    const current = balances.lookup(account);
    const max: Uint<128> = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    assert(max - current >= amount, "Deposit would overflow balance");
    balances.insert(account, current + amount);
  }
  ```

- [ ] **Subtraction underflow check: balance is sufficient before deduction.** Subtracting more than the current balance wraps to the maximum unsigned value in ZK circuits, effectively creating tokens from nothing. Always assert that the balance is greater than or equal to the amount before subtraction.

  ```compact
  // BAD — underflow wraps to maximum value, creating tokens
  export circuit withdraw(account: Bytes<32>, amount: Uint<128>): [] {
    const current = balances.lookup(account);
    balances.insert(account, current - amount);
  }

  // GOOD — assert sufficient balance before subtraction
  export circuit withdraw(account: Bytes<32>, amount: Uint<128>): [] {
    assert(amount > 0, "Withdrawal must be positive");
    assert(balances.member(account), "Account not found");
    const current = balances.lookup(account);
    assert(current >= amount, "Insufficient balance");
    balances.insert(account, current - amount);
  }
  ```

- [ ] **Total supply overflow on mint operations.** When minting new tokens, the total supply increases. If the contract does not track total supply or does not check for overflow at the supply level, it is possible to mint tokens past the maximum representable value, wrapping the total supply to a small number.

  ```compact
  // BAD — no supply tracking or overflow check
  export circuit mint(to: Bytes<32>, amount: Uint<128>): [] {
    assert(caller == authority, "Not authorized");
    const current = balances.lookup(to);
    balances.insert(to, current + amount);
  }

  // GOOD — tracks and limits total supply
  export circuit mint(to: Bytes<32>, amount: Uint<128>): [] {
    assert(caller == authority, "Not authorized");
    assert(amount > 0, "Amount must be positive");
    const supply = total_supply.read();
    assert(supply + amount <= MAX_SUPPLY, "Exceeds maximum supply");
    total_supply.increment(amount);
    const current = balances.member(to) ? balances.lookup(to) : 0;
    balances.insert(to, current + amount);
  }
  ```

- [ ] **Intermediate arithmetic fits in the declared type.** When performing multi-step arithmetic (e.g., `a + b - c`, `amount * rate / divisor`), intermediate results may overflow even if the final result fits. Verify that every intermediate step remains within the bounds of the declared type.

  ```compact
  // BAD — intermediate (a + b) may overflow even if (a + b - c) would fit
  const result = a + b - c;

  // GOOD — check intermediate result fits, or reorder to avoid overflow
  assert(a >= c, "Underflow in a - c");
  const result = (a - c) + b;
  // Or: assert that a + b does not overflow before proceeding
  ```

## Authorization Checklist

Check all token operations for proper caller authorization and role enforcement.

- [ ] **Mint operations: who can call? Is there an authority check?** Minting creates new tokens and must be restricted to authorized callers. An `export circuit` that mints tokens without verifying the caller's identity allows anyone to inflate the token supply. This is a critical vulnerability.

  ```compact
  // BAD — anyone can mint unlimited tokens
  export circuit mint(amount: Uint<64>): [] {
    token.mint(amount);
  }

  // GOOD — only the authority can mint (pattern from lock.compact)
  export circuit mint(amount: Uint<64>): [] {
    const sk = secretKey();
    const pk = publicKey(round, sk);
    assert(authority == pk, "Attempted to mint without authorization");
    token.mint(amount);
  }
  ```

- [ ] **Burn operations: can only the owner burn their tokens?** Burning destroys tokens permanently. If the burn circuit does not verify that the caller owns the tokens being burned, an attacker can destroy other users' tokens.

  ```compact
  // BAD — anyone can burn any account's tokens
  export circuit burn(account: Bytes<32>, amount: Uint<128>): [] {
    const current = balances.lookup(account);
    assert(current >= amount, "Insufficient balance");
    balances.insert(account, current - amount);
  }

  // GOOD — only the account owner can burn
  export circuit burn(amount: Uint<128>): [] {
    const sk = local_secret_key();
    const account = disclose(publicKey(sk));
    assert(balances.member(account), "Account not found");
    const current = balances.lookup(account);
    assert(current >= amount, "Insufficient balance");
    balances.insert(account, current - amount);
  }
  ```

- [ ] **Transfer operations: sender authorization verified.** A transfer must verify that the caller is the sender (or an approved delegate). Without sender verification, anyone can move tokens out of any account.

  ```compact
  // BAD — caller not verified as the sender
  export circuit transfer(from: Bytes<32>, to: Bytes<32>, amount: Uint<128>): [] {
    const from_bal = balances.lookup(from);
    assert(from_bal >= amount, "Insufficient balance");
    balances.insert(from, from_bal - amount);
    const to_bal = balances.member(to) ? balances.lookup(to) : 0;
    balances.insert(to, to_bal + amount);
  }

  // GOOD — sender proves ownership via secret key
  export circuit transfer(to: Bytes<32>, amount: Uint<128>): [] {
    const sk = local_secret_key();
    const from = disclose(publicKey(sk));
    assert(balances.member(from), "Sender account not found");
    const from_bal = balances.lookup(from);
    assert(from_bal >= amount, "Insufficient balance");
    balances.insert(from, from_bal - amount);
    const to_bal = balances.member(to) ? balances.lookup(to) : 0;
    balances.insert(to, to_bal + amount);
  }
  ```

- [ ] **Allowance/approval: `spendAllowance` correctly deducts from approved amount.** If the contract implements a delegated spending pattern (like ERC-20 `approve` + `transferFrom`), verify that the allowance is checked and deducted atomically. A missing deduction allows unlimited spending from a single approval.

  ```compact
  // BAD — checks allowance but does not deduct it; infinite spend
  export circuit transferFrom(owner: Bytes<32>, to: Bytes<32>, amount: Uint<128>): [] {
    const sk = local_secret_key();
    const spender = disclose(publicKey(sk));
    const allowed = allowances.lookup(owner);
    assert(allowed >= amount, "Allowance exceeded");
    // Missing: allowances.insert(owner, allowed - amount);
    const bal = balances.lookup(owner);
    balances.insert(owner, bal - amount);
    balances.insert(to, amount);
  }

  // GOOD — deducts allowance atomically with the transfer
  export circuit transferFrom(owner: Bytes<32>, to: Bytes<32>, amount: Uint<128>): [] {
    const sk = local_secret_key();
    const spender = disclose(publicKey(sk));
    const allowed = allowances.lookup(owner);
    assert(allowed >= amount, "Allowance exceeded");
    allowances.insert(owner, allowed - amount);
    const bal = balances.lookup(owner);
    assert(bal >= amount, "Insufficient balance");
    balances.insert(owner, bal - amount);
    const to_bal = balances.member(to) ? balances.lookup(to) : 0;
    balances.insert(to, to_bal + amount);
  }
  ```

- [ ] **`unsafe` variants (`unsafeTransfer`, `unsafeMint`): are they intentionally exposed?** Some token implementations expose `unsafe` versions of operations that skip safety checks (e.g., `unsafeTransfer` that does not verify `receiveShielded` on the receiving end, or `unsafeMint` that bypasses authority checks). If these are exported, verify that the exposure is intentional. Warning: tokens sent via `unsafeTransfer` to a contract address that does not call `receiveShielded` are permanently lost and irretrievable.

  ```compact
  // DANGEROUS — unsafeTransfer skips receiveShielded check on recipient
  // Tokens sent to a contract that does not call receiveShielded are LOST
  export circuit unsafeTransfer(
    coin: ShieldedCoinInfo,
    to: Either<ZswapCoinPublicKey, ContractAddress>,
    amount: Uint<64>
  ): [] {
    // Does not verify recipient calls receiveShielded
    sendShielded(coin, to, amount);
  }

  // If unsafe variants exist, ensure they are:
  // 1. Clearly documented as unsafe
  // 2. Not exported unless absolutely necessary
  // 3. Only called from circuits that handle the safety checks themselves
  ```

## Shielded Token Checklist

Check all shielded (zswap) token operations for correct API usage and value handling.

- [ ] **`receiveShielded()` called in receiving contract.** When shielded tokens are sent to a contract address, the receiving contract MUST call `receiveShielded(disclose(coin))` to accept and register the incoming coin. If `receiveShielded` is not called, the tokens are permanently lost with no recovery mechanism. This is one of the most critical token security checks.

  ```compact
  // BAD — contract receives shielded tokens but never calls receiveShielded
  // Tokens sent here are PERMANENTLY LOST
  export circuit deposit(coin: ShieldedCoinInfo): [] {
    // Process deposit logic but forget to receive the coin
    deposits.insert(disclose(someKey), disclose(coin.value));
  }

  // GOOD — receiveShielded called to accept incoming tokens
  // (pattern from midnight-node minter.compact)
  export circuit receiveShieldedTest(coin: ShieldedCoinInfo): [] {
    assert(coin.value > 0, "Deposit amount must be positive");
    receiveShielded(disclose(coin));
  }
  ```

  > **Tool:** `midnight-extract-contract-structure` identifies all `receiveShielded` calls. Cross-reference against all circuits that accept `ShieldedCoinInfo` parameters — each must call `receiveShielded`. `midnight-search-compact` can find reference patterns for correct shielded token handling.

- [ ] **Correct coin color used (token type identifier).** In Midnight's zswap model, each token type is identified by a "color" (a `Bytes<32>` domain separator). Using the wrong color means the operation targets the wrong token type. Verify that the domain separator passed to `mintShieldedToken` and other operations matches the intended token.

  ```compact
  // BAD — hardcoded color string that may not match the token's actual color
  const color = pad(32, "some-token");

  // GOOD — use a consistent domain separator, typically from a ledger or constant
  // (pattern from midnight-node minter.compact)
  export circuit mintShieldedToSelfTest(domainSep: Bytes<32>, amount: Uint<64>): ShieldedCoinInfo {
    const recipient = ownPublicKey();
    return mintShieldedToken(
      disclose(domainSep),
      disclose(amount),
      evolveNonce(0 as Uint<64>, disclose(domainSep)),
      left<ZswapCoinPublicKey, ContractAddress>(recipient)
    );
  }
  ```

- [ ] **`ShieldedCoinInfo` vs `QualifiedShieldedCoinInfo` — correct type for the operation.** These two types serve different purposes. `ShieldedCoinInfo` represents a newly minted or received coin. `QualifiedShieldedCoinInfo` represents a coin that has been qualified (bound to a specific spend context). Using the wrong type causes compilation errors or incorrect behavior. Check the stdlib signatures:
  - `receiveShielded(ShieldedCoinInfo)` — takes unqualified coin info
  - `sendShielded(QualifiedShieldedCoinInfo, ...)` — requires qualified coin info
  - `sendImmediateShielded(ShieldedCoinInfo, ...)` — takes unqualified coin info
  - `mergeCoin(QualifiedShieldedCoinInfo, QualifiedShieldedCoinInfo)` — merges two qualified coins

- [ ] **Change output handled properly after partial spend.** When spending only part of a shielded coin, the remaining value must be returned as a change output. If the change is not handled, the difference between the coin value and the sent amount is lost. Check that `sendImmediateShielded` return values are processed for change coins.

  ```compact
  // BAD — sends partial value but ignores the change output
  export circuit partialSpend(coin: ShieldedCoinInfo, amount: Uint<64>): [] {
    receiveShielded(disclose(coin));
    sendImmediateShielded(
      disclose(coin),
      right<ZswapCoinPublicKey, ContractAddress>(targetContract),
      disclose(amount)
    );
    // Change coin is lost!
  }

  // GOOD — handles the return value including change
  // (pattern from composable-relay.compact)
  export circuit send_to_burn(coin: ShieldedCoinInfo): [] {
    receiveShielded(disclose(coin));
    const sendValue = coin.value == 0 ? 0 : coin.value - 1;
    const res = sendImmediateShielded(
      disclose(coin),
      right<ZswapCoinPublicKey, ContractAddress>(burnContract),
      disclose(sendValue)
    );
    tmpDoCall(res.sent);
  }
  ```

- [ ] **`sendImmediateShielded` return value checked for change coins.** The `sendImmediateShielded` function returns a result that includes information about the sent coin and any change. If the return value is discarded, the caller loses the ability to handle change and cannot verify that the send succeeded.

  ```compact
  // BAD — return value discarded; change is lost and success not verified
  export circuit send(coin: ShieldedCoinInfo, to: ContractAddress, amount: Uint<64>): [] {
    receiveShielded(disclose(coin));
    sendImmediateShielded(
      disclose(coin),
      right<ZswapCoinPublicKey, ContractAddress>(to),
      disclose(amount)
    );
  }

  // GOOD — capture and process the return value
  export circuit send(coin: ShieldedCoinInfo, to: ContractAddress, amount: Uint<64>): [] {
    receiveShielded(disclose(coin));
    const res = sendImmediateShielded(
      disclose(coin),
      right<ZswapCoinPublicKey, ContractAddress>(to),
      disclose(amount)
    );
    // Process res.sent and handle any change output
    tmpDoCall(res.sent);
  }
  ```

- [ ] **Correct `Uint` width for token operations.** Token operations use specific `Uint` widths. The `mintShieldedToken` function takes `Uint<128>` for the value parameter, while `mintUnshieldedToken` takes `Uint<64>`. The `sendShielded`, `sendImmediateShielded`, and `sendUnshielded` functions all take `Uint<128>` for the amount parameter. Check the stdlib signatures below for the exact types required by each function.

  Standard library function signatures for reference:
  ```
  mintShieldedToken(Bytes<32>, Uint<128>, Bytes<32>, Either<ZswapCoinPublicKey, ContractAddress>)
  sendImmediateShielded(ShieldedCoinInfo, Either<ZswapCoinPublicKey, ContractAddress>, Uint<128>)
  sendShielded(QualifiedShieldedCoinInfo, Either<ZswapCoinPublicKey, ContractAddress>, Uint<128>)
  mintUnshieldedToken(Bytes<32>, Uint<64>, Either<ContractAddress, UserAddress>)
  sendUnshielded(Bytes<32>, Uint<128>, Either<ContractAddress, UserAddress>)
  ```

  > **Tool:** `midnight-get-latest-syntax` is the authoritative source for these function signatures. Cross-reference every token operation call against the syntax reference.

## Unshielded Token Checklist

Check all unshielded token operations for construction-time pitfalls and API correctness.

- [ ] **`unshieldedBalance()` not used in conditional logic.** Calling `unshieldedBalance()` inside an `if` condition or using its return value to make branching decisions creates a construction-time balance lock. The balance is captured when the proof is constructed (on the client), not when the transaction executes on-chain. By the time the transaction lands, the actual balance may have changed, leading to incorrect logic or stale decisions.

  ```compact
  // BAD — creates construction-time balance lock; stale by execution time
  export circuit conditionalTransfer(color: Bytes<32>, amount: Uint<128>): [] {
    if (unshieldedBalance(disclose(color)) > amount) {
      sendUnshielded(disclose(color), disclose(amount), recipient);
    }
  }

  // GOOD — use dedicated comparison circuit from stdlib
  // (pattern from midnight-js testkit)
  export circuit conditionalTransfer(color: Bytes<32>, amount: Uint<128>): Boolean {
    return unshieldedBalanceGt(disclose(color), disclose(amount));
  }
  ```

  > **Tool:** `midnight-search-docs` has guidance on construction-time balance locks and the correct use of comparison functions.

- [ ] **Comparison functions used instead of raw balance reads.** The standard library provides `unshieldedBalanceGt` and `unshieldedBalanceLt` for safe balance comparisons. These functions are designed to avoid the construction-time lock problem inherent in `unshieldedBalance()`. Use them instead of reading the balance and comparing manually.

  ```compact
  // BAD — reads balance then compares; construction-time lock
  export circuit hasEnough(color: Bytes<32>, threshold: Uint<128>): Boolean {
    return disclose(unshieldedBalance(disclose(color)) >= threshold);
  }

  // GOOD — stdlib comparison avoids construction-time lock
  export circuit hasEnough(color: Bytes<32>, threshold: Uint<128>): Boolean {
    return unshieldedBalanceGt(disclose(color), disclose(threshold));
  }
  ```

  Available stdlib comparison functions:
  ```
  unshieldedBalanceGt(Bytes<32>, Uint<128>) -> Boolean
  unshieldedBalanceGte(Bytes<32>, Uint<128>) -> Boolean
  unshieldedBalanceLt(Bytes<32>, Uint<128>) -> Boolean
  unshieldedBalanceLte(Bytes<32>, Uint<128>) -> Boolean
  ```

- [ ] **Proper `disclose()` on amount parameters.** Unshielded token operations require disclosed (public) parameters because unshielded balances are inherently public. Forgetting `disclose()` on the color or amount will cause a compilation error since undisclosed witness values cannot flow to public ledger operations.

  ```compact
  // BAD — missing disclose; will not compile
  export circuit send(color: Bytes<32>, amount: Uint<128>): [] {
    sendUnshielded(color, amount, recipient);
  }

  // GOOD — all parameters properly disclosed
  export circuit send(color: Bytes<32>, amount: Uint<128>): [] {
    sendUnshielded(disclose(color), disclose(amount), recipient);
  }
  ```

## Anti-Patterns Table

Quick reference of common token security anti-patterns in Compact contracts.

| Anti-Pattern | Risk | Correct Pattern |
|---|---|---|
| `export circuit mint(amount)` with no auth check | Anyone can mint unlimited tokens, destroying the token's economic model | Add `assert(caller == authority)` or role-based authorization check before minting |
| `balance - amount` without `assert(balance >= amount)` | Underflow wraps to maximum unsigned value in ZK circuits, effectively creating tokens from nothing | Always assert `balance >= amount` before any subtraction on token amounts |
| Missing `receiveShielded(disclose(coin))` in receiving contract | Shielded tokens sent to the contract are permanently lost with no recovery mechanism | Always call `receiveShielded(disclose(coin))` before processing any received shielded coin |
| `if (unshieldedBalance(...) > 0)` in conditional logic | Balance is captured at proof construction time, not execution time; decision is based on stale data | Use `unshieldedBalanceGt` or `unshieldedBalanceLt` stdlib comparison circuits instead |
| `kernel.mintShielded(pk, amount)` directly | Low-level kernel call bypasses stdlib safety checks, proper nonce handling, and coin registration | Use `mintShieldedToken(domainSep, amount, nonce, recipient)` stdlib wrapper which handles all safety concerns |
| Allowance checked but not deducted after spend | Approved spender can drain the entire owner balance with repeated calls using the same approval | Atomically deduct the spent amount from the allowance in the same circuit that performs the transfer |
| `sendImmediateShielded` return value discarded | Change output from partial spend is lost; tokens equal to `coinValue - sentAmount` are destroyed | Capture the return value and process `res.sent` and any change coins |
| Wrong `Uint` width for token operations | Using the wrong `Uint` width for token functions causes type mismatches; `mintShieldedToken` takes `Uint<128>` for value, `mintUnshieldedToken` takes `Uint<64>` for minting | Check the stdlib function signatures for the exact `Uint` width required by each token operation |
| Nullifier derived using `transientHash` | Non-deterministic; same coin produces different nullifiers each time, completely defeating double-spend prevention | Use `persistentHash` with domain separation and secret key for deterministic nullifier derivation |
| `unsafeTransfer` to a contract address | Recipient contract may not call `receiveShielded`, causing permanent token loss | Use safe transfer wrappers that verify recipient handling, or ensure the target contract is known to call `receiveShielded` |

## Tool Reference

| Tool | Description |
|------|-------------|
| `midnight-compile-contract` | Compile contract with hosted compiler. Use `skipZk=true` for syntax validation. |
| `midnight-extract-contract-structure` | Deep structural analysis: token patterns, missing `receiveShielded`, hash function usage. |
| `midnight-analyze-contract` | Static analysis of contract structure and common patterns. |
| `midnight-get-latest-syntax` | Authoritative Compact syntax reference including token operation signatures. |
| `midnight-search-compact` | Semantic search across Compact code for token handling patterns. |
| `midnight-search-docs` | Full-text search across official Midnight documentation. |
| `midnight-list-examples` | List available example contracts with token implementations for reference. |
