---
name: midnight-verify:verify-tooling
description: >-
  Compact CLI tooling claim classification and method routing. Determines what
  kind of CLI claim is being verified and which verification method applies:
  CLI execution (primary for behavioral claims) or source investigation
  (for internal/architectural claims). Handles claims about compact compile
  flags, compactc behavior, compiler output structure, error messages, exit
  codes, version management, and CLI installation. Loaded by the verifier
  agent alongside the hub skill.
version: 0.1.0
---

# Tooling Claim Classification

This skill classifies Compact CLI tooling claims and determines which verification method to use. The verifier (orchestrator) agent loads this alongside the hub skill (`verify-correctness`).

## Distinction from verify-compact

- **verify-compact** handles claims about the Compact *language* — syntax, types, stdlib, disclosure rules, patterns
- **verify-tooling** handles claims about the CLI *tool* — flags, output structure, error messages, versions, installation

**Routing rule:** If the claim is about what the language allows/disallows, route to verify-compact. If the claim is about what the CLI does when you run it, route here.

**Overlap:** "The compiler rejects X" could be either. If the claim is about a language rule ("you can't assign Field to Uint<8>"), it's Compact. If the claim is about CLI behavior ("the compiler exits with code 1 on syntax errors"), it's tooling.

## Verification Flow

CLI execution is the default. Source investigation is for when you genuinely can't run a command to answer the question.

1. **CLI execution (primary)** — dispatch cli-tester. Run the command, observe stdout/stderr/exit code/filesystem. This is the most authoritative evidence for behavioral claims.
2. **Source investigation (secondary)** — dispatch source-investigator (uses existing `verify-by-source`). For internal/architectural claims about how the compiler works under the hood.

## Claim Type → Method Routing

| Claim Type | Example | Primary | Secondary |
|---|---|---|---|
| Flag existence | "--skip-zk is a valid flag" | cli-tester (run --help, check output) | — |
| Flag behavior | "--skip-zk skips PLONK key generation" | cli-tester (compile with/without, compare output dirs) | source-investigator |
| Output structure | "Compilation produces build/contract/index.js" | cli-tester (compile, inspect filesystem) | — |
| Error messages | "Undeclared variables produce 'not in scope' error" | cli-tester (feed bad input, check stderr) | source-investigator |
| Exit codes | "Compilation errors exit with non-zero" | cli-tester (run, check $?) | — |
| Version info | "--language-version returns the current version" | cli-tester (run, parse output) | — |
| Installation | "compact is installed via npm" | cli-tester (check which compact) | source-investigator |
| CLI vs compactc | "compact compile invokes compactc" | cli-tester (run both, compare) | source-investigator |
| Compiler internals | "The compiler is written in Scheme" | source-investigator | — |
| CLI wrapper internals | "compact is a shell script wrapper" | source-investigator | cli-tester (file type check) |

### Routing Rules

**When in doubt:**
- If you can answer the question by running a command → cli-tester
- If you need to read source code to understand internal behavior → source-investigator
- If both apply → dispatch both concurrently

**CLI execution is preferred whenever possible.** The command ran and produced this output — that's more authoritative than reading source code about what the output *should* be.

## Hints from Existing Skills

The cli-tester may consult this skill for context. It is a **hint only** — never cite it as evidence.

- `midnight-tooling:compact-cli` — expected flags, compilation patterns, version management
