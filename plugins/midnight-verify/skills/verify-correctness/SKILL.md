---
name: verify-correctness
description: >-
  This skill should be used when the user needs to verify Midnight-related claims,
  check if stdlib functions exist, validate Compact syntax, confirm SDK API signatures,
  verify package versions, check compiler behavior, validate protocol claims, verify
  privacy properties, assess correctness confidence, or resolve conflicting information
  from multiple sources. This is the hub skill — it provides generic verification
  methodology and routes to domain-specific skills (verify-compact, verify-sdk) based
  on the claim being verified. Referenced by the SessionStart hook as the standard
  verification procedure.
version: 0.1.0
---

# Verification Framework for Midnight Claims

This skill is the hub of the `midnight-verify` plugin. It provides domain-agnostic verification methodology and routes to specialized skills based on the type of claim being verified. It does not contain domain-specific methods — those live in the domain skills.

For Compact-specific verification (syntax, stdlib, compilation, privacy properties), see `midnight-verify:verify-compact`. For SDK/TypeScript-specific verification (API signatures, package versions, import paths), see `midnight-verify:verify-sdk`.

## Routing Logic

Load the appropriate domain skill based on what is being verified. This is the first step for any verification task.

| Claim Type | Load Which Skill |
|------------|-----------------|
| Compact language: syntax, stdlib functions, types, disclosure rules, compiler behavior, patterns, privacy properties, circuit costs | `midnight-verify:verify-compact` |
| SDK/TypeScript: API signatures, package versions, import paths, type definitions, providers, DApp connector | `midnight-verify:verify-sdk` |
| Protocol/architecture claims | Both `midnight-verify:verify-compact` and `midnight-verify:verify-sdk` |
| Configuration/operations: network endpoints, Docker images, component compatibility | Both `midnight-verify:verify-compact` and `midnight-verify:verify-sdk` |
| Cross-component compatibility | Both `midnight-verify:verify-compact` and `midnight-verify:verify-sdk` |
| Tooling behavior only: CLI flags, proof server, indexer | Hub skill is sufficient — use Direct Tooling Checks below |

## Verification Methods (Generic)

These two methods apply across all domains. Domain-specific methods (compilation, MCP search) are documented in the domain skills.

### Direct Tooling Checks (Confidence: 90-100)

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

### Checking the Source (Confidence: 90-100)

The Compact compiler, SDKs, ledger, and other components are open source. Source code is the ultimate source of truth.

- Use the `midnight-tooling` plugin's GitHub tools or MCP `midnight-search-compact`/`midnight-search-typescript` to navigate source repositories
- This is time-consuming and costly — the compiler has dependencies across multiple repos, and understanding the full picture requires significant context
- Use only when specifically requested by the user, when other methods have produced contradictory results that cannot be resolved, or when the claim being verified has high-stakes consequences (production deployment, security properties)
- For Compact source repos, see `midnight-verify:verify-compact`. For SDK source repos, see `midnight-verify:verify-sdk`

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
- The claim involves security properties or production deployment and you have not reached 95+ confidence
- You suspect version skew but cannot determine which version the user is targeting
- The verification would require running commands against non-local infrastructure (other than read-only endpoints)

## Soft Confidence Guidelines

These are guidance, not hard gates. Use judgment based on the consequences of being wrong:

| Context | Acceptable Confidence | Rationale |
|---------|----------------------|-----------|
| Casual exploration / answering questions | 75+ | Low stakes but still verify |
| Writing code for the user | 90+ | Code that does not work wastes time |
| Production / deployment context | 95+ | Errors are expensive to fix |
| Version / release information | 95-100 (direct tooling only) | Never rely on skills or docs alone for versions |

When confidence is below the threshold for the context, say so. "I believe X based on [source], but I have not been able to verify this directly. To confirm, you could [suggested verification step]."

## Quick Reference Decision Table

| What You Are Verifying | Recommended Methods | Minimum Confidence Target |
|------------------------|---------------------|---------------------------|
| Stdlib function exists | `compact-core:compact-standard-library` skill → compile | 90 |
| Compact syntax is valid | Compile with `skipZk=true` | 90 |
| SDK API signature | MCP midnight-search-typescript → source | 90 |
| Package version | `npm view` | 95 |
| CLI flag/behavior | `compact --help` or run directly | 95 |
| Privacy property holds | `compact-core:compact-privacy-disclosure` skill → compile → source | 95 |
| Pattern is correct | `compact-core:compact-patterns` skill → compile | 90 |
| Version compatibility | Direct tooling checks | 95 |
| Network endpoint/config | Direct tooling → docs | 95 |
| Protocol/architecture claim | Skills → docs | 75 |
| Security property | Skills → source → user discussion | 95 |
| Disclosure behavior | `compact-core:compact-privacy-disclosure` skill → compile | 90 |

## Cross-References

| Topic | Skill / Plugin |
|-------|----------------|
| Compact code verification methods | `midnight-verify:verify-compact` |
| SDK/TypeScript verification methods | `midnight-verify:verify-sdk` |
| Stdlib function verification protocol and export inventory | `compact-core:compact-standard-library` |
| Compiler usage, version selection, compile flags | `compact-core:compact-compilation` |
| Troubleshooting verification failures and compile errors | `compact-core:compact-debugging` |
| MCP tool usage (midnight-search-compact, midnight-search-docs, midnight-compile-contract) | `midnight-mcp` plugin |
| CLI commands and flags | `midnight-tooling:compact-cli` |
| Privacy and disclosure verification | `compact-core:compact-privacy-disclosure` |
| Security review methodology | `compact-core:compact-review` |
| Circuit cost analysis | `compact-core:compact-circuit-costs` |
| Deployment and version compatibility | `compact-core:compact-deployment` |
