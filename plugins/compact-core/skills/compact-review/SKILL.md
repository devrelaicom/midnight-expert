---
name: compact-review
description: This skill should be used when reviewing Compact smart contract code, TypeScript witness implementations, or test files for a Midnight project. It provides category-specific checklists for privacy, security, cryptographic correctness, token economics, concurrency, compilation, performance, witness-contract consistency, architecture, code quality, testing adequacy, and documentation. Use this skill when you need structured review checklists and severity classification criteria for any of these categories. Load the appropriate reference file for your assigned review category.
---

# Compact Code Review Checklists

This skill contains review checklists for 11 categories of Compact smart contract review. Each reference file provides a focused checklist for one review category.

## How to Use

You will be assigned a **review category** by the review-compact command or coordinator. Load the reference file for your assigned category and apply every checklist item to the code under review.

## Category Reference Map

| Category | Reference File | Focus |
|----------|---------------|-------|
| Privacy & Disclosure | `privacy-review` | `disclose()` usage, witness data leaks, Set vs MerkleTree, persistentHash vs persistentCommit, salt reuse, conditional disclosure |
| Security & Cryptographic Correctness | `security-review` | Access control, hash/commit usage, domain separation, nullifiers, commitments, Merkle paths, error leakage |
| Token & Economic Security | `token-security-review` | Double-spend, overflow, unsafe transfers, missing receiveShielded, authorization |
| Concurrency & Contention | `concurrency-review` | Read-then-write patterns, Counter ops, transaction conflicts |
| Compilation & Type Safety | `compilation-review` | Deprecated syntax, return types, disclosure errors, casts, generics |
| Performance & Circuit Efficiency | `performance-review` | Proof cost, ledger reads, MerkleTree depth, redundant computation, loops |
| Witness-Contract Consistency | `witness-consistency-review` | Name matching, type mappings, private state patterns, WitnessContext |
| Architecture, State Design & Composability | `architecture-review` | ADT selection, depth planning, visibility, modules, decomposition |
| Code Quality & Best Practices | `code-quality-review` | Naming, complexity, dead code, stdlib hallucinations, idioms |
| Testing Adequacy | `testing-review` | Edge cases, negative tests, private state testing, witness mocks |
| Documentation | `documentation-review` | Circuit docs, witness contracts, ledger semantics |

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
