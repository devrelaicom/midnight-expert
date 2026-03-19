# MCP Skill Improvements — Implementation Handover

You are implementing three plans that improve the `midnight-mcp` plugin's skills. There is **no human in the loop** — execute autonomously, make decisions yourself, and do not ask questions. If you encounter an ambiguity, make the reasonable choice and document it in the commit message.

## Plans to Execute

Execute these in order. Plans 1 and 2 are independent, but Plan 3 MUST run after Plan 2.

| Order | Plan File | Branch Name | Summary |
|-------|-----------|-------------|---------|
| 1 | `docs/superpowers/plans/2026-03-19-mcp-search-technique-library.md` | `feat/mcp-search-technique-library` | 11 tasks, 38 new files — search technique library with references and examples |
| 2 | `docs/superpowers/plans/2026-03-19-mcp-compile-skill.md` | `feat/mcp-compile-skill` | 9 tasks, 12 new files + 1 modified — extract compile into own skill |
| 3 | `docs/superpowers/plans/2026-03-19-mcp-format-skill.md` | `feat/mcp-format-skill` | 3 tasks, 1 new file + 1 modified — extract format into own skill |

Plans 1 and 2 can be executed in parallel (on separate branches from main). Plan 3 must branch from the **merged** result of Plan 2, because it modifies `mcp-analyze/SKILL.md` which Plan 2 also modifies.

## Working Directory

```
/Users/aaronbassett/Projects/midnight/midnight-expert
```

All file paths in the plans are relative to `plugins/midnight-mcp/` unless stated otherwise.

## Spec Files (for reference, do not modify)

- `docs/superpowers/specs/2026-03-19-mcp-search-technique-library-design.md`
- `docs/superpowers/specs/2026-03-19-mcp-compile-skill-design.md`
- `docs/superpowers/specs/2026-03-19-mcp-format-skill-design.md`

## Step-by-Step Workflow for Each Plan

### 1. Start the plan

```bash
# Ensure you're on main and up to date
git checkout main
git pull origin main

# Create the feature branch
git checkout -b <branch-name>
```

For Plan 3 only: branch from main AFTER Plan 2's PR has been merged.

### 2. Read the plan file

Read the plan file listed in the table above. It contains numbered Tasks, each with checkboxed Steps.

### 3. Execute tasks in order

Work through tasks sequentially by task number. Within each task, execute each step in order.

**For each task:**

1. Read the task description, file list, and dependencies
2. If the task has a "Depends on" note, verify that dependency is complete (the files it creates should exist)
3. Execute each `- [ ]` step in order
4. When a step says "Write [file]", create that file with the content described. The plan provides detailed content guidance — follow it precisely. Write complete, production-quality content. Do not leave placeholders or TODOs.
5. When a step says "Verify", read back the file and check the listed criteria. If something is wrong, fix it before proceeding.
6. When a step says "Commit", stage the listed files and commit with the provided message format.

**Parallelizable tasks:** Some plans note that certain tasks "CAN run in parallel." When executing sequentially, just do them in task number order — the parallelism note is for multi-agent execution.

### 4. Commit conventions

Every commit message must:
- Use conventional commit format (the plans provide exact messages)
- End with `Co-Authored-By: Claude Code <noreply@anthropic.com>`

Example:
```bash
git commit -m "$(cat <<'EOF'
feat(mcp-search): add query expansion cluster reference and examples

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

### 5. Verify task completion

After committing a task, before moving to the next:
- Confirm the committed files exist: `git show --stat HEAD`
- If the task created reference or example files, verify they follow the conventions described in the plan (headings, sections, anti-patterns, etc.)

### 6. Run the integration verification task

Every plan has a final Integration Verification task. This task runs bash checks to verify all files exist, cross-references are valid, and file structures are correct. **Do not skip this.** If it finds issues, fix them and commit the fixes before proceeding to the PR.

### 7. Push and create PR

After all tasks (including integration verification) are complete:

```bash
git push origin <branch-name>
```

Create a PR to main:

```bash
gh pr create --title "<PR title>" --body "$(cat <<'EOF'
## Summary

<2-3 bullet points summarizing what this plan implemented>

## Plan

Implemented from `<plan file path>`

## Spec

Designed in `<spec file path>`

## Changes

- <number> new files created
- <number> existing files modified
- <list any external artifacts like GitHub issues>

Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Use these PR titles:
- Plan 1: `feat(mcp-search): add search technique library with references and examples`
- Plan 2: `feat(mcp-compile): extract compile tools into dedicated skill`
- Plan 3: `feat(mcp-format): extract format tool into dedicated skill`

### 8. Move to the next plan

After the PR is created (you do NOT need to wait for it to be merged before starting the next independent plan):
- Plans 1 and 2 are independent — after finishing one, start the other from `main`
- Plan 3 depends on Plan 2 — you MUST wait for Plan 2's PR to be merged into main before starting Plan 3. If Plan 2's PR is not yet merged, work on Plan 1 first.

**Recommended execution order:**
1. Execute Plan 2 (mcp-compile) — smaller, 9 tasks
2. Execute Plan 1 (mcp-search) — larger, 11 tasks
3. Merge Plan 2's PR (or confirm it's merged)
4. Execute Plan 3 (mcp-format) — smallest, 3 tasks, branches from updated main

## Content Quality Standards

All files you create are **consumed by LLMs**, not humans. Write accordingly:

- **Operational tone** — concise instructions the LLM executes, not explanatory documentation
- **Concrete examples** — real Midnight terminology, tool names, parameter values. No generic placeholders.
- **Anti-patterns are mandatory** — every example file must have 2-3 anti-patterns. These prevent the most common mistakes.
- **Before/after pairs** — show the transformation, not just the end state
- **No YAML frontmatter on reference or example files** — only SKILL.md files get frontmatter
- **Cross-references use skill names** — e.g., `compact-core:compact-compilation`, not file paths

## Key Domain Knowledge

You are writing about Midnight Network's Compact language and MCP tools:

- **Compact** is a smart contract language for the Midnight blockchain
- **MCP tools** are `midnight-search-compact`, `midnight-search-typescript`, `midnight-search-docs`, `midnight-fetch-docs`, `midnight-compile-contract`, `midnight-compile-archive`, `midnight-format-contract`, etc.
- **Common Compact types**: `Counter`, `MerkleTree`, `Map`, `Set`, `Bytes<N>`, `Uint<N>`, `Field`, `Boolean`, `Optional`, `Vector`
- **Key Compact constructs**: `circuit`, `witness`, `ledger`, `export`, `disclose`, `pragma language_version`
- **Trusted sources**: `midnightntwrk`, `OpenZeppelin`, `LFDT-Minokawa`
- **Do NOT expand**: DUST, tDUST, DApp (these are standard forms)
- **DO expand with shorthand preserved**: "Zero Knowledge Proof (ZKP)"

## If Something Goes Wrong

- **Compile/test failure in bash verification**: Fix the issue, re-run the check, commit the fix
- **File already exists when plan says "Create"**: Read it, verify it matches the plan's intent, update if needed
- **Plan references a file that doesn't exist yet**: Check if it's created by an earlier task in the same plan. If so, that task wasn't completed — go back and complete it.
- **Unclear content guidance**: Write the best version you can based on the spec and plan context. Err on the side of being more detailed rather than less.
- **Rate limit on `gh` commands**: Wait 60 seconds and retry.

## GitHub Issues (Plan 1 only)

Plan 1 Task 9 creates 7 GitHub issues on `devrelaicom/compact-playground`. The plan provides exact `gh issue create` commands. Run them as-is. If the repo requires authentication, use `gh auth status` to verify you're authenticated first.

## Final Checklist Before You Stop

After all three plans are executed and PRs are created:

- [ ] Plan 1 PR created on `feat/mcp-search-technique-library`
- [ ] Plan 2 PR created on `feat/mcp-compile-skill`
- [ ] Plan 3 PR created on `feat/mcp-format-skill`
- [ ] All integration verification tasks passed
- [ ] No uncommitted changes remain (`git status` is clean on each branch)
- [ ] 7 GitHub issues created on `devrelaicom/compact-playground` (from Plan 1)
