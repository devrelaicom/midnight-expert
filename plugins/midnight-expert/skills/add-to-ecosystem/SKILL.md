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

First, look ahead: if all required topics are already present (`existing_topics` from Phase 2 contains `midnightntwrk`, and either contains `compact` or the project doesn't use Compact) AND the README already contains one of the three EC sentences (run `check-readme.sh` and check `present`), then there is no work for Phase 4–6 to do. In that case, set `branch_state = "default-branch"`, skip the branch question, and continue — Phases 4–6 will print `[OK]` lines and exit.

Otherwise, use `AskUserQuestion` with this question:

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

## Phase 4 — Topics

Compare `existing_topics` (from Phase 2) to required topics.

### `midnightntwrk` (mandatory)

If `"midnightntwrk"` is **not** in `existing_topics`:

```bash
gh repo edit "$OWNER_REPO" --add-topic midnightntwrk
```

Print: `[FIX] Added topic 'midnightntwrk'`.

If already present: print `[OK] Topic 'midnightntwrk' present`.

### `compact` (conditional)

Run the project detection script:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/detect-project.sh"
```

Parse the JSON output. Read `recommendation.add_compact_topic`. The signal-to-recommendation rules are documented in `references/project-categorisation.md` — refer to it if you need to explain the recommendation to the user.

**If the script exits non-zero or its output isn't valid JSON**: treat detection as inconclusive. Skip the recommendation marker — present both options as equal and add a short note to the user that automatic detection failed and they should pick based on their own knowledge of the project.

If `"compact"` is already in `existing_topics`: print `[OK] Topic 'compact' present` and skip the rest of this section (no question, no edit).

Otherwise, use `AskUserQuestion`:

> "Does this project use Compact?"

Options (mark the recommended one):

1. `"Yes, add 'compact' topic"` — recommended if `add_compact_topic == true`
2. `"No, skip 'compact' topic"` — recommended if `add_compact_topic == false`
3. `"Cancel"` — abort the skill cleanly with a summary of what's been done so far (e.g., `midnightntwrk` topic was already applied if you reached this point and it was missing).

If the user picks option 1 and `"compact"` is not already in `existing_topics`:

```bash
gh repo edit "$OWNER_REPO" --add-topic compact
```

Print `[FIX] Added topic 'compact'` or `[OK] Topic 'compact' present` accordingly.

If `gh repo edit` fails (e.g., the user lacks admin permission), surface the error and continue to Phase 5 — don't abort. Topic edits are independent of the README work.

## Phase 5 — README attribution

Snapshot the working tree's modified paths **before** doing anything to the README:

```bash
git diff --name-only > /tmp/add-to-ecosystem-pre-snapshot.txt
git diff --cached --name-only >> /tmp/add-to-ecosystem-pre-snapshot.txt
```

Persist this list as `readme_pre_dirty_paths`.

Run the README check:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/check-readme.sh"
```

Parse the JSON. If the script exits non-zero or output isn't valid JSON: tell the user the README check couldn't be completed and ask them to either fix the issue (e.g., create `README.md` if it's missing — though `check-readme.sh` already handles that case) or skip the README phase. Don't proceed silently.

**If `present == true`**: look up the full sentence text from `references/ec-criteria.md` using `matched_sentence` as the key (`built-on` → "This project is built on the Midnight Network.", etc.) and print `[OK] README contains "<full sentence text>"`. Skip to the summary (no Phase 6 work — `made_readme_change` stays false).

**If `present == false`**: continue.

Run detection again (cached value from Phase 4 is fine) to get `recommendation.category`. If detection failed in Phase 4, present all three options without a recommendation and add a note. Otherwise, translate to display text using `references/ec-criteria.md`:

| `category` | Display label | Sentence |
|---|---|---|
| `built-on` | "Built on Midnight" | `This project is built on the Midnight Network.` |
| `integrates` | "Integrates with Midnight" | `This project integrates with the Midnight Network.` |
| `extends` | "Extends Midnight" | `This project extends the Midnight Network with additional developer tooling.` |

Use `AskUserQuestion` with the question:

> "Pick the attribution sentence for this project's README. (Recommended: $RECOMMENDED_LABEL)"

Show all three options (each labelled with the category and the verbatim sentence) plus a fourth `"Cancel"` option. Mark the recommendation. The user is free to override.

If the user picks `Cancel`, abort the skill cleanly with a summary of what's been done so far.

Otherwise, build the alert block:

```
> [!NOTE]
> {chosen sentence}
```

with one blank line before and one blank line after.

Decide the insertion point using the JSON from `check-readme.sh`:

- `placement == "top-of-file"`:
  - File doesn't exist: write the alert + `\n` to a new `README.md`.
  - File exists and is empty: write the alert + `\n`.
  - File exists with content: prepend the alert (alert + blank line + existing content).
- `placement == "after-title-block"`: insert the alert at line `title_block_end_line + 1` (1-indexed). Ensure exactly one blank line precedes and follows.
- `placement == "ambiguous"`: use `AskUserQuestion` with options:
  1. `"Insert after the H1 title (line $FIRST_H1)"` — recommended
  2. `"Insert at the very top of the file"`
  3. `"I'll add it myself — skip the README edit"`
  Apply the chosen action, or skip if option 3.

For all in-file edits, prefer the `Edit` tool with a unique `old_string` (use a few lines of surrounding context from `README.md` to make it unique). Do not use `sed -i` — it's not portable and obscures the change.

After writing the file, set `made_readme_change = true` and persist the chosen `category` and `sentence` for the commit message.

Print: `[FIX] Inserted "$category" attribution into README.md.`

## Phase 6 — Commit, push, PR

If `made_readme_change == false`, skip this phase entirely — print the summary and stop.

### 6a — Detect commit convention

```bash
git log --oneline -30 --no-merges
```

For each line, strip the leading SHA and check whether the message starts with one of: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `build`, `ci`, `perf`, `style`, `revert` (optionally followed by `(scope)`), then `:`. Count matches.

If matches / total ≥ 0.6, set `commit_convention = "conventional"`. Else `"freeform"`.

Build the commit message:

- `conventional`:
  ```
  docs: add Midnight Network attribution for Electric Capital

  Adds the canonical Electric Capital attribution sentence to README.md.
  ```
- `freeform`:
  ```
  Add Midnight Network attribution for Electric Capital

  Adds the canonical Electric Capital attribution sentence to README.md.
  ```

### 6b — Stage only this skill's changes, with safety check

If `README.md` appears in `readme_pre_dirty_paths` (the user already had unstaged changes there before the skill ran), abort the commit:

> "`README.md` had uncommitted changes before the skill ran. The skill won't mix its edits with yours. Commit or stash your changes manually, then re-run, or commit the skill's work yourself."

Otherwise:

```bash
git add README.md
```

Use `AskUserQuestion`:

> "Commit the README change?"

Options:
1. `"Commit with this message"` (show the message; recommended)
2. `"Edit the message"` — ask the user for replacement text via a follow-up `AskUserQuestion` free-text prompt
3. `"Skip — I'll commit myself"`

If the user skips, leave the file staged and jump to the summary.

If the user commits, run:

```bash
git commit -m "$COMMIT_MESSAGE"
```

(Use a heredoc to preserve the body line.)

### 6c — Push and PR

| `branch_state` | Behaviour |
|---|---|
| `existing-branch` | No push, no PR. Print: "Committed to `$CURRENT_BRANCH`. Push when you're ready." |
| `default-branch` | `AskUserQuestion`: "Push to `origin/$DEFAULT_BRANCH`?" Options: `"Yes, push"`, `"No, I'll push later"`. If yes: `git push`. |
| `new-branch` | `AskUserQuestion`: "Push and open a PR?" Options: `"Push and open a PR"`, `"Push only"`, `"Neither — I'll handle it"`. If push+PR: `git push -u origin "$CURRENT_BRANCH" && gh pr create --fill`. If push only: `git push -u origin "$CURRENT_BRANCH"`. |

For all push paths use plain `git push` (no `--force`, no `--force-with-lease`). If push fails, surface the error and stop without retrying.

If `gh pr create` fails after a successful push, print the error and a hint:

> "PR creation failed. Branch is pushed; open the PR manually at https://github.com/$OWNER_REPO/pull/new/$CURRENT_BRANCH"

## Final summary

Print a structured summary listing:

- Each EC requirement and whether it's now satisfied (with `[OK]` or `[FIX]` markers).
- Any actions still pending (e.g., "review and merge the PR", "submit to the Electric Capital `crypto-ecosystems` repo manually").
- A link to the EC submission process if the user wants to take the next step:
  > "To submit your project to the Electric Capital report, follow the instructions at https://github.com/electric-capital/crypto-ecosystems"

## Idempotency

Re-running the skill on a fully eligible project must:

1. Pass Phase 1.
2. Pass Phase 2 (no changes).
3. Skip the branch question — go straight through Phase 3 (no edits to make).
4. Phase 4: print `[OK]` for both topics, no `gh repo edit` calls.
5. Phase 5: detect the existing sentence, print `[OK]`, skip Phase 6.
6. Print the "already eligible" summary.

No prompts, no edits, no commits.

## Reference files

- `references/ec-criteria.md` — the canonical Electric Capital requirements and the three verbatim attribution sentences. Use this as the source of truth — never paraphrase.
- `references/project-categorisation.md` — what each detection signal means and how the category is recommended.
- `references/readme-placement.md` — the placement heuristic with worked examples.
