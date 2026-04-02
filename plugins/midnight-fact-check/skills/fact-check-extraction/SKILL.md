---
name: midnight-fact-check:fact-check-extraction
description: >-
  This skill should be used when extracting testable claims from Midnight
  documentation or source content. Covers how to identify verifiable
  statements about Compact syntax, types, APIs, compiler behavior, and
  runtime errors. Defines the JSON output schema for structured claim
  lists. Relevant when asked to "extract claims", "find testable
  statements", "parse documentation for verifiable facts", or "produce
  a claim list from content chunks". Used by the claim-extractor agent
  in the midnight-fact-check pipeline.
version: 0.1.0
---

# Claim Extraction

You are extracting **testable claims** from Midnight-related content. A testable claim is a statement that can be verified or refuted through one of these methods:

- Compiling and/or executing a Compact contract
- Running TypeScript type-checks (`tsc --noEmit`)
- Running code against a devnet
- Inspecting compiler, SDK, or ledger source code
- Running the ZKIR WASM checker
- Inspecting compiled ZKIR structure

## What IS a Testable Claim

- Statements about language syntax: "Compact tuples are 0-indexed"
- Statements about types: "persistentHash<T>() returns Bytes<32>"
- Statements about behavior: "Uint subtraction fails at runtime if the result would be negative"
- Statements about APIs: "deployContract returns DeployedContract"
- Statements about errors: "Using deprecated ledger {} syntax produces a parse error"
- Statements about compiler behavior: "disclosure compiles to declare_pub_input in ZKIR"
- Statements about circuit properties: "A pure circuit has no private_input instructions"

## What is NOT a Testable Claim

- General advice: "You should test your contracts thoroughly"
- Subjective statements: "Compact is a simple language"
- Process descriptions: "First, install the CLI tool"
- Definitions without behavior: "A circuit is a function"
- Future plans: "Support for X will be added"
- Meta-documentation: "This section covers..."

## Output Schema

For each claim you extract, produce a JSON object:

```json
{
  "claim": "The verbatim or highly specific claim text",
  "source": {
    "file": "relative/path/to/source/file.md",
    "line_range": [42, 44],
    "context": "Brief surrounding context (the section or heading this claim appears under)"
  }
}
```

### Field Rules

- **claim**: Use the exact wording from the source when possible. If the claim is implicit (spread across sentences), synthesize a single precise statement.
- **source.file**: The file path as provided in your task prompt.
- **source.line_range**: Best-effort line numbers. If you cannot determine exact lines, use `[0, 0]`.
- **source.context**: The heading or section name, e.g., "Standard Library > Hashing Functions".

## Output Format

Return a JSON array of claim objects. Nothing else — no commentary, no markdown wrapping.

```json
[
  {
    "claim": "persistentHash<T>() returns Bytes<32>",
    "source": {
      "file": "skills/compact-language-ref/references/stdlib.md",
      "line_range": [42, 44],
      "context": "Standard Library > Hashing Functions"
    }
  },
  {
    "claim": "Uint subtraction fails at runtime if the result would be negative",
    "source": {
      "file": "skills/compact-language-ref/references/types.md",
      "line_range": [118, 120],
      "context": "Type System > Unsigned Integers"
    }
  }
]
```

## Extraction Guidelines

1. **Be thorough.** Extract every testable claim, even if it seems obvious.
2. **One claim per object.** Do not combine multiple claims into one.
3. **Preserve specificity.** "persistentHash returns Bytes<32>" is better than "persistentHash returns bytes".
4. **Include negative claims.** "Division (/) does NOT exist in Compact" is testable.
5. **Include error claims.** "Using X produces error Y" is testable.
6. **Skip purely illustrative code examples** unless they contain an implicit claim about behavior. For example, a snippet showing `const x: Uint<32> = 5n` is illustrative. But a snippet showing `assert(hash.length === 32)` implicitly claims that the hash output is 32 bytes — extract that.
7. If the content contains no testable claims, return an empty array: `[]`
8. **Split compound claims.** If a statement lists multiple items ("Compact supports Uint<8>, Uint<16>, and Uint<32>"), extract each as a separate claim unless they are inseparable (e.g., "X returns Y and Z" where Y and Z are a single return type).
9. **Preserve duplicates with distinct sources.** If the same fact appears in two locations, extract it twice with the correct source for each. Downstream deduplication is handled separately.
