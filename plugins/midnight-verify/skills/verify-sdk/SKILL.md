---
name: verify-sdk
description: >-
  This skill should be used when verifying claims about the Midnight TypeScript SDK,
  including API function signatures, type definitions, package existence and versions,
  import paths, provider setup, DApp connector API, witness implementation patterns,
  and cross-component version alignment. Loaded by the verify-correctness hub skill
  when a claim is classified as SDK-related. Provides SDK-specific verification methods
  and a reference file mapping @midnight-ntwrk packages to their GitHub source repositories.
version: 0.1.0
---

# Midnight SDK Verification

This skill provides SDK/TypeScript-specific verification methods. For generic verification methodology, confidence scoring, and escalation rules, see the hub skill at `midnight-verify:verify-correctness`.

## SDK-Specific Verification Methods

Three methods for verifying SDK-related claims, ordered by confidence.

### MCP midnight-search-typescript (Confidence: 20-45)

Use the `midnight-mcp` plugin's `midnight-search-typescript` tool to search indexed TypeScript code.

- Check `relevanceScore` on results — higher scores indicate better matches
- Source repositories from `midnightntwrk` are generally more trustworthy than community or third-party code
- Indexed code may be outdated relative to the latest SDK release — a function appearing in search results does not guarantee it exists in the current release
- Useful for finding usage patterns and examples; less useful for confirming exact API signatures

### MCP midnight-search-docs (Confidence: 20-30)

Use the `midnight-mcp` plugin's `midnight-search-docs` tool.

- The docs search index may lag behind actual releases. Always verify claims found in docs independently using higher-confidence methods
- Check `relevanceScore` — low-scoring results are often tangentially related or outdated
- Most reliable for conceptual explanations and architecture; less reliable for API signatures and exact types

### Midnight Expert Skills (Confidence: 60-80)

Use skills from the `dapp-development` and `compact-core` plugins which contain verified reference material:

- `dapp-development:midnight-sdk` — SDK package reference, provider setup, and component overview
- `dapp-development:dapp-connector` — DApp connector API, wallet integration patterns
- `compact-core:compact-witness-ts` — Witness implementation patterns in TypeScript
- `compact-core:compact-deployment` — Deployment patterns and version compatibility

Skills contain verified reference material but may lag behind the latest SDK releases. Reliable for architecture, patterns, and provider setup. Less reliable for version-specific details or recently changed APIs.

## Categories of Things to Verify

### SDK / TypeScript

| What to Verify | Methods | Notes |
|---|---|---|
| API function signature | MCP search-typescript → skill → source | Check the actual package, not just types |
| Package exists / correct version | `npm view` | Definitive — always use direct tooling |
| Import path is correct | MCP search-typescript → compile test | Import paths change between major versions |
| Type definitions | MCP search-typescript → source | Check .d.ts files in the package |

### Configuration / Operations

| What to Verify | Methods | Notes |
|---|---|---|
| Network endpoints | Direct tooling → docs | Endpoints differ between devnet, testnet, mainnet |
| Docker image tags | `gh release list` / Docker Hub | Tags follow release versioning |
| CLI flags and commands | `compact --help` or run directly | CLI behavior is definitive |
| Version compatibility matrix | Direct tooling → release notes | Check all components being combined |

### Cross-Component Compatibility

| What to Verify | Methods | Notes |
|---|---|---|
| SDK ↔ compiler version alignment | `npm view` + `compact check` → release notes | Version mismatches are the most common integration issue |
| Network differences (devnet vs testnet vs mainnet) | Docs → direct tooling | Network IDs, endpoints, and available features differ |
| Runtime compatibility | Direct tooling → source | Node.js version requirements, browser support |

### Tooling Behavior

| What to Verify | Methods | Notes |
|---|---|---|
| CLI behavior | Run the command directly | CLI output is definitive |
| Proof server capabilities | Health endpoint → docs | Check the running instance's version |
| Indexer queries | GraphQL introspection → docs | Schema may differ between versions |

## Source Code Repositories

For a complete mapping of `@midnight-ntwrk/*` packages to their GitHub source repositories, see the `references/sdk-repo-map.md` reference file.

## Cross-References

| Topic | Skill / Plugin |
|-------|----------------|
| Generic verification methodology and confidence scoring | `midnight-verify:verify-correctness` |
| Compact code verification | `midnight-verify:verify-compact` |
| SDK package reference and provider patterns | `dapp-development:midnight-sdk` |
| DApp connector API | `dapp-development:dapp-connector` |
| Witness implementation patterns | `compact-core:compact-witness-ts` |
| Deployment and version compatibility | `compact-core:compact-deployment` |
| MCP tool usage | `midnight-mcp` plugin |
