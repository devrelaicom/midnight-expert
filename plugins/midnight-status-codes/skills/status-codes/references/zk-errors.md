# ZK Errors Reference

Errors from the zero-knowledge proof system used by Midnight (midnight-zk repo). Covers PLONK proving/verification, ZKIR circuit compilation, IVC aggregation, and dev/test tools. These errors surface during proof generation, proof verification, circuit compilation, or development testing.

## PLONK Errors

Source: `proofs/src/plonk/error.rs`

Primary proof system errors:

| Variant | Display Message | Fixes |
|---------|----------------|-------|
| `Synthesis(String)` | "Synthesis error: {msg}" | Check circuit constraints; witness values may be missing or invalid |
| `InvalidInstances` | "Provided instances do not match the circuit" | Verify instance count and shape match the circuit definition |
| `ConstraintSystemFailure` | "The constraint system is not satisfied" | Circuit constraints are violated; check witness assignments |
| `BoundsFailure` | "An out-of-bounds index was passed to the backend" | Internal error in permutation keygen |
| `Opening` | "Multi-opening proof was invalid" | Proof data may be corrupted; regenerate |
| `Transcript(io::Error)` | "Transcript error: {e}" | I/O error reading/writing proof transcript |
| `NotEnoughRowsAvailable { current_k }` | "k = {k} is too small for the given circuit" | Increase k value; circuit needs more rows |
| `InstanceTooLarge` | "Instance vectors are larger than the circuit" | Reduce instance size or increase circuit capacity |
| `NotEnoughColumnsForConstants` | "Too few fixed columns are enabled for global constants" | Enable more fixed columns in circuit config |
| `ColumnNotInPermutation(Column)` | "Column must be included in the permutation" | Add `meta.enable_equality()` on the column |
| `TableError(TableError)` | Delegates to TableError | See Table Errors below |
| `SrsError(usize, usize)` | "The SRS does not match for the given circuit" | SRS size doesn't match circuit; regenerate keys with correct SRS |
| `CompletenessFailure` | "Completeness failure due to bad luck in random sampling" | Extremely rare; retry the proof generation |

## Table Errors

Source: `proofs/src/plonk/error.rs`

| Variant | Message | Fixes |
|---------|---------|-------|
| `ColumnNotAssigned(TableColumn)` | "{col} not fully assigned. Assign a value at offset 0." | Assign values to all table column rows |
| `UnevenColumnLengths` | "{col} has length {n} while {table} has length {m}" | All columns in a lookup table must have equal length |
| `UsedColumn(TableColumn)` | "{col} has already been used" | Don't reuse table columns |
| `OverwriteDefault(TableColumn, String, String)` | "Attempted to overwrite default value" | Don't assign different values to the same default cell |

## Polynomial Commitment Errors

Source: `proofs/src/poly/mod.rs`

| Variant | Description | Fixes |
|---------|-------------|-------|
| `OpeningError` | Opening proof is not well-formed | Proof data corrupted; regenerate |
| `SamplingError` | Need to re-sample evaluation point | Retry with different randomness |
| `DuplicatedQuery` | Duplicate query to same (commitment, opening) pair | Multiopen argument only supports single query per pair |

## ZKIR Errors

Source: `zkir/src/error.rs`

| Variant | Display | Fixes |
|---------|---------|-------|
| `InvalidArity(Operation)` | "wrong arity: '{op}'" | Operation received wrong number of inputs/outputs |
| `ParsingError(IrType, String)` | "'{s}' cannot be parsed as a {type}" | Value doesn't match expected type (Bool, Native, JubjubScalar) |
| `NotFound(Name)` | "'{s}' not found" | Variable or witness not in memory; check circuit definitions |
| `DuplicatedName(Name)` | "'{s}' already exists" | Variable name collision; rename to avoid shadowing |
| `ExpectingType(IrType, IrType)` | "type {expected} was expected instead of {actual}" | Type mismatch in circuit IR |
| `Unsupported(Operation, Vec<IrType>)` | "{op} is not supported on {types}" | Operation not supported for these types |
| `Other(String)` | Various | Catch-all; check message for specifics |

Common `Other` messages: "invalid length", "cannot convert {x} to Bytes({n})", "underflow subtracting {b} from {a}"

## IVC Errors

Source: `aggregation/src/ivc/error.rs`

| Variant | Display | Fixes |
|---------|---------|-------|
| `ProofGeneration(plonk::Error)` | "proof generation failed: {e}" | Wraps PLONK error; see PLONK errors above |
| `InvalidInstance` | "invalid instance" | IVC instance is malformed |
| `VkMismatch` | "verifying-key mismatch" | VK in instance doesn't match verifier's key; ensure consistent keys |
| `InvalidProof` | "invalid proof" | Accumulator pairing check failed; proof is invalid |
| `TranscriptNotEmpty` | "proof transcript not empty" | Trailing data in proof; may indicate corruption |
| `DeciderFailed` | "decider check failed" | Application-level decider check failed |

## MockProver VerifyFailure

Source: `proofs/src/dev/failure.rs`

Dev/testing infrastructure for debugging circuit issues. All types implement Display/Debug/Error manually — no thiserror.

| Variant | Description | Fixes |
|---------|-------------|-------|
| `CellNotAssigned { gate, region, column, offset }` | Required cell not assigned in region | Assign a value to the cell at the specified offset |
| `InstanceCellNotAssigned { gate, region, column, row }` | Required instance cell not assigned | Provide the instance value at the specified row |
| `ConstraintNotSatisfied { constraint, location }` | Gate constraint evaluates to non-zero | Check constraint logic; review witness assignments |
| `ConstraintPoisoned { constraint }` | Constraint active on unusable row | Missing selector; gate is accidentally enabled |
| `Lookup { name, lookup_index, location }` | Lookup table entry not found | Input value not in the lookup table |
| `Permutation { column, location }` | Equality constraint not satisfied | Values that should be equal aren't; check copy constraints |

### FailureLocation

| Variant | Display |
|---------|---------|
| `InRegion { region, offset }` | "in {region} at offset {offset}" |
| `OutsideRegion { row }` | "outside any region, on row {row}" |

## Other Types

**NotInFieldError** (`curves/src/bls12_381/fq.rs`): Display "Not in field". Returned when a blst_scalar fails the field check.

## Error Conversion Chains

```
zkir::Error  ──From──►  plonk::Error::Synthesis(format!("{error:?}"))
plonk::Error ──From──►  zkir::Error::Other(format!("{error:?}"))
io::Error    ──From──►  plonk::Error::Transcript(error)
plonk::Error ──From──►  IvcError::ProofGeneration(e)
```

The `Relation` trait in zk_stdlib requires `type Error: From<plonk::Error>`, so all relation implementations accept PLONK error conversion.

## Notes

- All error types implement Display, Debug, and Error manually — no thiserror is used in this codebase.
- All errors are Rust enum variants — there are no numeric error codes.
