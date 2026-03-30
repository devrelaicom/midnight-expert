---
name: compact-review
description: This skill should be used when reviewing Compact smart contract code, TypeScript witness implementations, or test files for a Midnight project. Applies when a user asks to "review my Compact contract", "audit this smart contract", "check my Midnight code", or "run a code review checklist". Provides category-specific checklists covering privacy, security, cryptographic correctness, token economics, concurrency, compilation, performance, architecture, code quality, testing, and documentation, plus mechanical verification via /verify.
version: 0.1.0
---

# Compact Code Review Checklists

This skill contains review checklists for 10 categories of Compact smart contract review. Each reference file provides a focused checklist for one review category.

## How to Use

The assigned review category determines which reference file to load. Load the reference file for your assigned category and apply every checklist item to the code under review.

## Category Reference Map

| Category | Reference File | Focus |
|----------|---------------|-------|
| Privacy & Disclosure | `references/privacy-review.md` | `disclose()` usage, witness data leaks, Set vs MerkleTree, persistentHash vs persistentCommit, salt reuse, conditional disclosure |
| Security & Cryptographic Correctness | `references/security-review.md` | Access control, hash/commit usage, domain separation, nullifiers, commitments, Merkle paths, error leakage |
| Token & Economic Security | `references/token-security-review.md` | Double-spend, overflow, unsafe transfers, missing receiveShielded, authorization |
| Concurrency & Contention | `references/concurrency-review.md` | Read-then-write patterns, Counter ops, transaction conflicts |
| Compilation & Type Safety | `references/compilation-review.md` | Deprecated syntax, return types, disclosure errors, casts, generics |
| Performance & Circuit Efficiency | `references/performance-review.md` | Proof cost, ledger reads, MerkleTree depth, redundant computation, loops |
| Architecture, State Design & Composability | `references/architecture-review.md` | ADT selection, depth planning, visibility, modules, decomposition |
| Code Quality & Best Practices | `references/code-quality-review.md` | Naming, complexity, dead code, stdlib hallucinations, idioms |
| Testing Adequacy | `references/testing-review.md` | Edge cases, negative tests, private state testing, witness mocks |
| Documentation | `references/documentation-review.md` | Circuit docs, witness contracts, ledger semantics |

## Verification

Every review MUST include running `/verify` on the contract:

```bash
/verify <contract.compact>
```

For contracts with TypeScript witness implementations:

```bash
/verify <contract.compact> <witnesses.ts>
```

Verification results are authoritative for compilation correctness, type safety, witness consistency, and behavioral correctness. Include verification results alongside checklist findings in the review report.

## Severity Classification

Apply these severity levels consistently across all categories:

| Level | Criteria | Examples |
|-------|----------|----------|
| **Critical** | Will cause loss of funds, data breach, or contract exploitation | Missing access control on mint, private key leaked to ledger, double-spend vulnerability |
| **High** | Security vulnerability or privacy leak exploitable under certain conditions | Unnecessary disclose() on sensitive data, missing overflow check on token amounts |
| **Medium** | Correctness issue, compilation problem, or significant performance concern | Wrong type cast that will fail at runtime, MerkleTree depth 32 when 10 suffices |
| **Low** | Code quality, style, or minor best practice deviation | Inconsistent naming, unused import, missing sealed modifier |
| **Suggestion** | Enhancement opportunity, not a problem | Could use `pure` circuit modifier for better reuse, consider adding assertion message |

## Output Format

For each finding, use this format:

```
- **[Issue title]** (`file:line`)
  - **Problem:** Clear description of what is wrong
  - **Impact:** Why this matters (security, privacy, correctness, performance)
  - **Fix:** Suggested fix with code example when applicable
```

Group findings by severity within your category: Critical → High → Medium → Low → Suggestions.
End with a **Positive Highlights** section noting what was done well.
