---
name: midnight-fact-check:fact-check-extraction
description: >-
  Claim extraction skill for the midnight-fact-check pipeline. Defines what
  constitutes a testable claim in Midnight documentation, how to identify
  claims in source content, the JSON output schema, and examples of good
  vs bad extractions. Used by the claim-extractor agent to parse content
  chunks and produce structured claim lists.
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
6. **Skip code examples that are purely illustrative** unless they contain an implicit claim about behavior.
7. If the content contains no testable claims, return an empty array: `[]`
