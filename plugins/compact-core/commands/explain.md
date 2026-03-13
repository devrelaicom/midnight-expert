---
description: Explain Compact smart contract code, concepts, or patterns — provide a .compact file path, code snippet, or concept name
allowed-tools: Bash, Read, Glob, Grep, Skill, AskUserQuestion
argument-hint: [<file.compact> | "<concept>" | --interactive]
---

Explain Compact smart contract code, concepts, or patterns to the user.

## Step 1 — Parse Arguments

Analyze `$ARGUMENTS` to determine what the user wants explained:

| Input | Mode | Next Step |
|-------|------|-----------|
| Path ending in `.compact` | File explanation | Step 2 |
| Known concept keyword (see table below) | Concept explanation | Step 3 |
| Code block or snippet text | Snippet explanation | Step 3 |
| Nothing or `--interactive` | Interactive | Step 4 |
| Unrecognized input | Clarification | Step 4 |

**Concept keywords** (non-exhaustive — match liberally):
`disclose`, `disclosure`, `privacy`, `sealed`, `witness`, `circuit`, `ledger`, `constructor`, `types`, `casting`, `enum`, `struct`, `Map`, `Set`, `Counter`, `MerkleTree`, `tokens`, `FungibleToken`, `NFT`, `deployment`, `compilation`, `transaction`, `UTXO`, `patterns`, `access control`, `state machine`, `commit-reveal`, `escrow`

## Step 2 — File Explanation

When a `.compact` file path is provided:

1. Verify the file exists using Read. If not found, ask the user to confirm the path.
2. Read the full file content.
3. Invoke the skill: use the Skill tool to invoke `compact-core:compact-explain`.
4. Pass the file content as context so the skill can structure its explanation.

## Step 3 — Concept or Snippet Explanation

When a concept keyword or code snippet is provided:

1. Invoke the skill: use the Skill tool to invoke `compact-core:compact-explain`.
2. Pass the concept name or snippet text as context.

## Step 4 — Interactive Mode

If no arguments or unrecognized input:

Use AskUserQuestion to ask:

> What would you like me to explain? You can provide:
> - A `.compact` file path (e.g., `src/contract.compact`)
> - A concept (e.g., "disclosure", "sealed ledger", "witnesses")
> - A code snippet (paste Compact code directly)

Then route to Step 2 or Step 3 based on the response.
