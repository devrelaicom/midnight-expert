# MCP Skill Improvements — Implementation Handover

You are implementing four plans that improve the `midnight-mcp` plugin's skills. There is **no human in the loop** — execute autonomously, make decisions yourself, and do not ask questions. If you encounter an ambiguity, make the reasonable choice and document it in the commit message.

## Plans to Execute

Execute these in order. Plans 1, 2, and 4 are independent. Plan 3 MUST run after Plan 2.

| Order | Plan File | Branch Name | Summary |
|-------|-----------|-------------|---------|
| 1 | `docs/superpowers/plans/2026-03-19-mcp-search-technique-library.md` | `feat/mcp-search-technique-library` | 11 tasks, 38 new files — search technique library with references and examples |
| 2 | `docs/superpowers/plans/2026-03-19-mcp-compile-skill.md` | `feat/mcp-compile-skill` | 9 tasks, 12 new files + 1 modified — extract compile into own skill |
| 3 | `docs/superpowers/plans/2026-03-19-mcp-format-skill.md` | `feat/mcp-format-skill` | 3 tasks, 1 new file + 1 modified — extract format into own skill |
| 4 | `docs/superpowers/plans/2026-03-19-mcp-simulate-skill.md` | `feat/mcp-simulate-skill` | 14 tasks, 24 new files — rewrite simulate skill with OZ simulator integration |

Plans 1, 2, and 4 can be executed in parallel (on separate branches from main). Plan 3 cannot start until Plan 2 has been pushed. Plan 3 must branch from the feature branch of Plan 2, because it modifies `mcp-analyze/SKILL.md` which Plan 2 also modifies.

## Working Directory

All file paths in the plans are relative to `plugins/midnight-mcp/` unless stated otherwise.

## Spec Files (for reference, do not modify)

- `docs/superpowers/specs/2026-03-19-mcp-search-technique-library-design.md`
- `docs/superpowers/specs/2026-03-19-mcp-compile-skill-design.md`
- `docs/superpowers/specs/2026-03-19-mcp-format-skill-design.md`
- `docs/superpowers/specs/2026-03-19-mcp-simulate-skill-design.md`

## Step-by-Step Workflow for Each Plan

### 1. Start the plan

```bash
# Ensure you're on main and up to date
git checkout main
git pull origin main

# Create the feature branch
git checkout -b <branch-name>
```

For Plan 3 only: branch from Plan 2's feature branch rather than main. All other plans branch from main.

```bash

# Ensure you're on Plan 2's feature branch and up to date
git checkout <plan-2-branch-name>
git pull origin <plan-2-branch-name>

# Create the plan 3 feature branch
git checkout -b <plan-3-branch-name>

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

### 5. Review task with code reviewer

After committing a task, **before moving to the next task**, dispatch a `devs:code-reviewer` subagent to review the changes. Use the Agent tool with `subagent_type: "devs:code-reviewer"`.

Provide the reviewer with:
- The git diff of the task's commit: `git diff HEAD~1..HEAD`
- The plan file path and task number being reviewed
- The spec file path for context
- Instruction to check: content accuracy, adherence to conventions (operational tone, no frontmatter on references/examples, anti-patterns present in example files, cross-references valid), and completeness against the plan's step descriptions

Example prompt for the reviewer:
```
Review the changes in the latest commit for Task N of the mcp-search plan.

Plan: docs/superpowers/plans/2026-03-19-mcp-search-technique-library.md
Spec: docs/superpowers/specs/2026-03-19-mcp-search-technique-library-design.md
Task: N — [task description]

Check:
1. All files listed in the task were created/modified
2. Content follows conventions: operational tone, no YAML frontmatter on references/examples, real Midnight terminology
3. Example files have 3-5 before/after pairs and 2-3 anti-patterns (where applicable)
4. Reference files end technique sections with Examples: pointers (Plan 1 only)
5. Cross-references use skill names not file paths
6. No placeholders, TODOs, or incomplete sections

Run: git diff HEAD~1..HEAD
```

**If the reviewer finds issues:**
1. Fix each issue
2. Amend the commit: `git add -A && git commit --amend --no-edit`
3. Re-run the reviewer to confirm the fixes
4. Only proceed to the next task once the reviewer approves

**If the reviewer approves:** proceed to the next task.

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
- Plan 4: `feat(mcp-simulate): rewrite simulate skill with OZ simulator integration`

### 8. Move to the next plan

After the PR is created (you do NOT need to wait for it to be merged before starting the next independent plan):
- Plans 1, 2, and 4 are independent — after finishing one, start another from `main`
- Plan 3 depends on Plan 2 — Plan 3 cannot start until Plan 2 has been pushed. Plan 3 must branch from the feature branch of Plan 2, you do not need to wait until it has been merged.

**Recommended execution order:**
1. Execute Plan 2 (mcp-compile) — smaller, 9 tasks
2. Execute Plan 1 (mcp-search) — larger, 11 tasks
3. Execute Plan 4 (mcp-simulate) — 14 tasks
4. Merge Plan 2's PR (or confirm it's merged)
5. Execute Plan 3 (mcp-format) — smallest, 3 tasks, branches from Plan 2's branch

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
- **MCP tools** are `midnight-search-compact`, `midnight-search-typescript`, `midnight-search-docs`, `midnight-fetch-docs`, `midnight-compile-contract`, `midnight-compile-archive`, `midnight-format-contract`, `midnight-simulate-deploy`, `midnight-simulate-call`, `midnight-simulate-state`, `midnight-simulate-delete`, etc.
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

## GitHub Issues (Plans 1 and 4)

Plan 1 Task 9 creates 7 GitHub issues on `devrelaicom/compact-playground`. Plan 4 Task 12 creates 3 GitHub issues on `devrelaicom/compact-playground`. The plans provide exact `gh issue create` commands. Run them as-is. If the repo requires authentication, use `gh auth status` to verify you're authenticated first.

## Final Checklist Before You Stop

After all four plans are executed and PRs are created:

- [ ] Plan 1 PR created on `feat/mcp-search-technique-library`
- [ ] Plan 2 PR created on `feat/mcp-compile-skill`
- [ ] Plan 3 PR created on `feat/mcp-format-skill`
- [ ] Plan 4 PR created on `feat/mcp-simulate-skill`
- [ ] All integration verification tasks passed
- [ ] No uncommitted changes remain (`git status` is clean on each branch)
- [ ] 7 GitHub issues created on `devrelaicom/compact-playground` (from Plan 1)
- [ ] 3 GitHub issues created on `devrelaicom/compact-playground` (from Plan 4)
