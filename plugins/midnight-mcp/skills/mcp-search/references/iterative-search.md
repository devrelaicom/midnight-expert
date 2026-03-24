# Iterative Search

Techniques for refining when initial results are insufficient. These techniques trigger a second (or third) search pass.

## Retrieve-Read-Retrieve

**When to apply:** When initial results partially answer the question but leave gaps, or when reading results reveals that the question has a dimension that the original query missed.

Read the initial results carefully. Identify what aspects of the question remain unanswered. Formulate a targeted follow-up query that specifically addresses the gap. Do NOT repeat the original query — the follow-up must target different content. Limit to one follow-up pass; if two rounds do not produce answers, the information may not be in the index.

**Examples:** `examples/retrieve-read-retrieve.md`

## Query Refinement

**When to apply:** When results are too broad (many results, none specific enough) or too narrow (few or no results).

- Too broad — add specificity: more Midnight-specific terms, type names, construct names
- Too narrow — remove constraints: fewer terms, more general concepts, drop version-specific terms
- Wrong results entirely — rethink the query approach, possibly switch tools or use a different technique from the Query Expansion cluster

**Examples:** `examples/query-refinement.md`

## Confidence Assessment

**When to apply:** After every search, before presenting results to the user.

Assess the result set:
- **High confidence**: multiple results from trusted sources agree, covering the full question. Present results.
- **Medium confidence**: some relevant results but gaps, or results from lower-trust sources. Note the gaps, consider a follow-up search.
- **Low confidence**: few relevant results, conflicting information, or results that do not directly address the question. Do a follow-up search, try a different technique, or flag the uncertainty to the user.

This is about search sufficiency, not result trustworthiness (which belongs to `compact-core:verify-correctness`).

**Examples:** `examples/confidence-assessment.md`

## Contradiction Detection

**When to apply:** When multiple search results provide conflicting information about the same topic.

When results disagree (different function signatures, different behaviors described, different recommendations), do NOT silently pick one. Flag both results to the user with their sources. Note which source is more authoritative (trust hierarchy) and more recent (freshness). If the contradiction might be due to version differences, note the versions. Let the user or the verification skill resolve the conflict.

**Examples:** `examples/contradiction-detection.md`
