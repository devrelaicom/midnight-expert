# Compact Examples Plugin Reorganization

**Date:** 2026-04-05
**Plugin:** `plugins/compact-examples/`

## Problem

The compact-examples plugin currently has a single skill (`openzeppelin`) containing only the OpenZeppelin compact-contracts library. There are many more high-quality Compact examples across multiple repositories that agents could benefit from, but they're scattered and not discoverable by topic. Additionally, the plugin only includes `.compact` source files — witnesses and tests are absent.

## Goals

1. Expand the plugin with examples from 8 repositories covering counters, bulletin boards, NFTs, ZK lending, CryptoKitties, math libraries, shielded tokens, RWA, and more.
2. Organize by **capability domain** (not author) so agents find what they need by task.
3. Include **witnesses and tests** alongside every contract.
4. Ensure all Compact code compiles with **language version >= 0.22** and **full proof generation**.

## Source Repositories

| Repository | Content |
|---|---|
| `midnightntwrk/example-counter` | Minimal state counter |
| `midnightntwrk/example-bboard` | Bulletin board with ownership |
| `midnightntwrk/example-zkloan` | ZK credit scoring + Schnorr signatures |
| `midnightntwrk/example-kitties` | CryptoKitties NFT with breeding |
| `riusricardo/midnight-contracts` | NFT and privacy-enhanced NFT-ZK |
| `OpenZeppelin/compact-contracts` | Access control, security, token modules, utils |
| `OpenZeppelin/midnight-apps` | Math libraries, shielded tokens, queue data structure |
| `bricktowers/midnight-rwa` | Real-world assets, passport identity, tBTC |

## Skill Structure

Six skills organized by capability domain:

```
plugins/compact-examples/
  .claude-plugin/
    plugin.json
  skills/
    getting-started/
      SKILL.md
      examples/
        counter/
          counter.compact
          witnesses.ts
        bboard/
          bboard.compact
          witnesses.ts
      references/
        ...
    modules/
      SKILL.md
      examples/
        access/
          Ownable.compact
          ZOwnablePK.compact
          AccessControl.compact
          witnesses/
            OwnableWitnesses.ts
            ZOwnablePKWitnesses.ts
            AccessControlWitnesses.ts
          test/
            Ownable.test.ts
            ZOwnablePK.test.ts
            AccessControl.test.ts
            mocks/
              MockOwnable.compact
              MockZOwnablePK.compact
              MockAccessControl.compact
            simulators/
              OwnableSimulator.ts
              ZOwnablePKSimulator.ts
              AccessControlSimulator.ts
        security/
          Initializable.compact
          Pausable.compact
          witnesses/
            InitializableWitnesses.ts
            PausableWitnesses.ts
          test/
            Initializable.test.ts
            Pausable.test.ts
            mocks/
              MockInitializable.compact
              MockPausable.compact
            simulators/
              InitializableSimulator.ts
              PausableSimulator.ts
        token/
          FungibleToken.compact
          NonFungibleToken.compact
          MultiToken.compact
          Nft.compact
          NftZk.compact
          witnesses/
            FungibleTokenWitnesses.ts
            NonFungibleTokenWitnesses.ts
            MultiTokenWitnesses.ts
            NftWitnesses.ts
            NftZkWitnesses.ts
          test/
            FungibleToken.test.ts
            NonFungibleToken.test.ts
            MultiToken.test.ts
            mocks/
              MockFungibleToken.compact
              MockNonFungibleToken.compact
              MockMultiToken.compact
            simulators/
              FungibleTokenSimulator.ts
              NonFungibleTokenSimulator.ts
              MultiTokenSimulator.ts
        math/
          Uint64.compact
          Uint128.compact
          Uint256.compact
          Bytes8.compact
          Bytes32.compact
          Field255.compact
          Pack.compact
          Types.compact
          witnesses/
            ...
          test/
            ...
        crypto/
          schnorr.compact
          crypto.compact
        data-structures/
          Queue.compact
          witnesses/
            ...
          test/
            ...
        identity/
          passportidentity.compact
        utils/
          Utils.compact
          ShieldedUtils.compact
          witnesses/
            UtilsWitnesses.ts
          test/
            utils.test.ts
            mocks/
              MockUtils.compact
            simulators/
              UtilsSimulator.ts
      references/
        ...
    tokens/
      SKILL.md
      examples/
        AccessControlledToken.compact
        FungibleTokenMintablePausableOwnable.compact
        SimpleNonFungibleToken.compact
        MultiTokenTwoTypes.compact
        ShieldedFungibleToken.compact
        ShieldedERC20.compact
        nft.compact
        nft-zk.compact
        tbtc.compact
        witnesses/
          ...
        test/
          ...
      references/
        ...
    privacy-and-cryptography/
      SKILL.md
      references/
        ...
    applications/
      SKILL.md
      examples/
        kitties/
          kitties.compact
          witnesses.ts
        zkloan/
          schnorr.compact
          zkloan-credit-scorer.compact
          witnesses.ts
        midnight-rwa/
          midnight-rwa.compact
          passportidentity.compact
          crypto.compact
          witnesses.ts
        tbtc/
          tbtc.compact
      references/
        ...
```

### Skill descriptions

| Skill | Purpose | When an agent should use it |
|---|---|---|
| `getting-started` | Minimal contracts for learning Compact basics | "Show me a simple contract", "How does state work?" |
| `modules` | Reusable building blocks you import into contracts | "How do I add access control?", "Is there a math library?", "Show me a Queue implementation" |
| `tokens` | Complete, deployable token contracts that compose modules | "How do I build a fungible token?", "Show me an NFT contract" |
| `privacy-and-cryptography` | ZK patterns, signature verification, identity proofs | "How do I verify signatures?", "How do privacy proofs work?" |
| `applications` | Full multi-module apps demonstrating real-world architecture | "Show me a complete DApp contract", "How do these modules compose?" |

### Co-location rule

Witnesses and tests always live alongside the contract they serve:

- **Contract + witnesses**: same directory, or `witnesses/` subdirectory for modules with multiple witness files
- **Tests**: `test/` subdirectory, with `mocks/` and `simulators/` underneath when present
- **Pure circuit libraries** (no witnesses needed): no `witnesses/` directory — no empty placeholders

### Cross-referencing

Some contracts demonstrate multiple domains (e.g., NFT-ZK is both a token module and a privacy pattern). Each contract lives in **one primary skill** based on its main purpose. Other skills cross-reference it in their SKILL.md routing table:

```markdown
| Privacy-preserving NFTs | See `modules` skill → `examples/token/NftZk.compact` |
```

### The privacy-and-cryptography skill is reference-only

Unlike the other skills, `privacy-and-cryptography` has **no examples/ directory**. The actual contract code lives in `modules/` (Schnorr, NftZk, crypto) and `applications/` (zkloan, midnight-rwa). This skill's value is its reference material — documentation that explains the privacy patterns, cryptographic techniques, and ZK concepts demonstrated across those contracts, with routing to the relevant source files.

### Duplication between modules and applications

The `applications/` skill contains full, self-contained app source trees (e.g., the complete zkloan with both its Schnorr module and credit scorer together). The `modules/` skill contains the extracted, standalone building block (e.g., just the Schnorr module). This intentional duplication means:

- **modules/** shows the building block in isolation — useful for "how do I use this module?"
- **applications/** shows the building block in context — useful for "how do these pieces fit together?"

Both copies must compile independently.

## Compilation Requirements

### Language version

All `.compact` files must use:

```compact
pragma language_version >= 0.22;
```

Most source repos are 1-2 versions behind. Every file must be updated to compile under the current language version before inclusion.

### Full compilation with proof generation

Every example must pass a **full compile including proof generation** — not just syntax checking or `--skip-zk`:

```bash
compact build <contract>.compact
```

This produces the complete output including circuit keys. A contract that compiles with `--skip-zk` but fails full proof generation is **not accepted**.

### Compilation is necessary but not sufficient

Compilation proves the code is syntactically and type-correct. It does not prove the code is semantically correct or that witnesses are compatible. Where tests exist, they must also pass.

### Mock contracts

Mock contracts used for testing modules must also compile with `pragma language_version >= 0.22` and pass full proof generation.

## Migration Process

For each source file being added to the plugin:

1. **Copy** the `.compact` file, its witnesses, and its tests from the cloned repo.
2. **Update** `pragma language_version` to `>= 0.22`.
3. **Fix** any compilation errors introduced by language version changes (syntax changes, removed/renamed stdlib functions, new disclosure requirements, etc.).
4. **Run** `compact build` with full proof generation. Iterate until it passes.
5. **Run tests** if they exist. Fix any failures caused by the language version update.
6. **Place** the files in the correct skill directory per the structure above.

Do not attempt to migrate all files at once. Work skill-by-skill:

1. `getting-started` (2 contracts — smallest, fastest to validate)
2. `modules` (largest — work subdomain by subdomain: access, security, token, math, crypto, data-structures, identity, utils)
3. `tokens` (composed contracts that import modules — depends on modules compiling first)
4. `privacy-and-cryptography` (extract patterns from zkloan, nft-zk, rwa)
5. `applications` (full app trees — last, since they compose everything)

## SKILL.md Structure

Each skill's SKILL.md will contain:

1. **Frontmatter** with name, description, version, and scope keywords
2. **Purpose** — when to use this skill (1-2 sentences)
3. **Reference routing table** — maps topics to specific files
4. **Examples index** — lists all contracts with one-line descriptions
5. **Cross-references** — pointers to related contracts in other skills

## What changes from the current plugin

| Aspect | Before | After |
|---|---|---|
| Skills | 1 (`openzeppelin`) | 6 (domain-based) |
| Contracts | ~20 (OZ only) | ~55 (8 repos) |
| Witnesses | None | Co-located with every contract that needs them |
| Tests | Included but not emphasized | Co-located, required to pass |
| Organization | By author (OpenZeppelin) | By capability domain |
| Language version | Mixed (older versions) | All `>= 0.22` |
| Compilation | Not verified | Full build with proof generation required |
| Sources | compact-contracts | 8 repositories |

## Out of scope

- DApp UI code (React, deployment scripts) — this plugin is about Compact contracts, witnesses, and tests only
- Writing new reference documentation from scratch — reference docs will be migrated and updated from existing material where available, and written fresh only where needed for agent discoverability
- SDK integration examples — covered by other plugins
