---
name: midnight-verify:verify-tooling
description: >-
  Compact CLI tooling claim classification and method routing. Determines what
  kind of CLI claim is being verified and which verification method applies:
  CLI execution (primary for behavioral claims) or source investigation
  (for internal/architectural claims). Handles claims about compact compile
  flags, compactc behavior, compiler output structure, error messages, exit
  codes, version management, and CLI installation. Loaded by the /midnight-verify:verify
  command alongside the hub skill.
version: 0.1.0
---

# Tooling Claim Classification

This skill classifies Compact CLI tooling claims and determines which verification method to use. The /midnight-verify:verify command loads this alongside the `midnight-verify:verify-correctness` hub skill.

## Distinction from verify-compact

- **verify-compact** handles claims about the Compact *language* — syntax, types, stdlib, disclosure rules, patterns
- **verify-tooling** handles claims about the CLI *tool* — flags, output structure, error messages, versions, installation

**Routing rule:** If the claim is about what the language allows/disallows, route to verify-compact. If the claim is about what the CLI does when you run it, route here.

**Overlap:** "The compiler rejects X" could be either. If the claim is about a language rule ("you can't assign Field to Uint<8>"), it's Compact. If the claim is about CLI behavior ("the compiler exits with code 1 on syntax errors"), it's tooling.

## Verification Flow

CLI execution is the default. Source investigation is for when you genuinely can't run a command to answer the question.

1. **CLI execution (primary)** — dispatch @"midnight-verify:cli-tester (agent)". Run the command, observe stdout/stderr/exit code/filesystem. This is the most authoritative evidence for behavioral claims.
2. **Source investigation (secondary)** — dispatch @"midnight-verify:source-investigator (agent)" (loads the `midnight-verify:verify-by-source` skill). For internal/architectural claims about how the compiler works under the hood.

## Claim Type → Method Routing

| Claim Type | Example | Primary | Secondary |
|---|---|---|---|
| Flag existence | "--skip-zk is a valid flag" | @"midnight-verify:cli-tester (agent)" (run --help, check output) | — |
| Flag behavior | "--skip-zk skips PLONK key generation" | @"midnight-verify:cli-tester (agent)" (compile with/without, compare output dirs) | @"midnight-verify:source-investigator (agent)" |
| Output structure | "Compilation produces build/contract/index.js" | @"midnight-verify:cli-tester (agent)" (compile, inspect filesystem) | — |
| Error messages | "Undeclared variables produce 'not in scope' error" | @"midnight-verify:cli-tester (agent)" (feed bad input, check stderr) | @"midnight-verify:source-investigator (agent)" |
| Exit codes | "Compilation errors exit with non-zero" | @"midnight-verify:cli-tester (agent)" (run, check $?) | — |
| Version info | "--language-version returns the current version" | @"midnight-verify:cli-tester (agent)" (run, parse output) | — |
| Installation | "compact is installed via npm" | @"midnight-verify:cli-tester (agent)" (check which compact) | @"midnight-verify:source-investigator (agent)" |
| CLI vs compactc | "compact compile invokes compactc" | @"midnight-verify:cli-tester (agent)" (run both, compare) | @"midnight-verify:source-investigator (agent)" |
| Compiler internals | "The compiler is written in Scheme" | @"midnight-verify:source-investigator (agent)" | — |
| CLI wrapper internals | "compact is a shell script wrapper" | @"midnight-verify:source-investigator (agent)" | @"midnight-verify:cli-tester (agent)" (file type check) |

### Routing Rules

**When in doubt:**
- If you can answer the question by running a command → @"midnight-verify:cli-tester (agent)"
- If you need to read source code to understand internal behavior → @"midnight-verify:source-investigator (agent)"
- If both apply → dispatch both concurrently

**CLI execution is preferred whenever possible.** The command ran and produced this output — that's more authoritative than reading source code about what the output *should* be.

## Hints from Existing Skills

The @"midnight-verify:cli-tester (agent)" may load this skill for context. It is a **hint only** — never cite skill content as evidence.

- `midnight-tooling:compact-cli` skill — expected flags, compilation patterns, version management
