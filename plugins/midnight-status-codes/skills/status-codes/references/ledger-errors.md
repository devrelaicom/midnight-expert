# Ledger Errors Reference

## Source

These errors are defined in the **midnight-ledger** crate and represent the full taxonomy of transaction validation, execution, and state management errors. They are the Rust-level details behind the numeric `LedgerApiError` codes surfaced by the node.

**Important implementation notes:**
- No `thiserror` is used in the core ledger crate. Only the proof-server crate uses `thiserror`.
- `ProvingError` and `VerifyingError` are opaque `anyhow::Error` type aliases — their inner causes are not directly inspectable.
- All primary error enums are marked `#[non_exhaustive]`, meaning new variants may be added in future versions.

## Error Hierarchy

The full chain from top-level to low-level:

```
MalformedTransaction
  └─ wraps zswap::MalformedOffer
       └─ wraps TranscriptRejected
            └─ wraps OnchainProgramError
                 └─ wraps InvalidBuiltinDecode
                      └─ wraps merkle_tree::InvalidUpdate
```

Understanding this chain is essential when reading nested error output. A `MalformedTransaction::InvalidProof` error near the top of a chain may trace back to a deep `OnchainProgramError::Decode` inside a contract transcript execution.

---

## Error Types

### 1. MalformedTransaction\<D\>

`#[non_exhaustive]` — 50+ variants. Structural validity errors that are checked **before** any state application. If a transaction is malformed, it is rejected without touching the ledger state.

#### Proof and Cryptographic Errors

| Variant | Description | Fix |
|---------|-------------|-----|
| `InvalidNetworkId` | The transaction was built for a different network (e.g., mainnet vs. devnet). | Rebuild the transaction targeting the correct network ID. |
| `InvalidProof` | A zero-knowledge proof failed verification. | Reproving required; check that the witness and public inputs match. |
| `BindingCommitmentOpeningInvalid` | The binding commitment opening does not match the committed value. | Indicates a bug in transaction construction; recheck commitment generation. |
| `InvalidSchnorrProof` | A Schnorr signature proof failed verification. | Key mismatch or corrupted signing data; re-sign. |
| `PedersenCheckFailure` | A Pedersen commitment consistency check failed. | Balance or value encoding error; recheck transaction values. |

#### Structural Errors

| Variant | Description | Fix |
|---------|-------------|-----|
| `NotNormalized` | Transaction fields are not in the required canonical/sorted order. | Sort and normalize transaction fields per the ledger spec before submitting. |
| `FallibleWithoutCheckpoint` | A fallible transaction segment was submitted without a required checkpoint. | Add a checkpoint to the fallible segment. |
| `TransactionTooLarge` | The serialized transaction exceeds the maximum allowed byte size. | Split into smaller transactions or reduce payload size. |
| `VerifierKeyTooLarge` | A verifier key embedded in the transaction exceeds the size limit. | Check that the correct (non-debug) verifier key is being used. |
| `TooManyZswapEntries` | The transaction contains more zswap entries than the protocol allows. | Split zswap operations across multiple transactions. |

#### Claims Errors

| Variant | Description | Fix |
|---------|-------------|-----|
| `ClaimReceiveFailed` | A coin receive claim is invalid or cannot be verified. | Check that the claim data matches the coin being received. |
| `ClaimSpendFailed` | A coin spend claim failed verification. | Verify the spend authorization and nullifier data. |
| `ClaimNullifierFailed` | The nullifier in a claim is invalid or does not match. | Regenerate the nullifier from the correct key and coin data. |
| `UnclaimedCoinCom` | A coin commitment is present but has no corresponding claim. | Ensure every coin commitment has a valid associated claim. |
| `UnclaimedNullifier` | A nullifier is present but has no corresponding coin claim. | Ensure every nullifier has a corresponding spend claim. |
| `Unbalanced` | The transaction inputs and outputs do not balance (value is not conserved). | Recheck token amounts across all inputs and outputs. |
| `ClaimOverflow` | Arithmetic overflow occurred while summing claim values. | Reduce individual claim values; total may exceed `u64::MAX`. |
| `ClaimCoinMismatch` | The coin referenced in a claim does not match the expected coin. | Ensure the claim is constructed against the correct coin data. |

#### Committee Errors

| Variant | Description | Fix |
|---------|-------------|-----|
| `KeyNotInCommittee` | A key used for signing is not a member of the expected committee. | Use a key that is a registered committee member for this epoch. |
| `InvalidCommitteeSignature` | A committee signature is malformed or does not verify. | Re-collect signatures from valid committee members. |
| `ThresholdMissed` | The required threshold of committee signatures was not reached. | Gather signatures from more committee members before submitting. |

#### Intents Errors

| Variant | Description | Fix |
|---------|-------------|-----|
| `IntentSignatureVerificationFailure` | An intent's signature failed verification. | Re-sign the intent with the correct key. |
| `IntentSignatureKeyMismatch` | The signing key does not match the key declared in the intent. | Ensure the intent is signed with the key it references. |
| `IntentSegmentIdCollision` | Two intents reference the same segment ID, causing a collision. | Assign unique segment IDs to each intent. |
| `IntentAtGuaranteedSegmentId` | An intent was placed at a guaranteed segment ID, which is not permitted. | Move the intent to a non-guaranteed segment. |

#### Balance Check Errors

| Variant | Description | Fix |
|---------|-------------|-----|
| `BalanceCheckOutOfBounds` | A balance value is outside the valid numeric range for the check. | Verify that all token amounts are within protocol-defined bounds. |
| `BalanceCheckConversionFailure` | Type conversion failed during balance verification. | Indicates a bug in value encoding; check token type consistency. |
| `BalanceCheckOverspend` | The transaction attempts to spend more than is available. | Reduce spend amounts or add sufficient inputs. |

#### Dust Errors

| Variant | Description | Fix |
|---------|-------------|-----|
| `InvalidDustRegistrationSignature` | The dust registration signature is invalid. | Re-sign the dust registration with the correct key. |
| `InvalidDustSpendProof` | The proof for a dust spend is invalid. | Regenerate the spend proof with correct witness data. |
| `OutOfDustValidityWindow` | The dust registration or spend is outside the allowed validity window. | Check block height and resubmit within the validity window. |
| `MultipleDustRegistrationsForKey` | The same key appears in multiple dust registrations in one transaction. | Use each dust key at most once per transaction. |
| `InsufficientDustForRegistrationFee` | The dust amount is below the minimum required to cover the registration fee. | Increase the dust amount to meet the minimum fee threshold. |

#### Version Errors

| Variant | Description | Fix |
|---------|-------------|-----|
| `UnsupportedProofVersion` | The proof uses a version the node does not support. | Upgrade the SDK or reproduce the proof with a supported version. |
| `GuaranteedTranscriptVersion` | The transcript version is invalid for a guaranteed segment. | Ensure guaranteed segments use the correct transcript version format. |
| `FallibleTranscriptVersion` | The transcript version is invalid for a fallible segment. | Ensure fallible segments use the correct transcript version format. |

#### Check Errors

| Variant | Description | Fix |
|---------|-------------|-----|
| `EffectsCheckFailure` | The declared effects of the transaction failed static consistency checks. | Verify that declared effects match what the contract execution would actually produce. |
| `DisjointCheckFailure` | Segments that should be disjoint share resources or state. | Ensure segments operate on non-overlapping state. |
| `SequencingCheckFailure` | Segment ordering constraints were violated. | Reorder segments to satisfy sequencing requirements. |

#### Sorting and Deduplication Errors

| Variant | Description | Fix |
|---------|-------------|-----|
| `InputsNotSorted` | Transaction inputs are not in the required canonical sort order. | Sort inputs according to the ledger's canonical ordering before building the transaction. |
| `OutputsNotSorted` | Transaction outputs are not in the required canonical sort order. | Sort outputs canonically before building the transaction. |
| `DuplicateInputs` | The same input appears more than once in the transaction. | Remove duplicate inputs. |
| `InputsSignaturesLengthMismatch` | The number of input signatures does not match the number of inputs. | Provide exactly one signature per input. |

---

### 2. TransactionInvalid\<D\>

`#[non_exhaustive]` — 19 variants. State-application failures that occur when a structurally valid transaction is applied to the current ledger state and is rejected due to state inconsistencies.

| Variant | Description | Fix |
|---------|-------------|-----|
| `EffectsMismatch` | The actual effects of applying the transaction differ from the declared effects. | The declared effects must exactly match what contract execution produces. |
| `ContractAlreadyDeployed` | A contract deployment targets an address that already has a contract. | Deploy to a different address or check deployment uniqueness. |
| `ContractNotPresent` | A transaction calls a contract that does not exist at the given address. | Verify the contract address and ensure the contract is deployed. |
| `Zswap` | A zswap sub-operation failed (wraps `zswap::TransactionInvalid`). | See Zswap errors section for details. |
| `Transcript` | A contract transcript execution was rejected (wraps `TranscriptRejected`). | See `TranscriptRejected` errors for details. |
| `InsufficientClaimable` | The transaction attempts to claim more than is available in the claimable pool. | Reduce the claim amount or wait for more claimable funds to become available. |
| `VerifierKeyNotFound` | A verifier key referenced in the transaction is not registered on-chain. | Register the verifier key before submitting transactions that reference it. |
| `VerifierKeyAlreadyPresent` | A verifier key registration targets a key that is already registered. | Do not re-register existing verifier keys. |
| `ReplayCounterMismatch` | The replay protection counter does not match the expected value. | Fetch the current replay counter from the node and use it in the transaction. |
| `ReplayProtectionViolation` | The transaction violates replay protection constraints. | Ensure the transaction is not a duplicate or out-of-sequence. |
| `BalanceCheckOutOfBounds` | A balance value is out of valid range during state application. | Verify token amounts are within bounds after accounting for current state. |
| `InputNotInUtxos` | A transaction input references a UTXO that does not exist in the current state. | The UTXO may have already been spent; fetch fresh state before building the transaction. |
| `DustDoubleSpend` | A dust coin is being spent that has already been spent. | Check current dust UTXO state; the coin has already been consumed. |
| `DustDeregistrationNotRegistered` | Attempting to deregister a dust key that is not currently registered. | Verify that the key is actually registered before deregistering. |
| `GenerationInfoAlreadyPresent` | Generation info for this epoch/key is already recorded on-chain. | Generation info can only be submitted once per epoch. |
| `InvariantViolation` | An internal ledger invariant was violated. This is typically a bug. | Report as a bug; this should not occur with a correctly implemented node or SDK. |
| `RewardTooSmall` | The reward amount is below the minimum required. | Increase the reward amount to meet the protocol minimum. |
| `DivideByZero` | A division by zero was encountered during transaction processing. | Indicates a bug in transaction value computation. |
| `MerkleTreeError` | A Merkle tree operation failed during state application. | See `merkle_tree::InvalidUpdate` for specific sub-errors. |

---

### 3. OnchainProgramError\<D\>

17 variants — the Impact VM (onchain execution engine) errors. These are surfaced when contract transcript execution fails inside the VM.

| Variant | Description |
|---------|-------------|
| `RanOffStack` | The VM stack was exhausted; a pop or read was attempted on an empty stack. |
| `RanPastProgramEnd` | The program counter advanced past the end of the bytecode. |
| `ExpectedCell` | A cell value was expected at a stack position but a different type was found. |
| `Decode` | Failed to decode a value from the stack or program data (wraps `InvalidBuiltinDecode`). |
| `ArithmeticOverflow` | An arithmetic operation overflowed the supported integer range. |
| `TooLongForEqual` | An equality comparison was attempted on values exceeding the maximum comparable length. |
| `TypeError(String)` | A type mismatch occurred during VM execution. The string describes the mismatch. |
| `OutOfGas` | The transaction ran out of gas during contract execution. |
| `BoundsExceeded` | An array or buffer access was attempted out of bounds. |
| `LogBoundExceeded` | A logging operation exceeded the maximum allowed log size. |
| `InvalidArgs` | A built-in function was called with invalid or wrong-count arguments. |
| `MissingKey` | A required key was not found in the contract state map. |
| `CacheMiss` | A cache lookup for a required value returned no result during execution. |
| `AttemptedArrayDelete` | An attempt was made to delete an array element, which is not supported. |
| `ReadMismatch` | A read from contract state returned a value that does not match the expected value declared in the transcript. |
| `CellBoundExceeded` | A cell value exceeded the maximum allowed size. |
| `StackOverflow` | The VM call stack grew too deep, exceeding the recursion limit. |
| `MerkleTreeError` | A Merkle tree built-in operation failed inside the VM. |

---

### 4. TranscriptRejected\<D\>

5 variants. Wraps `OnchainProgramError` and represents failures during onchain contract execution.

| Variant | Description |
|---------|-------------|
| `Execution` | Contract execution failed (wraps `OnchainProgramError`). The inner error contains the VM-level failure. |
| `Decode` | Failed to decode the transcript input before execution could begin. |
| `FinalStackWrongLength` | After execution completed, the stack did not have the expected number of elements. |
| `WeakStateReturned` | The contract returned a weakened/reduced state when a full state was required. |
| `EffectDecodeError` | Failed to decode the effects emitted by the contract execution. |

---

### 5. Zswap Errors

Zswap manages private coin operations (shielded transfers, nullifiers, commitments).

#### zswap::TransactionInvalid

State-level zswap failures:

| Variant | Description | Fix |
|---------|-------------|-----|
| `NullifierAlreadyPresent` | The nullifier has already been spent; this is a double-spend attempt. | The coin has been spent; do not attempt to spend it again. |
| `CommitmentAlreadyPresent` | A coin commitment already exists in the commitment tree. | Duplicate commitment; check for replay or construction error. |
| `UnknownMerkleRoot` | The Merkle root referenced in the proof is not known to the current state. | Fetch the current Merkle root from the node and rebuild the proof. |
| `MerkleTreeError` | A Merkle tree update failed during zswap state application. | See `merkle_tree::InvalidUpdate` for details. |

#### zswap::MalformedOffer

Structural zswap errors:

| Variant | Description | Fix |
|---------|-------------|-----|
| `InvalidProof` | A zswap zero-knowledge proof failed verification. | Regenerate the proof with correct witness and public inputs. |
| `ContractSentCiphertext` | A contract attempted to send ciphertext, which is not permitted in this context. | Contracts must not produce ciphertext outputs directly. |
| `NonDisjointCoinMerge` | A coin merge attempted to combine non-disjoint coin sets. | Ensure merged coin sets are fully disjoint. |
| `NotNormalized` | The offer is not in canonical normalized form. | Normalize the offer before inclusion in a transaction. |

#### zswap::OfferCreationFailed

Errors during offer construction (client-side):

| Variant | Description | Fix |
|---------|-------------|-----|
| `InvalidIndex` | An invalid index was used when constructing the offer. | Verify the coin index is within the valid range for the Merkle tree. |
| `Proving` | The zero-knowledge proving step failed during offer creation. | Check that all witnesses are valid; re-run proving with correct inputs. |
| `NotContractOwned` | The offer references a coin that is not owned by the expected contract. | Ensure you are constructing offers only for coins owned by the correct contract. |
| `TreeNotRehashed` | The Merkle tree has not been rehashed after recent updates. | Call the tree rehash operation before constructing the offer. |
| `MerkleTreeError` | A Merkle tree operation failed during offer construction. | See `merkle_tree::InvalidUpdate` for details. |

---

### 6. Merkle Tree Errors

#### merkle_tree::InvalidIndex

| Variant | Description |
|---------|-------------|
| `InvalidIndex(u64)` | The provided index `u64` is out of range for the current Merkle tree size. |

#### merkle_tree::InvalidUpdate

6 variants representing structural failures when updating the Merkle tree:

| Variant | Description |
|---------|-------------|
| `CollapsedIndex` | An update was attempted on a collapsed (pruned) subtree node. |
| `StubUpdate` | An update targeted a stub node that cannot be updated. |
| `EndBeforeStart` | The end index of an update range is before the start index. |
| `EndOutOfTree` | The end index of an update range extends past the tree boundary. |
| `WrongNumberOfSegments` | The update provides a different number of segments than expected. |
| `NotFullyRehashed` | The tree has pending updates that have not been rehashed yet; the tree is in an inconsistent state. |
| `BadUpdatePath` | The Merkle path provided for the update is incorrect or inconsistent. |

---

### 7. Other Important Types

#### FeeCalculationError

Errors that occur during fee computation before transaction submission.

| Variant | Description |
|---------|-------------|
| `Overflow` | Fee arithmetic overflowed during calculation. |
| `DivisionByZero` | Fee rate calculation encountered a zero denominator. |
| `InvalidFeeRate` | The fee rate is outside the valid protocol range. |

#### MalformedContractDeploy

Errors specific to contract deployment transactions, checked before state application.

| Variant | Description |
|---------|-------------|
| `InvalidContractAddress` | The contract address does not match the hash of the contract code. |
| `InvalidInitialState` | The initial contract state fails validation checks. |
| `MissingVerifierKey` | A verifier key required by the contract is not included in the deployment. |

#### SystemTransactionError

10 variants covering errors in protocol-level system transactions (epoch transitions, committee updates, etc.):

| Variant | Description |
|---------|-------------|
| `InvalidEpoch` | The system transaction targets an incorrect epoch number. |
| `InvalidCommittee` | The committee set in the system transaction is invalid. |
| `MissingSignature` | A required protocol-level signature is absent. |
| `InvalidSignature` | A protocol-level signature failed verification. |
| `DuplicateEntry` | A duplicate entry was found in the system transaction data. |
| `ThresholdNotMet` | The signature threshold was not reached for the system transaction. |
| `InvalidTimestamp` | The timestamp in the system transaction is out of the valid range. |
| `WrongTransactionType` | A non-system transaction was submitted where a system transaction was required, or vice versa. |
| `InvalidReward` | The reward distribution in the system transaction is invalid. |
| `StateTransitionError` | The proposed state transition is invalid given the current protocol state. |

#### TransactionResult

The outcome type returned after transaction processing:

| Variant | Description |
|---------|-------------|
| `Success` | All segments executed successfully and all effects were applied. |
| `PartialSuccess` | Guaranteed segments succeeded but one or more fallible segments failed. The guaranteed effects are applied; fallible effects are discarded. |
| `Failure` | The transaction was rejected entirely (typically due to `MalformedTransaction` or guaranteed segment failure). No state changes are applied. |

#### TransactionConstructionError

Client-side errors encountered while building a transaction before submission:

| Variant | Description |
|---------|-------------|
| `InsufficientFunds` | The wallet does not have enough spendable funds to cover the transaction and fee. |
| `NoSuitableCoins` | No coins of the required type/denomination are available. |
| `ProofGenerationFailed` | The client-side proof generation step failed. |
| `InvalidRecipient` | The recipient address is malformed or unsupported. |
| `SerializationError` | Failed to serialize the transaction for submission. |

#### TransactionProvingError

Errors during the proving phase (proof-server interaction). Note that `ProvingError` is an opaque `anyhow::Error` alias.

| Variant | Description |
|---------|-------------|
| `ProvingError` | An opaque error from the proving backend. The inner `anyhow::Error` may contain more detail in logs. |
| `WitnessGenerationFailed` | Failed to generate the witness required for proving. |
| `CircuitNotFound` | The required proving circuit is not available to the proof server. |
| `Timeout` | The proving operation timed out. |

#### EventReplayError

Errors encountered during event log replay (used for syncing wallet state from on-chain events):

| Variant | Description |
|---------|-------------|
| `DecodeError` | An event could not be decoded from its on-chain representation. |
| `MissingEvent` | An expected event was not found in the log at the expected block height. |
| `StateInconsistency` | Replaying events produced a state that is inconsistent with the known chain state. |
| `UnknownEventType` | An event type was encountered that this client version does not understand. |

#### DustSpendError

Errors during dust coin spend operations:

| Variant | Description |
|---------|-------------|
| `NotRegistered` | The dust key is not currently registered; cannot spend. |
| `InvalidProof` | The dust spend proof failed verification. |
| `OutOfWindow` | The spend is outside the validity window for this dust registration. |
| `AlreadySpent` | The dust coin has already been spent. |

#### DustLocalStateError

Errors in local dust state management (client-side):

| Variant | Description |
|---------|-------------|
| `KeyNotFound` | The dust key is not found in local state. |
| `RegistrationExpired` | The stored dust registration has expired. |
| `CorruptedState` | Local dust state data is corrupted and cannot be read. |

---

## Cross-Reference: Rust Error to Node Error Code

When debugging a node error code (see `node-errors.md`), the underlying Rust error can be found by:

1. Looking up the numeric `LedgerApiError` code in `node-errors.md` to find the high-level category.
2. Checking the node's structured error response body — the Rust error type is often serialized as a string in the `detail` or `cause` field.
3. Matching the Rust type name against the tables in this file.

Common mappings:
- Node error `4000` (MalformedTransaction) → `MalformedTransaction<D>` variants in section 1 above.
- Node error `4001` (TransactionInvalid) → `TransactionInvalid<D>` variants in section 2 above.
- Node error `4002` (ContractError) → `OnchainProgramError<D>` or `TranscriptRejected<D>` variants.
- Node error `4003` (ZswapError) → Zswap error variants in section 5 above.
