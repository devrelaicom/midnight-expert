# compact-compilation Skill Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `compact-compilation` skill to the compact-core plugin that covers compiler output artifacts, ZKIR/key generation, TypeScript bindings, circuit metrics, and compiler error interpretation.

**Architecture:** A single skill with SKILL.md (quick reference + routing), 4 reference files (artifact-centric organization), and 2 minimal example contracts. Follows the established compact-core skill pattern exactly.

**Tech Stack:** Markdown documentation, Compact smart contract examples, Midnight MCP server for verification.

---

### Task 1: Create directory structure

**Files:**
- Create: `plugins/compact-core/skills/compact-compilation/SKILL.md` (empty placeholder)
- Create: `plugins/compact-core/skills/compact-compilation/examples/` (directory)
- Create: `plugins/compact-core/skills/compact-compilation/references/` (directory)

**Step 1: Create the directories**

Run: `mkdir -p plugins/compact-core/skills/compact-compilation/{examples,references}`

**Step 2: Create empty SKILL.md placeholder**

Create `plugins/compact-core/skills/compact-compilation/SKILL.md` with just the frontmatter:

```markdown
---
name: compact-compilation
description: This skill should be used when the user asks about compiling Compact contracts, compiler output/artifacts, ZKIR files, prover/verifier keys, circuit metrics (k-value, rows), interpreting compiler errors, pure vs impure circuit compilation differences, the --skip-zk flag, contract-info.json, TypeScript binding generation, or the build output directory structure.
---

# Compact Compilation

TODO: Implementation in progress
```

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-compilation/
git commit -m "feat(compact-compilation): scaffold skill directory structure"
```

---

### Task 2: Write PureImpureDemo.compact example

**Files:**
- Create: `plugins/compact-core/skills/compact-compilation/examples/PureImpureDemo.compact`

**Step 1: Write the example contract**

Create `plugins/compact-core/skills/compact-compilation/examples/PureImpureDemo.compact`:

```compact
// PureImpureDemo.compact
// Demonstrates how the Compact compiler treats different circuit types.
//
// COMPILATION OUTPUT GUIDE:
// After running: compact compile PureImpureDemo.compact ./output
//
// contract/          -- TypeScript bindings for ALL exported circuits
//   index.d.ts       -- Type definitions (increment, reset, add all appear)
//   index.js         -- JavaScript implementation
//   index.js.map     -- Source map back to this .compact file
//
// zkir/              -- ZKIR files for EXPORTED IMPURE circuits ONLY
//   increment.zkir   -- Circuit description for "increment"
//   increment.bzkir  -- Binary ZKIR for "increment"
//   reset.zkir       -- Circuit description for "reset"
//   reset.bzkir      -- Binary ZKIR for "reset"
//   (no add.zkir)    -- "add" is pure, so NO ZKIR generated
//
// keys/              -- Prover/verifier keys for EXPORTED IMPURE circuits ONLY
//   increment.prover    -- Proving key for "increment"
//   increment.verifier  -- Verification key for "increment"
//   reset.prover        -- Proving key for "reset"
//   reset.verifier      -- Verification key for "reset"
//   (no add.prover)     -- "add" is pure, so NO keys generated
//
// compiler/
//   contract-info.json  -- Circuit manifest and metadata
//
// Expected compiler output:
//   Compiling 2 circuits:
//     circuit "increment" (k=10, rows=...)
//     circuit "reset" (k=10, rows=...)
//   Overall progress [====================] 2/2
//
// Note: Only 2 circuits compiled (the impure ones), not 3.
// The pure circuit "add" and internal helper "double" produce no ZK artifacts.

pragma language_version >= 0.16 && <= 0.18;

import CompactStandardLibrary;

export ledger count: Counter;

// EXPORTED IMPURE CIRCUIT
// Modifies ledger state -> generates ZKIR + prover/verifier keys
// Appears in: contract/, zkir/, keys/, compiler/
export circuit increment(amount: Uint<64>): [] {
  const doubled = double(amount);
  count.increment(disclose(doubled));
}

// EXPORTED IMPURE CIRCUIT
// Modifies ledger state -> generates ZKIR + prover/verifier keys
// Appears in: contract/, zkir/, keys/, compiler/
export circuit reset(): [] {
  const current = count.read();
  count.decrement(current);
}

// EXPORTED PURE CIRCUIT
// No ledger access -> NO ZKIR, NO keys
// Appears in: contract/ only (as pureCircuits.add)
export pure circuit add(a: Uint<64>, b: Uint<64>): Uint<64> {
  return a + b;
}

// INTERNAL HELPER (not exported)
// Embedded into calling circuits at compile time
// Does NOT appear as a standalone artifact anywhere
circuit double(x: Uint<64>): Uint<64> {
  return x + x;
}
```

**Step 2: Verify example compiles using Midnight MCP**

Use the `midnight-compile-contract` MCP tool to verify the contract compiles successfully. Check for any syntax or semantic errors.

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-compilation/examples/PureImpureDemo.compact
git commit -m "feat(compact-compilation): add PureImpureDemo example contract"
```

---

### Task 3: Write ErrorTriggers.compact example

**Files:**
- Create: `plugins/compact-core/skills/compact-compilation/examples/ErrorTriggers.compact`

**Step 1: Write the example contract**

Create `plugins/compact-core/skills/compact-compilation/examples/ErrorTriggers.compact`:

```compact
// ErrorTriggers.compact
// A valid base contract with commented-out error patterns.
// Uncomment each section one at a time to see the corresponding compiler error.
//
// This file compiles successfully as-is. Each error section is independent --
// uncomment ONE at a time, compile, observe the error, then re-comment it.

pragma language_version >= 0.16 && <= 0.18;

import CompactStandardLibrary;

export ledger value: Counter;

witness get_secret(): Bytes<32>;

export circuit working(): [] {
  value.increment(1);
}

// ============================================================================
// ERROR 1: Parse Error -- Wrong return type syntax
// ============================================================================
// Compact uses [] (empty tuple) not Void. This is the most common parse error.
//
// Uncomment to trigger:
//   export circuit badReturn(): Void { }
//
// Compiler output:
//   Parse error: expected '[' but found 'Void'

// ============================================================================
// ERROR 2: Type Error -- Wrong argument type
// ============================================================================
// Counter.increment() expects a numeric type, not Bytes.
//
// Uncomment to trigger:
//   export circuit badType(): [] {
//     const b: Bytes<4> = pad(4, "test");
//     value.increment(b);
//   }
//
// Compiler output:
//   Type error: no matching overload for 'increment'
//   Expected: Uint or Field
//   Actual: Bytes<4>

// ============================================================================
// ERROR 3: Disclosure Error -- Missing disclose()
// ============================================================================
// Witness-derived values flowing to ledger operations need disclose().
//
// Uncomment to trigger:
//   export circuit noDisclose(): [] {
//     const secret = get_secret();
//     const h = persistentHash<Bytes<32>>(secret);
//     // Writing witness-derived value to ledger without disclose()
//     value.increment(h as Field);
//   }
//
// Compiler output:
//   Error: potential witness-value disclosure must be declared

// ============================================================================
// ERROR 4: Deprecated Syntax -- Block-style ledger
// ============================================================================
// Old Compact versions used `ledger { }` blocks. Now each field is separate.
//
// Uncomment to trigger:
//   ledger {
//     counter: Counter;
//   }
//
// Compiler output:
//   Parse error: expected declaration but found '{'

// ============================================================================
// ERROR 5: Enum Syntax Error -- Double colon
// ============================================================================
// Compact uses dot notation (State.active), not Rust-style double colons.
//
// Uncomment to trigger:
//   export enum State { active, inactive }
//   export circuit badEnum(): [] {
//     const s = State::active;
//   }
//
// Compiler output:
//   Parse error: expected ';' or '}' but found ':'
```

**Step 2: Verify base contract compiles using Midnight MCP**

Use the `midnight-compile-contract` MCP tool to verify the base contract (with all errors commented out) compiles successfully.

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-compilation/examples/ErrorTriggers.compact
git commit -m "feat(compact-compilation): add ErrorTriggers example contract"
```

---

### Task 4: Write references/compilation-output.md

**Files:**
- Create: `plugins/compact-core/skills/compact-compilation/references/compilation-output.md`

**Step 1: Write the reference file**

This file covers:
- Full directory tree of compiler output with every file type annotated
- File count formula: for N exported impure circuits, you get N ZKIR files, N prover keys, N verifier keys, plus TypeScript bindings and metadata
- The relationship: 1 exported impure circuit = 1 ZKIR + 1 prover + 1 verifier
- Pure circuits: appear in TypeScript bindings (as `pureCircuits`) but get NO ZKIR or keys
- Internal (non-exported) circuits: embedded into callers, no standalone output at all
- `compiler/contract-info.json` manifest -- what fields it contains, when it's needed (composable contracts use it as a dependency)
- Stale file cleanup -- when circuits are removed from source, compiler removes orphaned ZKIR files
- Annotated example using the PureImpureDemo contract showing exactly which files appear

Use the Midnight MCP server to verify artifact structure details:
- `midnight-search-docs` for "compilation output" and "artifacts"
- `midnight-search-typescript` for "contract-info" and "ZKFileConfiguration"
- Cross-reference with the research findings from brainstorming

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-compilation/references/compilation-output.md
git commit -m "feat(compact-compilation): add compilation-output reference"
```

---

### Task 5: Write references/zkir-and-keys.md

**Files:**
- Create: `plugins/compact-core/skills/compact-compilation/references/zkir-and-keys.md`

**Step 1: Write the reference file**

This file covers:
- ZKIR format overview: JSON (`.zkir`) and binary (`.bzkir`) variants
- ZKIR versioning (v2 vs v3), how version is detected from JSON payload
- What ZKIR represents: a circuit description consumed by the proof server at runtime to generate ZK proofs
- Prover key contents: `ProvingKeyMaterial` containing `proverKey: Uint8Array`, `verifierKey: Uint8Array`, `ir: Uint8Array`
- Verifier key contents: branded `Uint8Array`, submitted on-chain during deployment for validators to verify proofs
- Circuit metrics from compiler output: `k` value (evaluation domain size = 2^k) and `rows` (actual constraint rows used)
- Key generation as the compilation bottleneck -- this is the slowest phase
- `--skip-zk` flag: skips key generation, produces all outputs EXCEPT `keys/` directory. Use during development for fast iteration.
- When you NEED full key generation: before deployment, before integration testing with the proof server, before submitting to CI/CD
- The proof server's relationship to these artifacts: it reads ZKIR files and uses prover keys to generate proofs

Use the Midnight MCP server to verify ZKIR and key details:
- `midnight-search-typescript` for "ProvingKeyMaterial", "VerifierKey", "ZKIR"
- `midnight-search-docs` for "proof server" and "proving keys"

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-compilation/references/zkir-and-keys.md
git commit -m "feat(compact-compilation): add zkir-and-keys reference"
```

---

### Task 6: Write references/typescript-bindings.md

**Files:**
- Create: `plugins/compact-core/skills/compact-compilation/references/typescript-bindings.md`

**Step 1: Write the reference file**

This file covers:
- Overview of the `contract/` output directory
- `index.d.ts` type definitions:
  - `Contract<T>` class with `circuits`, `impureCircuits`, `initialState()` method
  - `PureCircuits` object containing all pure circuits as standalone functions
  - `Ledger` type for reading exported ledger state
  - `Witnesses<T>` type defining witness function signatures
  - User-defined types: how Compact `enum` maps to TypeScript `enum`, how Compact `struct` maps to TypeScript interface
  - `ledger(state: StateValue): Ledger` constructor function
- `index.js` implementation:
  - Runtime version check against `@midnight-ntwrk/compact-runtime`
  - MAX_FIELD validation ensuring compilation target matches runtime
  - Type descriptor definitions for encode/decode
  - Circuit implementations as argument-validated wrappers
- `index.js.map` source map:
  - Maps generated JavaScript back to original `.compact` source
  - `--sourceRoot` flag controls the relative path in the source map
  - Enables debugging Compact contracts in VS Code
- Type mapping table: Compact type → TypeScript type for all major types
- The `Contract<T>` generic parameter: `T` is the private state type, defined by the DApp developer in TypeScript (not in Compact)

Use the Midnight MCP server:
- `midnight-search-typescript` for "Contract class", "PureCircuits", "Ledger type"
- `midnight-get-file` for actual generated TypeScript examples from counter or bboard

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-compilation/references/typescript-bindings.md
git commit -m "feat(compact-compilation): add typescript-bindings reference"
```

---

### Task 7: Write references/compiler-errors.md

**Files:**
- Create: `plugins/compact-core/skills/compact-compilation/references/compiler-errors.md`

**Step 1: Write the reference file**

This file covers:
- **Parse errors**: The compiler shows expected-token diagnostics (e.g., "expected '[' but found 'Void'"). Common triggers: wrong return type syntax, double-colon enum access, block-style ledger declarations, Unicode numeric characters.
- **Type errors**: Overloading resolution failures show expected vs actual types. ADT type argument errors (wrong type for Map/Set/Counter operations). Generic parameter failures treated like overloading errors.
- **Disclosure errors**: `potential witness-value disclosure must be declared` -- witness-derived values flowing to ledger operations or conditionals without `disclose()`. Cross-reference to compact-privacy-disclosure skill for full disclosure rules.
- **ZKIR generation errors**: Rare but possible -- index allocation issues with circuit arguments when type constraints have side effects. Fixed in compiler version 0.21.105 (language version 0.14.100).
- **Integer overflow errors**: Integer literals exceeding the field modulus produce compile-time errors. The maximum value depends on the crypto backend (BLS12-381 field).
- **Composable contract errors**: Missing `contract-info.json` in dependency path. Malformed `contract-info.json` (corrupted circuit definitions). Malformed argument names in dependencies are tolerated.
- **Internal errors**: Should never occur for valid or invalid input. Exit code 255. If encountered, it's a compiler bug -- report it. Past examples: MerkleTree operator errors, `infer-types: no matching clause` errors.
- **Runtime compatibility errors** (post-compilation but commonly encountered right after): Version mismatch between generated JS and `@midnight-ntwrk/compact-runtime`. MAX_FIELD mismatch between compilation target and runtime. These manifest as runtime errors when loading the generated JavaScript, not during compilation itself.
- Error debugging strategy table: symptom → likely category → what to check

Cross-reference the ErrorTriggers.compact example for hands-on error reproduction.

Use the Midnight MCP server:
- `midnight-search-docs` for "compiler error" and "error messages"
- `midnight-get-latest-updates` to check for recent compiler error improvements

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-compilation/references/compiler-errors.md
git commit -m "feat(compact-compilation): add compiler-errors reference"
```

---

### Task 8: Write the full SKILL.md

**Files:**
- Modify: `plugins/compact-core/skills/compact-compilation/SKILL.md` (replace placeholder)

**Step 1: Write the complete SKILL.md**

Replace the placeholder with the full SKILL.md following the established compact-core pattern (see compact-structure/SKILL.md as the template). Sections:

1. **Frontmatter** -- name and trigger description
2. **Opening paragraph** -- "The Compact compiler transforms .compact source files into four categories of artifacts..."
3. **Compilation Output Structure** -- ASCII tree showing the 4 output directories with annotations
4. **Artifact Quick Reference** -- Table: Artifact | Purpose | Generated When
5. **Pure vs Impure Circuits** -- Code example showing which circuits get which artifacts, with a summary table
6. **Circuit Metrics** -- Explanation of `k` value and `rows` from compiler output, what they mean for circuit size
7. **Compiler Error Categories** -- Quick table: Error Type | Trigger | Key Diagnostic
8. **Development Workflow** -- `--skip-zk` usage pattern, when to use full compilation, iteration strategy
9. **Cross-references** -- Links to compact-cli (CLI management), compact-structure (contract anatomy), compact-privacy-disclosure (disclosure errors)
10. **Reference Files** -- Routing table mapping topics to reference files

Keep it concise -- SKILL.md is the quick reference and router, not the deep dive. Each section should be brief with a pointer to the relevant reference file for more detail.

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-compilation/SKILL.md
git commit -m "feat(compact-compilation): write complete SKILL.md"
```

---

### Task 9: Update plugin.json keywords

**Files:**
- Modify: `plugins/compact-core/.claude-plugin/plugin.json`

**Step 1: Add compilation-related keywords**

Add these keywords to the existing keywords array: `"compilation"`, `"compiler-output"`, `"zkir"`, `"prover-keys"`, `"verifier-keys"`, `"circuit-metrics"`, `"build-artifacts"`.

**Step 2: Commit**

```bash
git add plugins/compact-core/.claude-plugin/plugin.json
git commit -m "feat(compact-compilation): add compilation keywords to plugin manifest"
```

---

### Task 10: Verify examples compile

**Step 1: Compile PureImpureDemo.compact**

Use the `midnight-compile-contract` MCP tool to compile the PureImpureDemo.compact example. Verify it compiles without errors.

**Step 2: Compile ErrorTriggers.compact (base contract)**

Use the `midnight-compile-contract` MCP tool to compile ErrorTriggers.compact with all error patterns commented out. Verify the base contract compiles without errors.

**Step 3: Fix any compilation errors**

If either example fails to compile, fix the issues and amend the relevant commit.

**Step 4: Commit fixes if needed**

```bash
git add plugins/compact-core/skills/compact-compilation/examples/
git commit -m "fix(compact-compilation): address compilation errors in examples"
```

---

### Task 11: Run skill review

**Step 1: Review skill quality**

Use the `plugin-dev:skill-reviewer` agent to review the completed compact-compilation skill for quality, completeness, and adherence to best practices.

**Step 2: Address review feedback**

Make any adjustments recommended by the skill reviewer.

**Step 3: Commit fixes**

```bash
git add plugins/compact-core/skills/compact-compilation/
git commit -m "fix(compact-compilation): address skill review feedback"
```
