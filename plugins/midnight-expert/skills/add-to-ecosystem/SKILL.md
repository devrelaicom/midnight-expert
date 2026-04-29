---
name: midnight-expert:add-to-ecosystem
description: This skill should be used when the user asks to "add my project to the Midnight ecosystem", "submit to Electric Capital", "make my repo eligible for the EC report", "add Midnight topics to my repo", "add the Midnight attribution to my README", or invokes /midnight-expert:add-to-ecosystem. Walks the project through the four Electric Capital eligibility requirements (on GitHub, public, `midnightntwrk` topic, optional `compact` topic) and inserts the canonical attribution sentence into the README, then commits / pushes / opens a PR.
version: 0.1.0
---

# Add to Midnight Ecosystem

Walk the user's current project through the Electric Capital eligibility checklist and apply any missing fixes. Use the canonical text in `references/ec-criteria.md` — never paraphrase.

## When to use

- The user asks to "add my project to the Midnight ecosystem", "submit to Electric Capital", or anything similar.
- The user invokes `/midnight-expert:add-to-ecosystem`.

## Tools required

- `git`, `gh` (GitHub CLI), `jq`. If any are missing, abort Phase 1 with the install command.

## Skill state

Track these variables in your reasoning across phases:

- `branch_state` — one of `"existing-branch"`, `"default-branch"`, `"new-branch"`. Set in Phase 3, consumed in Phase 6.
- `made_readme_change` — boolean. Set true in Phase 5 if a file was written.
- `readme_pre_dirty_paths` — list of paths reported as modified by `git diff --name-only` at the start of Phase 5. Used in Phase 6 to refuse the commit if `README.md` had uncommitted user changes.
- `commit_convention` — `"conventional"` or `"freeform"`, computed in Phase 6a.

## Phase 1 — Pre-flight

Run these checks in order. Any failure aborts the skill with a clear next step for the user.

```bash
git rev-parse --is-inside-work-tree
```

If exit code ≠ 0: abort with:

> "This directory is not a git repository. Run `git init`, commit at least once, push to GitHub, then re-run this skill."

```bash
command -v gh
```

If missing: abort with:

> "The `gh` CLI is required. Install it: macOS `brew install gh`, Linux see <https://cli.github.com>. Then re-run."

```bash
gh auth status
```

If exit code ≠ 0 (not logged in): abort with:

> "You're not authenticated with GitHub. Run `gh auth login` and follow the prompts (we need API access to read and edit repository topics). Then re-run this skill."

```bash
command -v jq
```

If missing: abort with the platform-appropriate install command (`brew install jq` / `apt install jq` / etc.).

If all four checks pass, print:

```
[OK] Pre-flight: git, gh (authed), jq
```

## Phase 2 — GitHub repo check

Resolve the origin URL and parse `owner/repo`:

```bash
git remote get-url origin 2>/dev/null
```

If empty or not a `github.com` URL: abort with:

> "This repo doesn't have a GitHub origin remote. Add one with `git remote add origin git@github.com:<owner>/<repo>.git`, push, then re-run."

Extract `owner/repo` from the URL (handle both `https://github.com/...` and `git@github.com:...` forms).

Fetch repo metadata:

```bash
gh repo view "$OWNER_REPO" --json visibility,repositoryTopics,defaultBranchRef,nameWithOwner
```

Parse the JSON. If `gh` failed (e.g., auth or 404): surface the error and abort.

If `visibility != "PUBLIC"`: abort with:

> "Repository `$OWNER_REPO` is `$VISIBILITY`. Make it public via GitHub → Settings → General → Danger Zone → Change visibility, then re-run."

Extract:
- `existing_topics` — array from `repositoryTopics.nodes[].topic.name`
- `default_branch` — string from `defaultBranchRef.name`

Print:

```
[OK] On GitHub: $OWNER_REPO (public, default branch: $DEFAULT_BRANCH)
```

Persist `existing_topics` and `default_branch` for later phases.

## Phase 3 — Branch decision

```bash
git branch --show-current
```

Compare to `default_branch`.

**Case A — current branch is the default branch.**

Use `AskUserQuestion` with this question:

> "You're on the default branch (`$DEFAULT_BRANCH`). Create a feature branch for these changes?"

Options:

1. `"Yes, create branch 'add-midnight-ecosystem'"` (recommended)
2. `"No, work directly on $DEFAULT_BRANCH"`

If the user picks option 1: run `git switch -c add-midnight-ecosystem`. Set `branch_state = "new-branch"`.

If option 2: set `branch_state = "default-branch"`.

**Case B — current branch is not the default branch.**

Print:

```
[OK] On branch '$CURRENT_BRANCH' — continuing on this branch.
```

Set `branch_state = "existing-branch"`.

(Phases 4–6 added in Task 8.)
