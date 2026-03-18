---
name: verify-correctness
description: This skill should be used when the user needs to verify Midnight-related claims, check if stdlib functions exist, validate Compact syntax, confirm SDK API signatures, verify package versions, check compiler behavior, validate protocol claims, verify privacy properties, assess correctness confidence, or resolve conflicting information from multiple sources. Referenced by the SessionStart hook as the standard verification procedure.
version: 0.1.0
---

# Verification Framework for Midnight Claims

This skill defines a structured approach to verifying claims about Midnight's Compact language, SDKs, protocol, and tooling. Every verification has an associated confidence level. The goal is to select the right verification method for the context, combine evidence from multiple sources, and know when to escalate to the user. For stdlib-specific verification, see `compact-standard-library`. For compiler-specific verification, see `compact-compilation`. For MCP tool usage details, see the `midnight-mcp` plugin.

## Verification Methods

Six methods for verifying claims, ordered from lowest to highest confidence. Use the lowest-effort method that reaches the confidence threshold your context requires.

### 1. MCP midnight-search-compact / midnight-search-typescript (Confidence: 20-45)

Searches indexed code from Midnight Foundation, partners, and ecosystem projects via the `midnight-mcp` plugin.

- Quality varies significantly. Always check `relevanceScore` and `source.repository` in the results
- Code from `midnightntwrk`, `OpenZeppelin`, or `LFDT-Minokawa` repositories is more likely correct than community or third-party code
- Indexed code may be outdated — a function appearing in search results does not guarantee it exists in the current release
- Useful for finding usage patterns and examples, less useful for confirming exact API signatures
- Use `midnight-search-compact` for Compact language questions, `midnight-search-typescript` for SDK/DApp questions

### 2. MCP midnight-search-docs (Confidence: 20-30)

Searches the Midnight documentation index via the `midnight-mcp` plugin tools.

- The docs search index lags behind published docs. The published docs themselves lag behind releases and are not always correct
- Always verify information found in docs using an independent source before presenting it as fact
- Check `relevanceScore` — low-scoring results are often tangentially related or outdated
- Documentation is most reliable for high-level concepts and architecture; least reliable for exact API signatures and version-specific behavior

### 3. Midnight Expert Plugins/Skills (Confidence: 60-80)

Reference content from skills in `compact-core`, `midnight-tooling`, `midnight-mcp`, and other Midnight Expert plugins.

- Skill content has been verified against compiler and MCP sources, but Midnight moves fast and skills can become outdated
- Skills are reliable for language semantics, patterns, and architectural concepts that change infrequently
- Skills are less reliable for version numbers, package names, exact CLI flags, and anything tied to a specific release
- Cannot be fully trusted as a sole source — corroborate with higher-confidence methods when accuracy is critical

### 4. Compiling the Code (Confidence: 80-95)

Use MCP `midnight-compile-contract` or local `compact compile` to test whether code actually works. See `compact-compilation` for compiler usage details.

- Use `skipZk=true` for fast development validation (type checking, syntax, ledger operations). Use full compile for significant changes or when zero-knowledge proof generation behavior matters
- **Critical:** compile using the correct language version for the target environment. A contract that compiles under one Compact version may fail under another. Use `compact-compilation` for version selection guidance
- Compilation confirms syntax validity, type correctness, and that referenced functions exist. It does not confirm runtime behavior, gas costs, or proof generation performance
- A successful compile is strong evidence. A compile failure is definitive evidence that something is wrong

### 5. Direct Tooling Checks (Confidence: 90-100)

For version and release information, NEVER rely on skills or docs alone — these go stale fastest. Use the tools directly:

| Check | Command | What It Tells You |
|-------|---------|-------------------|
| Package versions | `npm view @midnight-ntwrk/<package> versions` | All published versions of a package |
| CLI/compiler version | `compact check` / `compact self check` | Installed CLI and compiler versions |
| Component releases | `gh release list` / GitHub tags | Release history for any component |
| Service health | Read-only health/version endpoints | Running version of a deployed service |

See `midnight-tooling:compact-cli` for CLI command details.

- Only hit read-only, idempotent endpoints. Local devnet is an exception where write operations are acceptable for testing
- Direct tooling checks are authoritative for the specific version/instance being queried
- If a direct check disagrees with documentation or skill content, the direct check wins

### 6. Checking the Source (Confidence: 90-100)

The Compact compiler, SDKs, ledger, and other components are open source. Source code is the ultimate source of truth.

- Use the `midnight-tooling` plugin's GitHub tools or MCP `midnight-search-compact`/`midnight-search-typescript` to navigate source repositories
- This is time-consuming and costly — the compiler has dependencies across multiple repos, and understanding the full picture requires significant context
- Use only when specifically requested by the user, when other methods have produced contradictory results that cannot be resolved, or when the claim being verified has high-stakes consequences (production deployment, security properties)

## Categories of Things to Verify

Each category has different verification characteristics. Use the recommended methods in order of preference.

### 1. Compact Language

Stdlib function/type existence, syntax validity, type compatibility and casting rules, compiler behavior for a specific language version, disclosure rules.

| What to Verify | Recommended Methods | Notes |
|----------------|---------------------|-------|
| Function exists in stdlib | Skills → Compile | Check `compact-standard-library` export inventory first, then compile a minimal contract |
| Syntax is valid | Compile | Compilation is definitive for syntax questions |
| Type compatibility | Compile | Write a minimal contract exercising the type conversion |
| Disclosure rules | Skills → Compile | Check `compact-privacy-disclosure`, then compile to confirm |
| Compiler behavior for version X | Compile (with correct version) → Source | Behavior can differ across versions |

### 2. SDK / TypeScript

API function signatures, type definitions, package existence/versions/compatibility, import paths and module structure.

| What to Verify | Recommended Methods | Notes |
|----------------|---------------------|-------|
| API signature | MCP midnight-search-typescript → Skills → Source | Check `compact-witness-ts` for witness/provider patterns |
| Package exists/versions | Direct tooling (`npm view`) | Never rely on skills for version info |
| Import paths | MCP midnight-search-typescript → Source | Import paths change between major versions |
| Type definitions | MCP midnight-search-typescript → Source | TypeScript types are generated; check the generated output |

### 3. Protocol / Architecture

How things work (UTXO vs account model, what is visible on-chain), token behavior and capabilities, transaction model semantics.

| What to Verify | Recommended Methods | Notes |
|----------------|---------------------|-------|
| On-chain visibility | Skills → Docs | Check `compact-transaction-model` and `compact-privacy-disclosure` |
| Token behavior | Skills → Compile | Check `compact-tokens` then compile to confirm |
| Transaction semantics | Skills → Docs → Source | Check `compact-transaction-model` |

### 4. Configuration / Operations

Network endpoints and ports, Docker image tags and versions, CLI commands and flags, component compatibility matrix.

| What to Verify | Recommended Methods | Notes |
|----------------|---------------------|-------|
| Network endpoints | Direct tooling → Docs | Endpoints change; always verify against live infrastructure |
| Docker image tags | Direct tooling (`docker pull`, registry) | Tags change with each release |
| CLI flags | Direct tooling (`compact --help`) → Skills | Check `midnight-tooling:compact-cli` then verify with `--help` |
| Compatibility matrix | Direct tooling (`npm view`) → Skills | Check `compact-deployment` for known compatibility |

### 5. Patterns / Best Practices

Design pattern selection, security properties, performance implications.

| What to Verify | Recommended Methods | Notes |
|----------------|---------------------|-------|
| Pattern correctness | Skills → Compile | Check `compact-patterns`, then compile the pattern |
| Security properties | Skills → Source | Check `compact-review` for security review guidance |
| Performance implications | Skills → Compile (full, no skipZk) | Check `compact-circuit-costs` for cost analysis |

### 6. Tooling Behavior

Compact CLI flags and behavior, proof server capabilities and limitations, indexer query behavior.

| What to Verify | Recommended Methods | Notes |
|----------------|---------------------|-------|
| CLI behavior | Direct tooling → Skills | Run the command with `--help` or test it directly |
| Proof server capabilities | Skills → Docs → Source | Check `compact-compilation` and `compact-deployment` |
| Indexer queries | Skills → Docs → Source | Check relevant deployment and testing skills |

### 7. Cross-Component Compatibility

Compiler to SDK to proof server version alignment, runtime version compatibility, network differences (devnet vs testnet vs mainnet).

| What to Verify | Recommended Methods | Notes |
|----------------|---------------------|-------|
| Version alignment | Direct tooling → Skills | Use `npm view` and `compact check` to get actual versions; check `compact-deployment` |
| Network differences | Skills → Docs → Direct tooling | Check `compact-deployment` for network-specific configuration |
| Runtime compatibility | Direct tooling → Source | Version mismatches cause subtle failures; always verify |

### 8. Privacy Properties

What is actually hidden vs visible in a contract design, whether a privacy pattern achieves its claimed guarantees, correlation attack resistance.

| What to Verify | Recommended Methods | Notes |
|----------------|---------------------|-------|
| Hidden vs visible | Skills → Compile | Check `compact-privacy-disclosure` and `compact-transaction-model`; compile to verify disclosure behavior |
| Privacy guarantees | Skills → Source | Check `compact-review` for privacy review methodology |
| Correlation resistance | Skills → Source → User discussion | This requires deep analysis; see `compact-privacy-disclosure` for known patterns |

## Confidence Combination and Disagreement

### Corroborating Evidence

When multiple verification methods agree, confidence increases:

- Skills say X + compile confirms X → high confidence (85-95)
- Skills say X + MCP search shows X in real code + compile confirms → very high confidence (90-95)
- Direct tooling confirms X + source code confirms X → definitive (95-100)

A single high-confidence method that directly tests the claim can be sufficient on its own (e.g., successful compilation for "does this syntax work?").

### Contradictory Evidence

When methods disagree, do NOT pick the result that supports your assumption. Investigate the disagreement:

1. **Higher-confidence methods win when they directly test the claim.** "Compile fails" beats "docs say it works." `npm view` showing version 1.5.0 as latest beats a skill saying 1.3.0 is latest
2. **Check for version skew.** The most common cause of disagreement is that one source refers to a different version than another
3. **Check for scope mismatch.** A function may exist in the compiler but not be exported from the standard library, or exist in one package but not the one being discussed
4. **Document the disagreement.** When reporting to the user, note which sources agree and which disagree, and what your resolution is

### When to Escalate to the User

Escalate rather than guessing when:

- Methods disagree and you cannot resolve the contradiction through further investigation
- The highest available confidence is below what the context requires (see soft guidelines below)
- The claim involves security properties or production deployment and you have not reached 90+ confidence
- You suspect version skew but cannot determine which version the user is targeting
- The verification would require running commands against non-local infrastructure (other than read-only endpoints)

## Soft Confidence Guidelines

These are guidance, not hard gates. Use judgment based on the consequences of being wrong:

| Context | Acceptable Confidence | Rationale |
|---------|----------------------|-----------|
| Casual exploration / answering questions | 60+ | Low stakes; user is learning |
| Writing code for the user | 80+ | Code that does not work wastes time |
| Production / deployment context | 90+ | Errors are expensive to fix |
| Version / release information | 90-100 (direct tooling only) | Never rely on skills or docs alone for versions |

When confidence is below the threshold for the context, say so. "I believe X based on [source], but I have not been able to verify this directly. To confirm, you could [suggested verification step]."

## Quick Reference Decision Table

| What You Are Verifying | Recommended Methods | Minimum Confidence Target |
|------------------------|---------------------|---------------------------|
| Stdlib function exists | `compact-standard-library` skill → compile | 80 |
| Compact syntax is valid | Compile with `skipZk=true` | 80 |
| SDK API signature | MCP midnight-search-typescript → source | 80 |
| Package version | `npm view` | 90 |
| CLI flag/behavior | `compact --help` or run directly | 90 |
| Privacy property holds | `compact-privacy-disclosure` skill → compile → source | 90 |
| Pattern is correct | `compact-patterns` skill → compile | 80 |
| Version compatibility | Direct tooling checks | 90 |
| Network endpoint/config | Direct tooling → docs | 90 |
| Protocol/architecture claim | Skills → docs | 60 |
| Security property | Skills → source → user discussion | 90 |
| Disclosure behavior | `compact-privacy-disclosure` skill → compile | 80 |

## Cross-References

| Topic | Skill / Plugin |
|-------|----------------|
| Stdlib function verification protocol and export inventory | `compact-standard-library` |
| Compiler usage, version selection, compile flags | `compact-compilation` |
| Troubleshooting verification failures and compile errors | `compact-debugging` |
| MCP tool usage (midnight-search-compact, midnight-search-docs, midnight-compile-contract) | `midnight-mcp` plugin |
| CLI commands and flags | `midnight-tooling:compact-cli` |
| Privacy and disclosure verification | `compact-privacy-disclosure` |
| Security review methodology | `compact-review` |
| Circuit cost analysis | `compact-circuit-costs` |
| Deployment and version compatibility | `compact-deployment` |
