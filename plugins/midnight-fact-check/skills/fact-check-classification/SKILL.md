---
name: midnight-fact-check:fact-check-classification
description: >-
  Domain classification skill for the midnight-fact-check pipeline. Defines
  the four verification domains (Compact, SDK, ZKIR, Witness), how to tag
  claims with domains, rules for cross-domain classification, and handling
  of boundary cases. Used by the domain-classifier agent to tag claims in
  its assigned domain.
version: 0.1.0
---

# Domain Classification

You are a domain-specialist classifier. You have been assigned **one domain** and must tag every claim in the claims file that belongs to your domain.

## The Four Domains

### compact

Claims about the Compact smart contract language:
- Syntax, grammar, keywords, operators
- Type system (Uint, Field, Boolean, Bytes, tuples, structs, enums, generics)
- Standard library functions (persistentHash, transientHash, Counter, Map, Set, etc.)
- Control flow (for loops, if/else, assert)
- Disclosure and privacy (disclose(), ledger visibility)
- Module system (imports, exports, pragma)
- Compiler behavior (errors, warnings, accepted/rejected syntax)

**Examples:**
- "Compact tuples are 0-indexed" → compact
- "The for loop uses lower..upper syntax (inclusive..exclusive)" → compact
- "assert(condition, message) is the only error-handling mechanism" → compact

### sdk

Claims about the Midnight SDK, TypeScript APIs, and DApp development:
- Package exports and imports (`@midnight-ntwrk/*`)
- API signatures, return types, error types
- Provider configuration, network connectivity
- DApp connector patterns
- Transaction lifecycle
- Deployment and contract interaction

**Examples:**
- "deployContract returns DeployedContract" → sdk
- "CallTxFailedError extends TxFailedError" → sdk
- "The indexer GraphQL endpoint is at /api/v1/graphql" → sdk

### zkir

Claims about Zero-Knowledge Intermediate Representation:
- Opcode semantics (add, mul, neg, assert, constrain_bits, etc.)
- Field arithmetic (wrapping, modular)
- Circuit structure (instruction counts, I/O shape)
- Proof pipeline (PLONK checker, transcript protocol)
- Compiled output format

**Examples:**
- "add wraps modulo the field prime r" → zkir
- "disclosure compiles to declare_pub_input" → zkir
- "A pure circuit has no private_input instructions" → zkir

### witness

Claims about TypeScript witness implementations:
- Witness function signatures and return types
- WitnessContext usage
- Private state handling
- Type mappings between Compact and TypeScript
- Witness/contract interface matching

**Examples:**
- "Witness functions must return [PrivateState, ReturnValue]" → witness
- "Boolean maps to boolean in TypeScript" → witness
- "WitnessContext is the first parameter" → witness

## Your Task

You have been assigned the domain: **[provided in dispatch prompt]**

1. Read the claims file (your copy)
2. For each claim, determine if it belongs to your domain
3. If it does, update the claim object by adding/merging your domain into the `domains` array and setting `classification` fields
4. If it does not belong to your domain, leave it unchanged
5. Write the updated file

### When a Claim Belongs to Your Domain

Add or merge these fields:

```json
{
  "domains": ["your-domain"],
  "classification": {
    "primary_domain": "your-domain",
    "confidence": "high",
    "notes": "Brief reason this belongs to your domain"
  }
}
```

- If `domains` already exists (from another classifier), **append** your domain to the array.
- If `classification` already exists, only overwrite `primary_domain` if your confidence is higher.
- **confidence** values: `"high"` (clearly in your domain), `"medium"` (partially in your domain, might be cross-domain).

### Cross-Domain Claims

Some claims span multiple domains. If a claim is partially in your domain:
- Add your domain to `domains`
- Set confidence to `"medium"`
- Add a note explaining the cross-domain nature

Example: "Compact Boolean maps to TypeScript boolean" spans both `compact` and `witness`. Both classifiers should tag it.

### Boundary Cases

- If a claim is about **compiler behavior** (what the compiler does), it's `compact`
- If a claim is about **compiled output** (what ZKIR looks like), it's `zkir`
- If a claim is about **SDK types that mirror Compact types**, it's `sdk` (not compact)
- If a claim is about **witness types that mirror Compact types**, it's `witness` (not compact)

## Output

Write the updated claims file to your copy path. Return a summary:

```
Tagged N claims as [domain]. Skipped M claims (not in my domain).
Cross-domain tags: K claims also tagged by other domains.
```
