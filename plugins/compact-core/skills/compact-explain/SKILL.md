---
name: compact-explain
description: Use when the user asks to explain, describe, walk through, or teach Compact smart contract code, concepts, syntax, patterns, or language features. Also use when the user pastes a .compact file or snippet and asks "what does this do", "how does this work", or "help me understand".
---

# Explain Compact Code

Explain Compact smart contract code, concepts, and patterns to users with accuracy and progressive depth.

## Core Principles

1. **Never invent syntax.** Every code example MUST use valid Compact syntax. If unsure, load the relevant skill to verify before showing examples.
2. **Route to authoritative skills.** Don't explain from memory — load the specific compact-core skill for the topic and reference its content.
3. **Progressive depth.** Start with what it does, then how it works, then why it's designed that way.
4. **Connect to context.** When explaining code, relate each part to the user's actual contract, not abstract theory.

## Explanation Routing Table

Before explaining, identify WHAT the user is asking about and load the right skill:

| Topic | Load Skill | Key Sections |
|-------|-----------|--------------|
| Types, operators, casting, syntax | `compact-language-ref` | Types Quick Reference, Operators, Type Casting |
| Contract anatomy, ledger, circuits, witnesses | `compact-structure` | Contract Anatomy, Common Mistakes |
| `disclose()`, privacy, sealed ledger, witness flow | `compact-privacy-disclosure` | Core concepts, debugging-disclosure |
| Design patterns (access control, state machines, etc.) | `compact-patterns` | Pattern Quick Reference, specific pattern |
| Tokens (FungibleToken, NFT, shielded) | `compact-tokens` | Token operations |
| Ledger types, Map, Set, Counter, MerkleTree | `compact-ledger` | Types and operations |
| Standard library functions (persistentHash, pad, etc.) | `compact-standard-library` | Function reference, hallucination traps |
| TypeScript witnesses, type mappings | `compact-witness-ts` | Type mappings, witness implementation |
| Compilation, circuit costs, ZK constraints | `compact-compilation` + `compact-circuit-costs` | Compilation pipeline, cost model |
| Transaction model, UTXO, shielded coins | `compact-transaction-model` | Transaction lifecycle |
| Deployment | `compact-deployment` | Deployment steps |

**Multiple topics?** Load multiple skills. A single contract often spans structure + privacy + patterns.

## Explanation Structure

### For Code Explanations (file or snippet)

Follow this structure:

**1. One-Sentence Summary**
What does this contract/snippet do in plain language?

**2. Section-by-Section Walkthrough**
For each logical section of the code:
- **What it declares/does** — plain language
- **Why it matters** — the purpose in the contract's logic
- **Compact-specific detail** — how this maps to ZK circuits, on-chain state, or privacy properties

**3. Privacy Analysis**
Create a table showing what is public vs private:

```
| Element | Visibility | Why |
|---------|-----------|-----|
| ledger X | Public | Not sealed — visible on-chain |
| sealed ledger Y | Private | Values committed, not readable |
| witness Z | Fully private | Never leaves prover's machine |
| disclose(V) | Explicitly public | Author chose to reveal this |
```

**4. Pattern Identification**
Identify which patterns from `compact-patterns` the code uses (or should use). Name them explicitly.

**5. Issues and Improvements** (if any)
Flag real problems with specific fixes. Reference the correct Compact syntax for the fix. Verify behavioral claims (e.g., sealed ledger write restrictions, Map operation visibility) against the loaded skill before stating them as fact.

**6. Learn More**
Point to 2-3 specific skills or sections for deeper reading.

### For Concept Explanations (no code provided)

**1. What It Is** — one-paragraph definition grounded in Compact specifics (not generic blockchain theory)

**2. When You Need It** — specific triggering situations in Compact code

**3. How It Works** — using ONLY valid Compact syntax in examples. Load the relevant skill to get correct examples.

**4. What Happens Without It** — actual compiler errors or runtime behavior (load skill to get exact error messages)

**5. Common Mistakes** — from the loaded skill's troubleshooting section

**6. Related Concepts** — links to other skills for connected topics

## Red Flags — Stop and Verify

If you catch yourself doing any of these, STOP and load the relevant skill:

- Writing a code example without checking it's valid Compact syntax
- Using `function` keyword (Compact uses `circuit`)
- Using `private` keyword for state (Compact uses `sealed ledger`)
- Using `contract { }` block syntax (Compact files ARE the contract)
- Referencing stdlib functions without verifying they exist (check `compact-standard-library` hallucination traps)
- Explaining a concept purely from memory without loading the skill
- Using `::` for enum variants (Compact uses `.` dot notation)
- Using `Void` return type (Compact uses `[]`)
- Making claims about runtime/compiler behavior (e.g., "sealed fields can only be written in constructors") without verifying against the loaded skill

## Adapting Depth to the User

- **Beginner signals** ("what does this do", "I don't understand", "new to Compact"): Lead with analogies to familiar concepts. Keep ZK details minimal. Focus on what, not how.
- **Intermediate signals** (asking about specific features, already has working code): Explain the mechanics. Include circuit/proof implications. Reference patterns by name.
- **Advanced signals** (asking about circuit costs, optimization, privacy properties): Go deep on ZK constraints, proof generation, on-chain vs off-chain tradeoffs. Reference `compact-circuit-costs` and `compact-compilation`.

When in doubt, start at intermediate level and adjust based on follow-up questions.
