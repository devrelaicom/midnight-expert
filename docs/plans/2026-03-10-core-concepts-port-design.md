# Design: Port midnight-core-concepts to core-concepts

## Goal

Port the `midnight-core-concepts` plugin from the knowledgebase repo to `plugins/core-concepts/` in this marketplace, with every claim verified against the Midnight MCP server, octocode, and the Midnight docs repo.

## Source & Destination

- **From:** `/Users/aaronbassett/Projects/midnight/midnight-knowledgebase/plugins/midnight-core-concepts/`
- **To:** `plugins/core-concepts/` (this repo)

## Structure

Keep the existing 6-skill structure + concept-explainer agent unless fact-checking reveals restructuring is needed:

```
plugins/core-concepts/
├── .claude-plugin/
│   └── plugin.json        # updated name: core-concepts
├── agents/
│   └── concept-explainer.md
└── skills/
    ├── data-models/        (SKILL.md, references/, examples/)
    ├── architecture/       (SKILL.md, references/, examples/)
    ├── zero-knowledge/     (SKILL.md, references/, examples/)
    ├── privacy-patterns/   (SKILL.md, references/, examples/)
    ├── smart-contracts/    (SKILL.md, references/, examples/)
    └── protocols/          (SKILL.md, references/, examples/)
```

## Verification Process (per skill)

For each skill in order: data-models, architecture, zero-knowledge, privacy-patterns, smart-contracts, protocols.

1. **Read** all source files (SKILL.md + references + examples)
2. **Fact-check** every claim against:
   - Midnight MCP server (authoritative source for Compact/protocol details)
   - Octocode (search Midnight repos for implementation evidence)
   - Midnight docs repo (`github.com/midnightntwrk`)
3. **Produce findings report** saved to `docs/findings/core-concepts/<skill-name>.md` with:
   - Verified claims
   - Inaccuracies found (with correct information)
   - Ambiguities that need clarification
   - Missing information worth adding
4. **Port corrected version** to `plugins/core-concepts/skills/<skill-name>/`

## Approach

- Launch midnight-fact-checker agents per skill for deep verification
- Use Midnight MCP tools (midnight-search-docs, midnight-search-compact, midnight-get-latest-syntax) as primary sources
- Use octocode to search actual Midnight source repos for implementation evidence
- Fix inline and document what changed

## What We're NOT Doing

- Not modifying compact-core or any other existing plugin
- Not restructuring unless evidence demands it
- Not adding new content beyond what fact-checking reveals as missing

## Skill Processing Order

1. data-models (UTXO/ledger fundamentals)
2. architecture (system structure, transaction model)
3. zero-knowledge (ZK proofs, circuits)
4. privacy-patterns (commitments, Merkle trees, nullifiers)
5. smart-contracts (Compact, Impact VM)
6. protocols (Kachina, Zswap)
