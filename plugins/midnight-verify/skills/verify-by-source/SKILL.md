---
name: midnight-verify:verify-by-source
description: >-
  Verification by source code inspection. Searches and reads the actual
  compiler, ledger, and runtime source code to verify structural or
  architectural claims about Compact and Midnight that cannot be tested
  via compilation. Uses octocode-mcp for quick lookups, falls back to
  local cloning for deep investigation. Loaded by the source-investigator
  agent.
version: 0.2.0
---

# Verify by Source Code Inspection

You are verifying a claim about Compact or Midnight by reading the actual source code of the compiler, ledger, runtime, or related repositories. Follow these steps in order.

## When This Method Is Used

This method is for claims that **cannot be meaningfully tested by compiling and running code**:

- Language feature counts ("Compact exports 57 primitives")
- Internal implementation details ("Compact compiler is written in Scheme")
- Architectural rationale ("Compact chose Field as the base type because...")
- Cross-component contracts ("Compiled output follows format X")
- Protocol-level behavior that isn't observable from a single contract execution

If the claim CAN be tested by writing and running a contract, the contract-writer agent handles it instead. You only run when execution isn't viable.

## Using compact-core Skills as Hints

You may consult compact-core skills to get a starting point for where to look. They can tell you which stdlib functions are expected to exist, what the type system looks like, etc. But they are **hints only** — the source code is your evidence, not the skills.

## Step 1: Determine Where to Look

**Repository routing — match the claim to the right repo:**

| Claim About | Primary Repo | Key Paths / Notes |
|---|---|---|
| Compiler behavior, language semantics, stdlib | `LFDT-Minokawa/compact` | `compiler/` directory, `midnight-natives.ss` for stdlib exports |
| Compiler-generated docs (good secondary source) | `LFDT-Minokawa/compact` | `docs/` — generated from source, more reliable than general Midnight docs |
| Ledger types, transaction structure, token ops | `midnightntwrk/midnight-ledger` | Rust source — defines Counter, Map, Set, MerkleTree, transaction validation |
| ZK proof system, circuit compilation | `midnightntwrk/midnight-zk` | Rust source — proof generation, ZKIR, circuit constraints |
| Node runtime, on-chain execution | `midnightntwrk/midnight-node` | Rust source — how transactions execute on-chain |
| Compact CLI releases, changelog | `midnightntwrk/compact` | Release notes — distinct from LFDT-Minokawa/compact compiler source |

If the claim doesn't clearly map to one repo, start with `LFDT-Minokawa/compact` for language/compiler claims or `midnightntwrk/midnight-ledger` for protocol/transaction claims.

## Step 2: Search with octocode-mcp

Start with targeted lookups using the `octocode-mcp` tools:

1. **`githubSearchCode`** — search for specific function names, type names, export definitions
2. **`githubGetFileContent`** — read a specific file once you know the path
3. **`githubViewRepoStructure`** — understand the repo layout if you're not sure where to look

**Search strategy:**

- Start narrow: search for the exact term from the claim (function name, type name, keyword)
- If no results, broaden: search for related terms or parent concepts
- Check multiple files if the claim is about something spread across the codebase

**Evaluate results critically:**

- Are you looking at the right branch? Default branch is usually `main` or `master`
- Is this the current version, or an old commit?
- Does the file you found actually contain the information you need, or just a reference to it?

## Step 3: Clone Locally if Needed

If octocode-mcp results are insufficient — you need to trace through multiple files, count exports across modules, or understand control flow — clone the repo locally:

```bash
# Clone to a temp directory
CLONE_DIR=$(mktemp -d)
git clone --depth 1 https://github.com/<org>/<repo>.git "$CLONE_DIR/<repo>"
```

Use `--depth 1` for shallow clones (faster, we usually only need the latest state).

After investigation, clean up:

```bash
rm -rf "$CLONE_DIR"
```

## Step 4: Read and Interpret Source

**What counts as evidence (ordered by strength):**

1. **Function/type/export definitions in source code** — strong evidence. If the source defines a function with signature X, that's definitive.
2. **Test files in the repo** — good evidence. Tests express intended behavior. If a test asserts X, the developers intend X to be true.
3. **Generated docs in `LFDT-Minokawa/compact/docs/`** — good evidence, but note that it's generated from source, not raw source itself. More reliable than general Midnight docs, less authoritative than the code.
4. **Comments in source code** — supporting context only. Comments can be stale. Never use a comment as primary evidence.

**Watch for:**

- Version-specific behavior: the source on `main` may differ from the released version the user is targeting
- Unreleased changes: code on `main` might include features not yet in any release
- Multiple implementations: some behaviors have different implementations for different contexts (e.g., native vs WASM)

## Step 5: Report

**Your report must include:**

1. **The claim as received** — verbatim
2. **Where you looked** — repo name, file path(s), line numbers
3. **What the source shows** — quote or summarize the relevant code
4. **GitHub links** — full URLs to the exact files/lines (e.g., `https://github.com/LFDT-Minokawa/compact/blob/main/compiler/midnight-natives.ss#L42`)
5. **Your interpretation** — does the source confirm, refute, or leave the claim inconclusive?

**Report format:**

```
### Source Investigation Report

**Claim:** [verbatim]

**Searched:** [repo(s) and method — octocode-mcp search / local clone]

**Found:**
- File: [repo/path/to/file.ext:line-range]
- Link: [full GitHub URL]
- Content: [relevant code snippet or summary]

**Interpretation:** [Confirmed / Refuted / Inconclusive] — [explanation of what the source shows and how it relates to the claim]
```

If inconclusive, explain:
- What you searched and why it wasn't definitive
- What further investigation might resolve it (different repo, different approach, needs runtime testing)
