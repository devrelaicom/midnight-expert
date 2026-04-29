# Manual Smoke Checklist

Run before tagging a release that touches the feedback skill. None of these are CI-gated.

## Setup

- [ ] Ensure `gh` is installed and authed: `gh auth status`
- [ ] Confirm a recent session JSONL exists at `~/.claude/projects/-Users-<you>-Projects-midnight-midnight-expert/<recent-id>.jsonl`
- [ ] Note the marketplace version: `jq .metadata.version .claude-plugin/marketplace.json`
- [ ] Note the plugin version: `jq .version plugins/midnight-expert/.claude-plugin/plugin.json`

## Smoke runs

### 1. Clean bug, current session

- [ ] Trigger an intentional, harmless error in a session (e.g., `compact compile <missing-file>`)
- [ ] Invoke `/midnight-expert:feedback the compact compile command failed`
- [ ] Verify: route inferred as `issue`, plugin inferred without asking, evidence cards include the failing tool call, body composes cleanly
- [ ] **Cancel before filing.** Do NOT actually create a public issue during smoke.
- [ ] Check that no draft was saved (cancel path is clean)

### 2. Enhancement

- [ ] Invoke `/midnight-expert:feedback it would be nice if /doctor showed compact version in the summary`
- [ ] Verify: route inferred as `enhancement`, single textarea confirmation, plugin label `midnight-expert` (or asked)
- [ ] Cancel before filing

### 3. PII / secret in prose

- [ ] Invoke with prose containing a fake-but-shaped secret: `/midnight-expert:feedback I keep getting "AKIA1234567890ABCDEF" in my logs even though my .env is gitignored`
- [ ] Verify: in the rendered final body shown for review, the AKIA-shaped string is replaced with `[REDACTED-SECRET]`
- [ ] Cancel before filing

### 4. gh missing / unauthed

- [ ] Temporarily remove gh from PATH: `PATH=/usr/bin:/bin /midnight-expert:feedback ...`
- [ ] Verify: skill detects the failure, saves a draft to `${CLAUDE_PLUGIN_DATA}/.feedback/drafts/`, prints the path, prints a paste-ready command
- [ ] Inspect the draft file: contents match what would have been filed

### 5. Empty prose

- [ ] Invoke `/midnight-expert:feedback` with no args
- [ ] Skip the prompt twice (empty replies)
- [ ] Verify: skill aborts cleanly with "no feedback captured"

## Done

If all five smoke runs pass, the skill is ready to release.
