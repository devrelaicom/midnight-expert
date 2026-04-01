---
name: core-concepts:protocol-schemas
description: This skill should be used when the user asks about Midnight protocol data structures, Compact AST schema, transaction schema, ZK proof schema, JSON schemas for Midnight, proof format, transaction format, AST structure, program structure, circuit declarations, ledger declarations, or the structure of compiled Compact programs.
version: 0.1.0
---

# Midnight Protocol Schemas

Midnight defines three core JSON schemas that describe the protocol's primary data structures: the Compact AST (abstract syntax tree), transactions, and zero-knowledge proofs. These schemas formalize the structure of compiler output, on-chain transaction data, and cryptographic proofs used throughout the system.

## Schema Overview

| Schema | Purpose | Reference File |
|--------|---------|---------------|
| Compact AST | Structure of compiled Compact programs | `references/compact-ast-schema.json` |
| Transaction | On-chain transaction format | `references/transaction-schema.json` |
| ZK Proof | Zero-knowledge proof structure | `references/zk-proof-schema.json` |

## Compact AST Schema

The Compact AST schema defines the structure of programs produced by the Compact compiler. The root type is `Program`, which contains imports, ledger declarations, circuits, witnesses, and type definitions.

See `midnight-tooling:compact-cli` for how the compiler produces this AST.

### Root Structure

A `Program` object contains:

| Property | Type | Description |
|----------|------|-------------|
| `type` | `"Program"` | Node type identifier |
| `version` | string | AST schema version |
| `imports` | array of strings | Imported modules |
| `ledger` | array of `LedgerDeclaration` | Public ledger state fields |
| `circuits` | array of `CircuitDeclaration` | Exported and internal circuits |
| `witnesses` | array of `WitnessDeclaration` | Private witness declarations |
| `types` | object | Named type definitions |

### Key Definitions

The schema contains 17 definitions covering the full AST:

| Definition | Description |
|-----------|-------------|
| `LedgerDeclaration` | A public ledger field with name, type, and export flag |
| `LedgerField` | Field within a ledger declaration (name and type) |
| `CircuitDeclaration` | Circuit with name, parameters, return type, body, export/pure flags |
| `WitnessDeclaration` | Witness function declaration (name, parameters, return type) |
| `Parameter` | Function parameter with name and type |
| `BlockStatement` | Block of statements enclosed in braces |
| `Statement` | Union of all statement types |
| `VariableDeclaration` | `const` binding with name, type, and initializer |
| `AssertStatement` | Assertion with condition and message |
| `ReturnStatement` | Return statement with optional value |
| `ExpressionStatement` | Expression used as a statement |
| `Expression` | Union of all expression types |
| `BinaryExpression` | Binary operation (arithmetic, comparison, logical) |
| `CallExpression` | Function/circuit call with callee and arguments |
| `MemberExpression` | Property access (dot notation) |
| `Identifier` | Named reference |
| `Literal` | Literal value (number, string, boolean) |

The full schema with all type constraints and validation rules is in `references/compact-ast-schema.json`.

## Transaction Schema

The transaction schema defines the format of on-chain transactions submitted to the Midnight network. Each transaction references a deployed contract, specifies the circuit to invoke, and includes the ZK proof along with public state changes.

See `core-concepts:architecture` for how transactions flow through the network.

### Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `version` | string | Yes | Transaction format version |
| `hash` | string | Yes | Transaction hash (hex, `^0x[a-fA-F0-9]{64}$`) |
| `contractAddress` | string | Yes | Target contract address (hex) |
| `circuitName` | string | Yes | Circuit being invoked |
| `inputs` | array | Yes | Public inputs to the circuit |
| `proof` | `Proof` | Yes | Zero-knowledge proof |
| `publicOutputs` | array | Yes | Public outputs from execution |
| `stateChanges` | array of `StateChange` | Yes | Ledger state modifications |
| `timestamp` | string (date-time) | Yes | Transaction creation time |
| `sender` | string | Yes | Sender address (hex) |
| `nonce` | integer | Yes | Replay protection counter |
| `fee` | object | Yes | Fee with `amount` (string) and `token` (string) |

### Definitions

**Proof**

| Property | Type | Description |
|----------|------|-------------|
| `type` | enum: `groth16`, `plonk` | Proof system used |
| `data` | string (base64) | Encoded proof data |
| `publicInputs` | array of strings | Public inputs to the proof |

**StateChange**

| Property | Type | Description |
|----------|------|-------------|
| `type` | enum: `insert`, `update`, `delete` | Type of state modification |
| `path` | string | Ledger state path being modified |
| `oldValue` | any (nullable) | Previous value (null for inserts) |
| `newValue` | any (nullable) | New value (null for deletes) |

The full schema is in `references/transaction-schema.json`.

## ZK Proof Schema

The ZK proof schema defines the structure of zero-knowledge proofs generated by the Midnight prover. This schema covers the proof elements, public inputs/outputs, verification key, and metadata.

See `core-concepts:zero-knowledge` for the cryptographic concepts behind these proofs, and `compact-core:compact-circuit-costs` for proof generation costs.

### Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `proofSystem` | enum: `groth16`, `plonk`, `halo2` | Yes | Proving system used |
| `curve` | enum: `bn254`, `bls12-381` | Yes | Elliptic curve |
| `proof` | object | Yes | Proof elements (a, b, c) |
| `publicInputs` | array of strings | Yes | Public inputs |
| `publicOutputs` | array of strings | Yes | Public outputs |
| `verificationKey` | string | Yes | Base64-encoded verification key |
| `metadata` | object | Yes | Proof generation metadata |

### Proof Elements

The `proof` object contains the three group elements that form the core of the ZK proof:

| Element | Type | Description |
|---------|------|-------------|
| `a` | array of 2 strings | G1 elliptic curve point (x, y coordinates) |
| `b` | array of 2 arrays of 2 strings | G2 elliptic curve point (2x2 coordinate matrix) |
| `c` | array of 2 strings | G1 elliptic curve point (x, y coordinates) |

### Metadata

| Property | Type | Description |
|----------|------|-------------|
| `circuitName` | string | Name of the circuit that generated the proof |
| `contractAddress` | string | Associated contract address |
| `generatedAt` | string (date-time) | Proof generation timestamp |
| `proverVersion` | string | Version of the prover software |

The full schema is in `references/zk-proof-schema.json`.

## Usage

These schemas are useful for:

- **Tooling development**: Validating compiler output, transaction construction, and proof generation
- **Integration testing**: Verifying that components produce correctly structured data
- **Documentation**: Understanding the exact structure of protocol data types
- **Interoperability**: Building third-party tools that interact with the Midnight protocol

When building DApps, the Compact compiler produces ASTs conforming to the Compact AST schema, transactions submitted to the network conform to the transaction schema, and proofs generated by the prover conform to the ZK proof schema.
