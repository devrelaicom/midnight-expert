---
name: midnight-verify:verify
description: Verify claims about Midnight, Compact code, or SDK APIs. Accepts a claim, file path, code snippet, SDK question, or no arguments to be prompted.
allowed-tools: Agent, AskUserQuestion, Read, Glob, Grep
argument-hint: "[claim, file path, code snippet, or SDK question]"
---

Verify Midnight-related claims by dispatching the `midnight-verify:verifier` agent.

## Input Routing

Determine what `$ARGUMENTS` contains and dispatch accordingly:

### 1. No arguments

If `$ARGUMENTS` is empty, use `AskUserQuestion` to ask:

> What would you like to verify? You can provide:
> - A claim (e.g., "Compact stdlib has a sha256 function")
> - A file path (e.g., `contracts/my-contract.compact`)
> - A code snippet
> - An SDK question (e.g., "midnight-js-contracts supports ERC-20 style tokens")

Do NOT attempt to infer what the user wants to verify. Ask them.

### 2. File path

If `$ARGUMENTS` looks like a file path (ends in `.compact`, `.ts`, `.tsx`, or exists on disk when checked with Glob):

1. Read the file content
2. Dispatch `midnight-verify:verifier` agent with:
   - The file path
   - The file content
   - Instruction: "Verify the correctness of this file. Check for any Midnight-related claims, Compact code correctness, or SDK API usage. Report findings with the structured verdict format."

### 3. Code snippet

If `$ARGUMENTS` contains code syntax (keywords like `ledger`, `circuit`, `witness`, `export`, `import`, `contract`, `const`, `function`, curly braces, semicolons, type annotations):

1. Dispatch `midnight-verify:verifier` agent with:
   - The code snippet as inline content
   - Instruction: "Verify the correctness of this code snippet. Determine if it is Compact or TypeScript and apply the appropriate verification methods. Report findings with the structured verdict format."

### 4. Natural language claim or question

If `$ARGUMENTS` is natural language (a question or assertion):

1. Dispatch `midnight-verify:verifier` agent with:
   - The claim verbatim
   - Instruction: "Verify this claim about Midnight. Classify the domain, load appropriate skills, run verification methods, and report with the structured verdict format."

### 5. Multiple files or directory

If `$ARGUMENTS` is a directory path or contains glob patterns:

1. Use Glob to find all `.compact` and `.ts` files matching the path
2. Present the file list to the user for confirmation
3. Dispatch `midnight-verify:verifier` agent for each file (or as a batch if fewer than 5 files)

## Output

Present the agent's structured verdict directly to the user. Do not add commentary or interpretation — the verdict speaks for itself.
