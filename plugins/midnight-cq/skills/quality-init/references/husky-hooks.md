# Husky Hooks Reference

## Dependencies

```bash
npm install --save-dev husky
```

| Package | Purpose |
|---------|---------|
| `husky` | Git hooks manager -- installs hooks that run automatically on commit and push |

## Setup

```bash
npx husky init
```

This creates the `.husky/` directory and adds a `prepare` script to `package.json`. Verify the prepare script exists:

```jsonc
{
  "scripts": {
    "prepare": "husky"
  }
}
```

The `prepare` script runs automatically after `npm install`, ensuring hooks are set up for every developer who clones the repo.

## Pre-commit Hook

Create `.husky/pre-commit`:

```bash
npx biome ci --changed
```

This hook runs on every `git commit`. It checks only files that have changed compared to the default branch, which keeps the check fast -- typically under 2 seconds even on large projects.

What it catches:

- Formatting violations (indentation, quotes, semicolons)
- Lint errors (unused variables, barrel files, etc.)
- Import sorting issues

What it does not do:

- Type checking (too slow for every commit)
- Running tests (too slow for every commit)
- Checking unchanged files (only staged changes matter)

## Pre-push Hook

Create `.husky/pre-push`:

```bash
set -e
npx biome ci
npx tsc --noEmit
npx vitest run
```

This hook runs on every `git push`. It runs the full quality suite to prevent broken code from reaching the remote:

1. `biome ci` -- full lint and format check on all files (not just changed)
2. `tsc --noEmit` -- type-check the entire project without emitting output
3. `vitest run` -- run the complete test suite

If any step fails, the push is aborted and the developer must fix the issue before pushing.

### Why separate hooks?

| Hook | Scope | Speed | Purpose |
|------|-------|-------|---------|
| pre-commit | Changed files only | Fast (~2s) | Catch obvious issues immediately |
| pre-push | Entire project | Slower (~30s+) | Full verification before sharing code |

The pre-commit hook keeps the feedback loop tight -- developers get instant feedback on their current changes. The pre-push hook is the safety net that catches issues the pre-commit hook cannot (type errors, test failures, lint issues in files that interact with the changed code).

## Bypassing Hooks

```bash
git commit --no-verify -m "emergency hotfix"
git push --no-verify
```

The `--no-verify` flag skips all hooks. Use it only for genuine emergency hotfixes where speed matters more than quality gates.

Rules for `--no-verify`:

- Only use it when the CI pipeline will catch any issues (it always does)
- Never use it as a habit to avoid fixing lint/type/test errors
- If you find yourself using it regularly, the hooks are too slow or the rules are wrong -- fix the root cause
- Always follow up with a proper commit that passes all hooks
