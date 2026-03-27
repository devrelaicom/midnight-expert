# Code-Specific Search

Techniques specifically for searching code patterns in Compact and TypeScript.

## Symbol-Aware Search

**When to apply:** When the query targets a specific named symbol — a type, function, module, circuit, or constructor.

Detect symbol names in the query. Compact symbols include: `Counter`, `MerkleTree`, `Map`, `Set`, `Bytes`, `Uint`, `Field`, `Boolean`, `Void`, `Optional`, `Vector`, `persistentHash`, `persistentCommit`, `pad`, `merge`, `assert`. TypeScript symbols include: `ContractAddress`, `DeployedContract`, `MidnightProvider`, `WalletProvider`, `Transaction`, `NodeApiClient`.

Use exact symbol names in queries — do not paraphrase (`Counter` not "counter variable", `MerkleTree` not "tree data structure"). For stdlib functions, cross-reference with `compact-core:compact-standard-library`.

**Examples:** `examples/symbol-aware-search.md`

## Error-to-Doc Search

**When to apply:** When the user provides a compiler error, runtime error, or stack trace.

Extract the distinctive parts of the error message — error codes, specific function names mentioned, type mismatch details. Strip the file-specific context (line numbers, file paths) that will not match in the index. Rewrite into a search query using the error's key terms. For Compact compiler errors, include both the error text and the likely cause terms. For TypeScript runtime errors, include the package name and error type.

**Examples:** `examples/error-to-doc.md`

## Example Mining

**When to apply:** When the user needs runnable, complete code examples rather than documentation or partial snippets.

Bias search queries toward finding complete implementations. Add terms like `example`, `contract`, `circuit export` for Compact code. For TypeScript, add `example`, `implementation`, `deploy`. Prefer results that include full file content over single-function snippets. Check `source.repository` — official example repos (`midnightntwrk/examples`, `midnightntwrk/midnight-examples`) are the richest source. The MCP tool `midnight-list-examples` (from `midnight-mcp:mcp-overview`) can also list available example contracts with complexity ratings.

**Examples:** `examples/example-mining.md`

## Version-Aware Search

**When to apply:** When the user's project targets a specific Compact language version or SDK version, and results from other versions could be misleading or incorrect.

Determine the target version from environmental grounding (Context Gathering cluster) or user context. Include version-specific terms in the query where relevant. After retrieval, check `source.repository` metadata for version indicators. Deprioritize results from significantly different versions. Be especially careful with import paths, API signatures, and syntax that changes between versions.

**Examples:** `examples/version-aware-search.md`

## Diff-Aware Search

**When to apply:** When the user is in a PR review, migration, or refactoring context and the search should be informed by what is changing.

Identify the files being changed (from git diff, open PR, or user description). Use the changed file paths, modified function names, and affected types as search context. For migrations, search for the specific constructs being migrated. For PR reviews, search for patterns that the PR is trying to implement to verify correctness.

**Examples:** `examples/diff-aware-search.md`
