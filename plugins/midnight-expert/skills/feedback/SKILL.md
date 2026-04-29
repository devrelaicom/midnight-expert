---
name: midnight-expert:feedback
description: This skill should be used when the user asks to "file feedback", "report a bug", "report an issue", "file an issue", "request a feature", "submit feedback", "send feedback to maintainers", or invokes /midnight-expert:feedback. Routes to a GitHub issue or enhancement on devrelaicom/midnight-expert. The user types one paragraph; the skill silently scans the session transcript and environment, applies heavy redaction, and composes a maintainer-ready issue body.
version: 0.1.0
---

# Feedback

Route a user's feedback to GitHub on `devrelaicom/midnight-expert` with minimal user effort. The user contributes intent and expectation; the skill provides everything else.

## Allowed Tools

Bash, Read, Write, AskUserQuestion

## Phase 0 — Capture opening prose

If the slash-command was invoked with arguments, those are the opening prose. Otherwise ask the user:

> "What's the feedback?"

Accept the user's free-text reply as `prose`. If `prose` is empty or whitespace-only, ask once more:

> "I need a sentence or two to get started — what's the feedback?"

If the second reply is also empty, abort cleanly: print *"Cancelled — no feedback captured."* and stop.

Save `prose` to `/tmp/feedback-prose.txt` using the Write tool (cleaner than heredoc bash).

## Phase 1 — Collect structured context

Determine the current session's JSONL file. The encoded project key is `cwd` with `/` replaced by `-`:

```bash
PROJECT_KEY="$(printf '%s' "$PWD" | sed 's|/|-|g')"
SESSIONS_DIR="$HOME/.claude/projects/$PROJECT_KEY"

CURRENT_JSONL=""
if [ -d "$SESSIONS_DIR" ]; then
  if cur_bsd=$(find "$SESSIONS_DIR" -maxdepth 1 -type f -name '*.jsonl' -print0 \
      | xargs -0 stat -f '%m %N' 2>/dev/null | sort -rn | head -1 | awk '{ $1=""; sub(/^ /,""); print }'); then
    CURRENT_JSONL="$cur_bsd"
  fi
  if [ -z "$CURRENT_JSONL" ]; then
    CURRENT_JSONL=$(find "$SESSIONS_DIR" -maxdepth 1 -type f -name '*.jsonl' -print0 \
      | xargs -0 stat -c '%Y %n' 2>/dev/null | sort -rn | head -1 | awk '{ $1=""; sub(/^ /,""); print }' || true)
  fi
fi
```

Then in a single message, run these in parallel Bash tool calls (independent):

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/collect-environment.sh" > /tmp/feedback-environment.json
```

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/list-recent-sessions.sh" "$PWD" > /tmp/feedback-recent-sessions.json
```

If `CURRENT_JSONL` is non-empty, also run (depends on the JSONL path):

```bash
node "${CLAUDE_SKILL_DIR}/scripts/extract-failure-signature.js" "$CURRENT_JSONL" > /tmp/feedback-failure-signature.json
```

```bash
KNOWN="$(jq -r '.plugins | keys | join(",")' /tmp/feedback-environment.json)"
node "${CLAUDE_SKILL_DIR}/scripts/plugin-name-detection.js" \
  --prose-file /tmp/feedback-prose.txt \
  --jsonl-file "$CURRENT_JSONL" \
  --plugins "$KNOWN" \
  > /tmp/feedback-plugin-candidates.json
```

If `CURRENT_JSONL` is empty (no session JSONLs found), substitute these defaults:

```bash
echo '{"events":[],"counts":{"tool-error":0,"nonzero-exit":0,"hook-event":0,"exception":0}}' > /tmp/feedback-failure-signature.json
echo '{"fromProse":[],"fromFailingTools":[],"activeInSession":[]}' > /tmp/feedback-plugin-candidates.json
```

### Failure handling

If individual scripts fail, fall back to `null` / empty for that field. If `~/.claude/projects/` doesn't exist at all, abort with:

> "I can't read your session storage at `~/.claude/projects/`. Re-run from a Claude Code session."

## Phase 2 — Silent inference

Read `${CLAUDE_SKILL_DIR}/references/inference-rubric.md`. Then read in parallel:

- `/tmp/feedback-prose.txt`
- `/tmp/feedback-recent-sessions.json`
- `/tmp/feedback-failure-signature.json`
- `/tmp/feedback-plugin-candidates.json`
- `/tmp/feedback-environment.json`

Apply the rubric to produce a JSON object matching this exact schema:

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

Save it to `/tmp/feedback-inference.json` using the Write tool. Do not include any prose around the JSON.

If your output is unparseable, retry once with stricter framing. If still unparseable, save the prose to a draft and abort:

```bash
DRAFT_DIR="$CLAUDE_PLUGIN_DATA/.feedback/drafts"
mkdir -p "$DRAFT_DIR"
cp /tmp/feedback-prose.txt "$DRAFT_DIR/$(date -u +%Y%m%dT%H%M%SZ)-prose-only.md"
```

Print: *"I couldn't analyze the feedback. Your prose is saved at <path>. Try again or file manually at https://github.com/devrelaicom/midnight-expert/issues/new"*

(Phase 3 + Phase 4 dispatch in next section.)
