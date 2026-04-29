# Inference Rubric

Concrete guidance for Phase 2 silent inference. The skill reads this file to apply the rules consistently.

## Inputs

You will receive:

- **prose** — the user's opening message
- **recent-sessions.json** — last ~10 session entries (sessionId, startedAt, gitBranch, firstUserPrompt)
- **failure-signature.json** — counts and event summaries from the current session
- **plugin-candidates.json** — slugs derived from prose mentions, failing tool calls, and active-in-session
- **environment.json** — environment metadata

## Output (must be valid JSON)

```json
{
  "route": "issue" | "enhancement",
  "route_confidence": "high" | "medium" | "low",
  "session_pointer": "current" | "older" | "ambiguous",
  "session_candidates": ["<sessionId>", ...],
  "plugin_label": "<slug>" | null,
  "plugin_confidence": "high" | "medium" | "low",
  "expected_anchor_draft": "<prose>" | null,
  "intent_anchor_draft": "<prose>" | null
}
```

If you can't produce one of these confidences with structural certainty, emit `medium` or `low`. Do not invent `high`.

## Route

- **enhancement** when the prose contains imperative-future framing — *"would be nice if"*, *"I wish"*, *"please add"*, *"feature request"*, *"can we have"*, *"missing"* — AND no failing event in `failure-signature.json` matches the prose's symptom.
- **issue** otherwise.

Confidence:

- **high** when one signal is unambiguous (the prose explicitly says "bug" or "feature request"; or the prose's verbs map cleanly to a failure event in the signature).
- **medium** when the prose contains both bug-framing and feature-request-framing.
- **low** when neither pattern is clearly present.

## Session pointer

- **current** when at least one prose detail (failing tool name, plugin slug, error message fragment, file path mentioned) matches an event or artifact in the current session's JSONL / failure-signature.
- **older** when prose details match an entry in `recent-sessions.json` (other than the current session) but not the current session.
- **ambiguous** when matches appear in both, or in neither.

When `older` or `ambiguous`, populate `session_candidates` with the relevant `sessionId`s, ordered by likelihood (best match first).

## Plugin label

Apply the structural rule literally:

- **high confidence ONLY when both:**
  1. `plugin-candidates.fromFailingTools` contains exactly one slug, AND
  2. `plugin-candidates.fromProse` is either empty or contains exactly the same single slug.
- **medium** when prose and failing-tools agree on a slug but the failing-tools list is empty or has multiple entries.
- **low** when prose and failing-tools disagree, or when no candidate is derivable.

If `plugin_confidence` is `low` and there are no candidates at all, set `plugin_label` to `null`. Otherwise pick the most likely candidate.

## Anchor drafts

- **expected_anchor_draft**: 1–2 sentences describing what the user expected to happen, drawn from the prose. If the prose contains *"I expected X"* or *"X should have happened"*, lift it directly. If you can't derive an expectation from the prose, emit `null`.
- **intent_anchor_draft**: 1–2 sentences describing what the user was trying to do. If the prose explicitly says *"I was trying to X"* or describes a task ("compiling the contract"), lift it. If unclear, emit `null`.

Never fabricate anchors. `null` is a valid output and triggers a user prompt downstream.

## After producing JSON

Return ONLY the JSON object. No prose around it. Validation in SKILL.md will retry once with a stricter prompt if the output isn't parseable.
