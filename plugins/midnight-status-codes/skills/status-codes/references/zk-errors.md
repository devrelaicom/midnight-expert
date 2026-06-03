# ZK Errors Reference

> **Last verified:** 2026-06-02 against `midnightntwrk/midnight-zk@main`. The current directory layout is `aggregation/`, `circuits/`, `curves/`, `proofs/`, `zk_stdlib/` — **the `zkir/` Rust crate has been removed from `main`** (and the old `next` branch no longer exists). The "ZKIR Errors" Rust-crate section that previously appeared here has been dropped accordingly.
>
> **Note:** the removed `zkir/` *Rust crate* is unrelated to the `@midnight-ntwrk/zkir-v2` *npm package* (the WASM PLONK checker used by midnight-verify and the Compact toolchain), which is unaffected and still published (2.1.0). It is also unrelated to the Compact compiler's internal `zkir` pass (see compiler-errors.md).

Errors from the zero-knowledge proof system used by Midnight (midnight-zk repo). Covers PLONK proving/verification, IVC aggregation, and dev/test tools. These errors surface during proof generation, proof verification, or development testing.

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
| `NotEnoughRowsAvailable { current_k }` | "k = {current_k} is too small for the given circuit. Try using a larger value of k" | Increase k value; circuit needs more rows |
| `InstanceTooLarge` | "Instance vectors are larger than the circuit" | Reduce instance size or increase circuit capacity |
| `NotEnoughColumnsForConstants` | "Too few fixed columns are enabled for global constants usage" | Enable more fixed columns in circuit config |
| `ColumnNotInPermutation(Column)` | "Column {column:?} must be included in the permutation. Help: try applying \`meta.enable_equalty\` on the column" *(note upstream typo: source says `enable_equalty`, missing an `i`; the actual API method is `enable_equality()`)* | Add `meta.enable_equality()` on the column |
| `TableError(TableError)` | Delegates to TableError | See Table Errors below |
| `SrsError(usize, usize)` | "The SRS (with size {srs_k}) does not match for the given circuit (of size {circuit_k})" | SRS size doesn't match circuit; regenerate keys with correct SRS |
| `CompletenessFailure` | "Completeness failure due to bad luck in random sampling. This error is expected to be almost impossible to trigger." | Extremely rare; retry the proof generation |

## Table Errors

Source: `proofs/src/plonk/error.rs`

| Variant | Message | Fixes |
|---------|---------|-------|
| `ColumnNotAssigned(TableColumn)` | "{col:?} not fully assigned. Help: assign a value at offset 0." *(`{col:?}` is the column's Debug repr, e.g. `TableColumn { inner: Column { index: 0, column_type: Fixed } }`)* | Assign values to all table column rows |
| `UnevenColumnLengths` | "{col:?} has length {col_len} while {table:?} has length {table_len}" | All columns in a lookup table must have equal length |
| `UsedColumn(TableColumn)` | "{col:?} has already been used" | Don't reuse table columns |
| `OverwriteDefault(TableColumn, String, String)` | "Attempted to overwrite default value {default} with {val} in {col:?}" | Don't assign different values to the same default cell |

## Polynomial Commitment Errors

Source: `proofs/src/poly/mod.rs`

| Variant | Description | Fixes |
|---------|-------------|-------|
| `OpeningError` | Opening proof is not well-formed | Proof data corrupted; regenerate |
| `SamplingError` | Need to re-sample evaluation point | Retry with different randomness |
| `DuplicatedQuery` | Duplicate query to same (commitment, opening) pair | Multiopen argument only supports single query per pair |

## IVC Errors

Source: `aggregation/src/ivc/error.rs`

| Variant | Display | Fixes |
|---------|---------|-------|
| `ProofGeneration(plonk::Error)` | "proof generation failed: {e}" | Wraps PLONK error; see PLONK errors above |
| `InvalidInstance` | "invalid instance" | IVC instance is malformed |
| `InvalidWitness(String)` | "invalid witness: {msg}" | The witness supplied to the IVC step is invalid; check the message for specifics |
| `VkMismatch` | "verifying-key mismatch" | VK in instance doesn't match verifier's key; ensure consistent keys |
| `InvalidProof` | "invalid proof" | Accumulator pairing check failed; proof is invalid |
| `TranscriptNotEmpty` | "proof transcript not empty" | Trailing data in proof; may indicate corruption |
| `DeciderFailed` | "decider check failed" | Application-level decider check failed |

## MockProver VerifyFailure

Source: `proofs/src/dev/failure.rs`

Dev/testing infrastructure for debugging circuit issues. All types implement Display/Debug/Error manually — no thiserror.

| Variant | Description | Fixes |
|---------|-------------|-------|
| `CellNotAssigned { gate, region, gate_offset, column, offset }` | Display: "{region} uses {gate} at offset {gate_offset}, which requires cell in column {column:?} at offset {offset} with annotation {…} to be assigned." | Assign a value to the cell at the specified offset |
| `InstanceCellNotAssigned { gate, region, gate_offset, column, row }` | Required instance cell not assigned | Provide the instance value at the specified row |
| `ConstraintNotSatisfied { constraint, location, cell_values }` | Gate constraint evaluates to non-zero. `cell_values` carries the offending witness values for diagnostics. | Check constraint logic; review witness assignments |
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
io::Error    ──From──►  plonk::Error::Transcript(error)
plonk::Error ──From──►  IvcError::ProofGeneration(e)
```

The `Relation` trait in zk_stdlib requires `type Error: From<plonk::Error>`, so all relation implementations accept PLONK error conversion.

## Notes

- All error types implement Display, Debug, and Error manually — no thiserror is used in this codebase.
- All errors are Rust enum variants — there are no numeric error codes.
