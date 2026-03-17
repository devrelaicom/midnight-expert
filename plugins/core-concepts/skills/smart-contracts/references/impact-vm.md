# Impact VM

The Impact VM is Midnight's on-chain virtual machine for executing the public portion of smart contract logic. It replays state changes that were proven valid by ZK proofs.

## Core Properties

- **Stack-based** -- operates on a stack of values
- **Non-Turing-complete** -- no operations can decrease the program counter (no backward jumps), guaranteeing termination
- **Deterministic** -- same input always produces the same output
- **Gas-bounded** -- every operation has a fixed cost; programs declare a gas bound

The non-Turing-completeness is enforced by the instruction set: `jmp` and `branch` opcodes can only skip forward, never backward. This ensures all programs terminate in bounded time.

## Stack Structure

The VM stack is initialized with three elements:

```text
[Context, Effects, State]
```

| Element | Purpose |
|---------|---------|
| **Context** | Execution environment (read-only) |
| **Effects** | Accumulated side effects (token operations, contract calls) |
| **State** | Current contract state (read/write) |

## Value Types

The Impact VM supports these value types:

| Type | Description |
|------|-------------|
| `Cell` | Single value (field element, integer, bytes) |
| `Array(n)` | Indexed collection where 0 < n < 16 (1 to 15 items) |
| `Map` | Key-value mapping |
| `MerkleTree(d)` | Merkle tree with depth d (1 <= d <= 32) |

**Array bounds note**: The specification defines `Array(n)` where `0 < n < 16`, meaning arrays must have between 1 and 15 items (inclusive). The upper bound 16 is exclusive.

## Context Object

The context is an `Array` with 5 entries providing execution environment information:

| Index | Field | Type | Description |
|-------|-------|------|-------------|
| 0 | Contract address | Cell | The address of the executing contract |
| 1 | New coin allocations | Map | Newly allocated coins for this transaction |
| 2 | Block timestamp | Cell | Current block's timestamp |
| 3 | Timestamp divergence bound | Cell | Maximum allowed divergence from real time |
| 4 | Block hash | Cell | Hash of the current block |

> **Caution**: Currently, only the first two entries (contract address and new coin allocations) are correctly initialized. Entries 2–4 are defined but not yet correctly populated.

The context is read-only during execution.

## Opcode Categories

### Stack Operations

| Opcode | Description |
|--------|-------------|
| `push` | Push a constant value onto the stack |
| `pop` | Remove top element |
| `dup` | Duplicate top element |
| `swap` | Swap top two elements |

### Arithmetic

| Opcode | Description |
|--------|-------------|
| `add` | Addition |
| `sub` | Subtraction |
| `eq` | Equality comparison |

### Control Flow

| Opcode | Description |
|--------|-------------|
| `jmp offset` | Jump forward by offset (never backward) |
| `branch offset` | Conditional jump forward |
| `noop` | No operation |

All jump offsets must be positive, enforcing forward-only execution.

### State Operations

| Opcode | Description |
|--------|-------------|
| `idx` / `idxc` / `idxp` / `idxpc` | Read from contract state (various indexing modes) |
| `ins` / `insc` | Write to contract state (insert operations) |

### Effect Operations

Effects are modified via `ins`/`idx` operations on the effects Array in the initial stack.

## Execution Flow

```text
1. Initialize stack: [Context, Effects, State]
2. Load Impact program (bytecode)
3. Execute instructions sequentially (PC only moves forward)
4. On completion: stack returns to original shape; new State adopted if marked as storable
5. Verify: accumulated Effects match declared Effects
6. Commit new State to ledger
```

The program counter starts at 0 and can only increase. There are no loops in Impact bytecode -- all iteration is unrolled at compile time.

## Gas Model

Every opcode has a fixed gas cost. The transaction declares a gas bound for each transcript (guaranteed and fallible separately):

- If execution exceeds the declared gas bound, the transcript fails
- Gas costs ensure predictable execution time
- Validators can estimate block processing time from total gas

### Cost Categories (Conceptual)

- **Computation** -- arithmetic operations, hashing
- **Storage** -- ledger reads and writes (costs still being finalized)
- **Cryptographic** -- proof-related operations

Note: Specific gas costs are subject to change as the network matures. Storage costs in particular are still being finalized.

## Relationship to Compact

Compact code compiles to two outputs:

1. **Impact bytecode** -- the public state changes (runs on-chain in the VM)
2. **ZK circuits** -- the private computation (proven off-chain)

```text
Compact source
  ├── Impact bytecode (public transcript)
  │   └── Executes on Impact VM (on-chain)
  └── ZK circuit (private computation)
      └── Proves correctness off-chain (verified in guaranteed phase)
```

### What Goes Where

| Compact construct | Compiles to |
|-------------------|-------------|
| Ledger reads/writes | Impact bytecode |
| Arithmetic on public values | Impact bytecode |
| Witness function calls | ZK circuit (private) |
| `assert` with private data | ZK circuit constraint |
| `disclose()` boundary | Transition from ZK to Impact |
| Token operations | Impact effects |

## Debugging and Inspection

Transaction inspection is available through block explorers or the `midnight-node-toolkit`. Tooling is evolving as the network matures.

The Impact bytecode in a transaction is deterministic: given the same contract state and the same program, the output is always the same. This property makes debugging reproducible -- replaying a transaction against the same state will always produce the same result.
