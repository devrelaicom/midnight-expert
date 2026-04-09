# Midnight Node Error Codes

## Source

These are `LedgerApiError` codes mapped to `u8` (0–255), defined in `midnight-node/ledger/src/versions/common/types.rs`. They surface via Substrate's `InvalidTransaction::Custom(u8)` when the node rejects a transaction at the ledger level.

You encounter them when:
- A submitted transaction is rejected by the node with `Custom(N)` in the Substrate dispatch error
- A pallet-level `DispatchError::Module` surfaces with index 5 (`pallet_midnight`) or 6 (`pallet_midnight_system`) and you need to decode the inner error

---

## Error Tables by Code Range

### Deserialization Errors (0–11)

Group: "Data that couldn't be deserialized from the wire format."

| Code | Name | Description | Fixes |
|------|------|-------------|-------|
| 0 | NetworkId | Failed to deserialize the network ID | Check SDK version compatibility, verify network ID encoding |
| 1 | Transaction | Failed to deserialize transaction payload | Verify transaction was built with a compatible SDK version |
| 2 | LedgerState | Failed to deserialize ledger state | Internal node error — may indicate corrupted state |
| 3 | ContractAddress | Failed to deserialize contract address | Verify the contract address format |
| 4 | PublicKey | Failed to deserialize public key | Check key format and encoding |
| 5 | VersionedArenaKey | Failed to deserialize versioned arena key | Internal — may indicate version mismatch |
| 6 | UserAddress | Failed to deserialize user address | Verify address format |
| 7 | TypedArenaKey | Failed to deserialize typed arena key | Internal — may indicate version mismatch |
| 8 | SystemTransaction | Failed to deserialize system transaction | Governance/bridge transaction format error |
| 9 | DustPublicKey | Failed to deserialize DUST public key | Check DUST key format |
| 10 | CNightGeneratesDustActionType | Failed to deserialize cNIGHT-generates-DUST action type | Internal bridge/observation error |
| 11 | CNightGeneratesDustEvent | Failed to deserialize cNIGHT-generates-DUST event | Internal bridge/observation error |

### Serialization Errors (50–63)

Group: "Data that couldn't be serialized for storage or transmission."

| Code | Name | Description | Fixes |
|------|------|-------------|-------|
| 50 | TransactionIdentifier | Failed to serialize transaction identifier | Internal — report as bug |
| 51 | LedgerState | Failed to serialize ledger state | Internal node error |
| 52 | LedgerParameters | Failed to serialize ledger parameters | Internal node error |
| 53 | ContractAddress | Failed to serialize contract address | Internal — should not normally occur |
| 54 | ContractState | Failed to serialize contract state | Contract state may be corrupted |
| 55 | ContractStateToJson | Failed to serialize contract state to JSON | Contract state format incompatible with JSON serialization |
| 56 | ZswapState | Failed to serialize Zswap state | Internal Zswap error |
| 57 | UnknownType | Failed to serialize an unknown type | Internal — type not recognized |
| 58 | MerkleTreeDigest | Failed to serialize Merkle tree digest | Internal Merkle tree error |
| 59 | VersionedArenaKey | Failed to serialize versioned arena key | Internal |
| 60 | TypedArenaKey | Failed to serialize typed arena key | Internal |
| 61 | CNightGeneratesDustEvent | Failed to serialize cNIGHT-generates-DUST event | Internal bridge error |
| 62 | SystemTransaction | Failed to serialize system transaction | Internal governance error |
| 63 | ArenaHash | Failed to serialize arena hash | Internal |

### Transaction Invalid (100–109, 193–200)

Group: "Transaction was applied to ledger state but rejected by ledger validation rules. The transaction structure is valid, but the state transition it proposes violates a ledger invariant."

| Code | Name | Description | Fixes |
|------|------|-------------|-------|
| 100 | EffectsMismatch | Declared transaction effects don't match the computed effects | Rebuild the transaction — the effects declaration is stale or was computed incorrectly |
| 101 | ContractAlreadyDeployed | A contract already exists at the target address | Use a different contract address or find the existing deployment |
| 102 | ContractNotPresent | Called a contract that doesn't exist at the given address | Verify the contract address; deploy the contract first |
| 103 | Zswap | Zswap-level transaction error (e.g., double-spend, unknown Merkle root) | Check for nullifier reuse, verify coin tree root is current |
| 104 | Transcript | On-chain transcript execution was rejected | Check contract logic; the circuit's on-chain transcript failed |
| 105 | InsufficientClaimable | Not enough NIGHT tokens to claim | Ensure sufficient NIGHT balance for the operation |
| 106 | VerifierKeyNotFound | Verifier key missing for the circuit operation | Deploy the verifier key before calling the circuit |
| 107 | VerifierKeyAlreadyPresent | Verifier key already exists for this operation | The key is already deployed; no action needed |
| 108 | ReplayCounterMismatch | Signed counter doesn't match (replay attack prevention) | Rebuild the transaction with the current replay counter |
| 109 | UnknownError | Unclassified transaction invalid error | Check node logs for details |
| 193 | ReplayProtectionViolation | Transaction violates replay protection (duplicate intent) | This transaction or intent was already submitted |
| 194 | BalanceCheckOutOfBounds | Token balance would overflow or underflow | Verify token amounts don't exceed representable range |
| 195 | InputNotInUtxos | Input references a UTXO that doesn't exist in the set | The coin may already be spent; resync wallet state |
| 196 | DustDoubleSpend | Attempt to spend the same DUST twice | DUST UTXO already consumed; resync dust wallet |
| 197 | DustDeregistrationNotRegistered | Attempting to deregister a DUST address that isn't registered | Verify the DUST address is currently registered |
| 198 | GenerationInfoAlreadyPresent | DUST generation info already exists | Duplicate generation info submission |
| 199 | InvariantViolation | Protocol-level invariant violated (e.g., NIGHT supply exceeded) | Transaction would break fundamental protocol rules |
| 200 | RewardTooSmall | Claimed reward is below the minimum payout threshold | Accumulate more rewards before claiming |

### Transaction Malformed (110–139, 166–192)

Group: "Structural validity errors caught before applying the transaction to ledger state. These indicate the transaction itself is malformed — not that the ledger rejected it after application."

| Code | Name | Description | Fixes |
|------|------|-------------|-------|
| 110 | VerifierKeyNotSet | Contract deployed without required verifier key | Include verifier keys when deploying the contract |
| 111 | TransactionTooLarge | Transaction exceeds maximum allowed size | Reduce transaction payload; split into multiple transactions |
| 112 | VerifierKeyTooLarge | Verifier key exceeds deserialization limit | Use a smaller circuit or contact Midnight support |
| 113 | VerifierKeyNotPresent | Referenced verifier key not found | Deploy the verifier key before calling the circuit |
| 114 | ContractNotPresent | Transaction references a non-existent contract | Verify contract address; deploy the contract first |
| 115 | InvalidProof | Zero-knowledge proof verification failed | Regenerate the proof; ensure proof server is compatible |
| 116 | BindingCommitmentOpeningInvalid | Binding commitment was incorrectly opened | Internal Zswap error — rebuild the transaction |
| 117 | NotNormalized | Transaction is not in normal form | Rebuild with the SDK; transactions must be normalized |
| 118 | FallibleWithoutCheckpoint | Fallible transcript missing initial checkpoint | Add kernel.checkpoint() at the start of fallible sections |
| 119 | ClaimReceiveFailed | Failed to claim a coin commitment receive | Coin commitment format error; rebuild the transaction |
| 120 | ClaimSpendFailed | Failed to claim a coin commitment spend | Coin commitment format error; rebuild the transaction |
| 121 | ClaimNullifierFailed | Failed to claim a nullifier | Nullifier format error; rebuild the transaction |
| 122 | ClaimCallFailed | Failed to claim a contract call | Contract call format error; rebuild the transaction |
| 123 | InvalidSchnorrProof | Fiat-Shamir Schnorr proof verification failed | Signing error — regenerate the transaction signature |
| 124 | UnclaimedCoinCom | Contract-owned output left unclaimed | All contract outputs must be claimed in the transaction |
| 125 | UnclaimedNullifier | Contract-owned coin input left unauthorized | All contract inputs must be authorized |
| 126 | Unbalanced | Negative balance in a token type | Transaction doesn't balance — check token amounts |
| 127 | Zswap | Zswap offer is structurally malformed | Rebuild the Zswap offer; check proof validity |
| 128 | BuiltinDecode | FAB (field-aligned binary) decode error | Internal encoding error; verify data formats |
| 129 | GuaranteedLimit | Exceeded guaranteed section limits | Reduce the guaranteed section size |
| 130 | MergingContracts | Error merging contract intents | Contracts can't be merged in this configuration |
| 131 | CantMergeTypes | Attempted to merge incompatible transaction types | Transaction types must be compatible for merging |
| 132 | ClaimOverflow | Claimed coin value overflows deltas | Token amounts exceed representable range |
| 133 | ClaimCoinMismatch | ClaimRewards coin doesn't match the real coin | Rebuild the claim with correct coin data |
| 134 | KeyNotInCommittee | Signing key is not a committee member | Only committee members can sign this operation |
| 135 | InvalidCommitteeSignature | Committee signature verification failed | Verify the signing key and signature |
| 136 | ThresholdMissed | Committee approval threshold not met | Gather more committee signatures |
| 137 | TooManyZswapEntries | Too many Zswap entries (>=2^16) | Reduce the number of shielded operations |
| 138 | BalanceCheckOverspend | Negative balance in a transaction segment | Segment spends more than available; check amounts |
| 139 | UnknownError | Unclassified malformed transaction error | Check node logs for details |
| 166 | InvalidNetworkId | Transaction's network ID doesn't match the node's network | Verify networkId matches the target (e.g., 'undeployed' for devnet); check setNetworkId() |
| 167 | IllegallyDeclaredGuaranteed | Guaranteed segment (0) used where forbidden | Don't use segment_id 0 for intents |
| 168 | FeeCalculation | Fee calculation error | Transaction size or timing parameters are invalid |
| 169 | InvalidDustRegistrationSignature | DUST registration signature verification failed | Regenerate DUST registration with correct keys |
| 170 | InvalidDustSpendProof | DUST spend proof verification failed | Regenerate DUST spend proof |
| 171 | OutOfDustValidityWindow | DUST outside its validity time window | DUST creation time is outside the allowed window; use fresher DUST |
| 172 | MultipleDustRegistrationsForKey | Multiple DUST registrations for same key in one intent | Only one DUST registration per key per intent |
| 173 | InsufficientDustForRegistrationFee | Not enough DUST to pay registration fee | Acquire more DUST before registering |
| 174 | MalformedContractDeploy | Contract deployment is structurally invalid | Check for non-zero balance or incorrect charged state in deploy |
| 175 | IntentSignatureVerificationFailure | Intent signature verification failed | Regenerate intent signatures |
| 176 | IntentSignatureKeyMismatch | Signing key doesn't match verifying key | Use the correct signing key for the intent |
| 177 | IntentSegmentIdCollision | Duplicate segment_id in intent merge | Each intent must have a unique segment_id |
| 178 | IntentAtGuaranteedSegmentId | Intent placed at segment_id 0 (reserved for guaranteed) | Use segment_id >= 1 for intents |
| 179 | UnsupportedProofVersion | Proof version not supported | Update SDK/proof server to a compatible version |
| 180 | GuaranteedTranscriptVersion | Guaranteed transcript version not supported | Update to a compatible ledger/SDK version |
| 181 | FallibleTranscriptVersion | Fallible transcript version not supported | Update to a compatible ledger/SDK version |
| 182 | TransactionApplicationError | Intent TTL expired, too far in future, or duplicate | Check intent timing; avoid resubmitting same intent |
| 183 | BalanceCheckOutOfBounds | Balance overflow/underflow in a segment | Token amounts in a segment exceed representable range |
| 184 | BalanceCheckConversionFailure | Failed to convert balance to i128 | Token amount too large for internal representation |
| 185 | PedersenCheckFailure | Binding commitment mismatch | Internal cryptographic error — rebuild the transaction |
| 186 | EffectsCheckFailure | Transaction effects validation failed | Declared effects don't match computed effects |
| 187 | DisjointCheckFailure | Input/output sets are not disjoint | Shielded and transient inputs/outputs must not overlap |
| 188 | SequencingCheckFailure | Call graph sequencing violated | Contract calls must respect ordering constraints |
| 189 | InputsNotSorted | Unshielded inputs are not sorted | Sort unshielded inputs before submission |
| 190 | OutputsNotSorted | Unshielded outputs are not sorted | Sort unshielded outputs before submission |
| 191 | DuplicateInputs | Duplicate unshielded inputs | Remove duplicate inputs from the transaction |
| 192 | InputsSignaturesLengthMismatch | Input count doesn't match signature count | Ensure each input has a corresponding signature |

### Infrastructure Errors (150–155, 165)

Group: "Node infrastructure errors not directly related to transaction content."

| Code | Name | Description | Fixes |
|------|------|-------------|-------|
| 150 | LedgerCacheError | Ledger cache mutex/lock poisoned | Restart the node; this is an internal concurrency error |
| 151 | NoLedgerState | No ledger state present in the node | Node may not be fully synced; wait for sync to complete |
| 152 | LedgerStateScaleDecodingError | SCALE decoding of ledger state failed | Node state may be corrupted; try resyncing |
| 153 | ContractCallCostError | Failed to calculate contract call cost | Internal cost model error |
| 154 | BlockLimitExceededError | Transaction exceeds block limits | Reduce transaction size or wait for a less congested block |
| 155 | FeeCalculationError | Fee calculation failed | Internal fee model error |
| 165 | GetTransactionContextError | Failed to retrieve transaction context | Internal node error |

### System Transaction Errors (201–210)

Group: "Errors from governance and bridge system transactions. These are special transactions submitted by the network's governance mechanisms."

| Code | Name | Description | Fixes |
|------|------|-------------|-------|
| 201 | IllegalPayout | Payout exceeds remaining supply or bridge pool | Payout amount is too large for available funds |
| 202 | InsufficientTreasuryFunds | Treasury doesn't have enough funds | Requested amount exceeds treasury balance |
| 203 | CommitmentAlreadyPresent | Faerie-gold double-commitment attempt | Commitment already exists in the tree |
| 204 | UnknownError | Unclassified system transaction error | Check node logs |
| 205 | ReplayProtectionFailure | System transaction replay protection violated | Duplicate system transaction |
| 206 | IllegalReserveDistribution | Reserve distribution exceeds supply | Distribution amount exceeds available reserves |
| 207 | GenerationInfoAlreadyPresent | DUST generation info already inserted | Duplicate generation info |
| 208 | InvalidBasisPoints | Bridge fee basis points >= 10,000 | Basis points must be between 0 and 9,999 |
| 209 | InvariantViolation | Protocol-level invariant violated | Transaction would break fundamental protocol rules |
| 210 | TreasuryDisabled | Attempted to access disabled treasury | Treasury feature is not enabled |

### Host API Error (255)

| Code | Name | Description | Fixes |
|------|------|-------------|-------|
| 255 | HostApiError | Error in host API processing | Internal runtime error; check node logs |

### Reserved Ranges

The following code ranges are currently unassigned and reserved for future use:

- 12–49 (between deserialization and serialization)
- 64–99 (between serialization and transaction errors)
- 140–149 (gap in malformed transaction range, originally between old and new malformed errors)
- 156–164 (between infrastructure and new malformed errors)
- 211–254 (between system transaction and host API)

---

## Pallet Dispatch Errors

When a transaction fails inside a Substrate pallet, the error surfaces as `DispatchError::Module { index, error }`. The `index` identifies the pallet and `error` is the SCALE-encoded variant index within that pallet's error enum.

### Pallet Index Map

| Index | Pallet | Description |
|-------|--------|-------------|
| 5 | pallet_midnight | Core Midnight ledger pallet |
| 6 | pallet_midnight_system | System transaction pallet |
| 13 | pallet_cnight_observation | cNIGHT bridge observation |
| 44 | pallet_federated_authority | Governance authority |
| 45 | pallet_federated_authority_observation | Authority observation |
| 50 | pallet_system_parameters | System parameters |
| 51 | pallet_throttle | Transaction throttling |

### pallet_midnight (index 5)

| Variant | Name | Description |
|---------|------|-------------|
| 0 | NewStateOutOfBounds | New ledger state is out of acceptable bounds |
| 1 | Deserialization | Wraps DeserializationError (codes 0–11) |
| 2 | Serialization | Wraps SerializationError (codes 50–63) |
| 3 | Transaction | Wraps TransactionError (codes 100–210) |
| 4 | LedgerCacheError | Ledger cache poisoned (code 150) |
| 5 | NoLedgerState | No ledger state (code 151) |
| 6 | LedgerStateScaleDecodingError | SCALE decode failure (code 152) |
| 7 | ContractCallCostError | Cost calculation failure (code 153) |
| 8 | BlockLimitExceededError | Block limit exceeded (code 154) |
| 9 | FeeCalculationError | Fee calculation failure (code 155) |
| 10 | HostApiError | Host API error (code 255) |
| 11 | NetworkIdNotString | Network ID not a valid string |
| 12 | GetTransactionContextError | Transaction context retrieval error (code 165) |

### pallet_midnight_system (index 6)

| Variant | Name | Description |
|---------|------|-------------|
| 0 | LedgerApiError | Wraps full LedgerApiError |
| 1 | SystemTransactionNotAllowedForGovernance | Governance-disallowed system transaction |

### pallet_federated_authority (index 44)

| Variant | Name | Description |
|---------|------|-------------|
| 0 | MotionAlreadyApproved | Authority already approved this motion |
| 1 | MotionApprovalMissing | Approver not in the approval list |
| 2 | MotionApprovalExceedsBounds | Exceeds maximum authority bodies |
| 3 | MotionNotFound | Motion does not exist |
| 4 | MotionNotEnded | Motion voting not yet complete |
| 5 | MotionHasEnded | Motion ended; no more changes allowed |
| 6 | MotionTooEarlyToClose | Approval period hasn't ended yet |
| 7 | MotionAlreadyExists | Motion already exists |
| 8 | MotionExpired | Motion expired without enough approvals |
| 9 | MotionWeightBoundTooLow | Weight bound too low for the call |

### pallet_cnight_observation (index 13)

| Variant | Name | Description |
|---------|------|-------------|
| 0 | MaxCardanoAddrLengthExceeded | Cardano wallet address too long |
| 1 | MaxRegistrationsExceeded | Too many registrations |
| 2 | LedgerApiError | Wraps LedgerApiError |
| 3 | InherentAlreadyExecuted | Only one inherent call per block |
| 4 | CardanoPositionRegression | Next Cardano position doesn't advance |
| 5 | TooManyUtxos | UTXO count exceeds capacity |

### pallet_federated_authority_observation (index 45)

| Variant | Name | Description |
|---------|------|-------------|
| 0 | EmptyMembers | Membership set is empty |
| 1 | DuplicatedMembers | Duplicate members in the set |
| 2 | InherentAlreadyExecuted | Only one inherent call per block |

### pallet_system_parameters (index 50)

| Variant | Name | Description |
|---------|------|-------------|
| 0 | UrlTooLong | URL exceeds maximum allowed length |

---

## JSON-RPC Error Codes

The Midnight node uses standard JSON-RPC 2.0 error codes from the `jsonrpsee` crate.

| Code | Name | Used In | Description |
|------|------|---------|-------------|
| -32602 | INVALID_PARAMS | State RPC, Block RPC, Events, Peer Info | Bad contract address, account address, block hash, peer ID, or other invalid parameter |
| -32603 | INTERNAL_ERROR | Peer Info RPC, System Parameters RPC | Failed to send/receive internal requests, runtime API failures |

---

## Standard InvalidTransaction Variants

These are Substrate-level transaction rejection reasons used by the Midnight node:

| Variant | Context | Description |
|---------|---------|-------------|
| `Custom(u8)` | pallet_midnight | Maps all LedgerApiError codes (0–255) — see tables above |
| `Call` | GovernanceAuthorityCallFilter | Call is not whitelisted; only Council, TechnicalCommittee, FederatedAuthority, and System::apply_authorized_upgrade are allowed |
| `ExhaustsResources` | pallet_throttle | Per-account rolling window limits exceeded (MaxBytes or MaxTxs) |
