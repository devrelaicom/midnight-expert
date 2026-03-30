# CI Troubleshooting Reference

## checks.yml Passes But test.yml Fails

**Symptom:** The "Format and Lint" workflow is green, but the "Test Suite" workflow is red.

**Cause:** The two workflows are completely independent. `checks.yml` only runs Biome. It does not compile contracts, run `tsc`, or execute tests. A project can be perfectly formatted and lint-clean while having broken TypeScript, a failing compilation step, or failing tests.

**How to debug:**

1. Open the failing `test.yml` run in GitHub Actions.
2. Check which step failed: `Compile contracts`, `Run type checks`, or `Run tests`.
3. Expand that step's log to see the full error output.
4. Reproduce locally in the same order CI runs:

```bash
npx compact-compiler --skip-zk
npx tsc --noEmit
npx vitest run
```

Each command must succeed before the next is meaningful. Do not run `tsc` before compiling contracts — `tsc` will report phantom errors for types that only exist in generated artifacts.

---

## Path Filter Not Triggering

**Symptom:** You pushed a change that touches source files but `test.yml` did not start, or started but skipped.

**Cause:** The `paths-ignore` configuration in `test.yml` may be too broad and is inadvertently matching your files, or you are using `paths` (include filter) rather than `paths-ignore` and your changed files are not covered.

**How to debug:**

1. Open `.github/workflows/test.yml` and review the `on` section:

```yaml
on:
  pull_request:
    paths-ignore:
      - '**.md'
      - '.gitignore'
      - 'biome.json'
```

2. Check whether any of your changed files match a `paths-ignore` pattern. GitHub uses `fnmatch` glob matching — `**.md` matches `docs/api/README.md`.

3. If you are using a `paths` include filter instead, verify that your changed file paths are covered:

```yaml
on:
  pull_request:
    paths:
      - 'src/**'
      - 'test/**'
      - 'package.json'
      - 'tsconfig.json'
      - '*.compact'
```

4. To force a workflow run for testing purposes, add a trivial change to a file that the path filter definitely includes (e.g., a comment in a `.ts` file), or use the GitHub Actions UI "Re-run all jobs" button.

Do not add `package.json`, `tsconfig.json`, or `.compact` source files to `paths-ignore` — changes to these files can and do break compilation and tests.

---

## Compact Compiler Version Mismatch

**Symptom:** CI fails at `Compile contracts` with an error referencing an unknown option, an unrecognized syntax in your `.compact` file, or a bytecode format error. The same compilation works locally.

**Cause:** The `compact-version` pinned in the `setup-compact-action` step in CI does not match the version installed locally. The Compact language and compiler are evolving — `.compact` syntax valid in one version may not compile in another.

**Fix:** Pin the version explicitly in both places and keep them in sync.

In `test.yml`:

```yaml
- name: Setup Compact Compiler
  uses: midnightntwrk/setup-compact-action@v1
  with:
    compact-version: '0.29.0'
```

In `package.json`:

```jsonc
{
  "devDependencies": {
    "@midnight-ntwrk/compact-compiler": "0.29.0"
  }
}
```

Check your local version:

```bash
npx compact-compiler --version
```

Update whichever side is out of date so both use the same version string.

---

## `SKIP_ZK` Not Set

**Symptom:** CI `test.yml` run starts the `Compile contracts` step and then times out after many minutes. The log shows the compiler generating proofs.

**Cause:** The `SKIP_ZK` environment variable is not set, so the Compact compiler performs full zero-knowledge proof generation during compilation. ZK compilation can take tens of minutes per circuit — far more than the CI timeout budget.

**Fix:** Set `SKIP_ZK: 'true'` as a top-level environment variable in the `test.yml` job or workflow:

```yaml
env:
  SKIP_ZK: 'true'

jobs:
  test:
    ...
    steps:
      - name: Compile contracts
        run: npx compact-compiler --skip-zk
```

Note: the `--skip-zk` flag on the CLI and the `SKIP_ZK` environment variable are redundant but complementary — set both for clarity. The environment variable also affects any scripts or sub-processes that invoke the compiler indirectly.

ZK proof generation is only needed when producing production builds. Unit test CI never needs it.

---

## Node Version Mismatch

**Symptom:** CI fails with cryptic native module errors, `require is not a function`, or `SyntaxError: Unexpected token '??='` (or similar modern syntax errors). These errors do not appear locally.

**Cause:** The Node.js version in CI is different from the version you are using locally. Midnight dependencies may use optional chaining, nullish coalescing, or other features that require Node 18+.

**Fix:** Add an `.nvmrc` file at the project root specifying the required version:

```
20
```

Or a specific patch version:

```
20.11.1
```

Reference it in the CI workflow with `setup-node`:

```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version-file: '.nvmrc'
    cache: 'npm'
```

This ensures CI uses exactly the version specified in the repo. Locally, run `nvm use` in the project directory to switch to the correct version.

To check the Node version currently used in CI, look at the `Setup Node.js` step output in the workflow run log — it prints the resolved version.

---

## Caching Issues

**Symptom:** A workflow that was previously passing starts failing after a dependency update or a change to the build configuration. The failure is inconsistent — sometimes it passes, sometimes it fails.

**Cause:** Stale entries in the `npm` cache or in the Turborepo cache (if the project uses Turbo) cause CI to use outdated dependencies or skip build steps that should run.

**Fix — npm cache:**

Force a clean install by clearing the npm cache or rotating the cache key. In GitHub Actions, the `actions/setup-node` step caches based on the `package-lock.json` hash. If the lockfile changed but the cache has not been invalidated, update the cache key:

```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version-file: '.nvmrc'
    cache: 'npm'
```

This configuration automatically invalidates the npm cache when `package-lock.json` changes. If you suspect the cache is stale despite a lockfile change, go to GitHub → Settings → Actions → Caches and delete the relevant entry manually.

**Fix — Turbo cache:**

If the project uses Turborepo, Turbo caches task outputs. A stale Turbo cache can cause tasks to appear successful when they should re-run.

Clear the Turbo cache by deleting the `.turbo` directory or by running with `--force`:

```bash
npx turbo run build --force
```

In CI, rotate the Turbo cache key by bumping the cache version suffix in the workflow:

```yaml
- name: Cache Turbo
  uses: actions/cache@v4
  with:
    path: .turbo
    key: turbo-${{ runner.os }}-${{ hashFiles('**/package-lock.json') }}-v2
```

Increment `v2` to `v3` to force a clean Turbo cache on the next run.

---

## Playwright in CI

**Symptom:** E2E tests that pass locally fail in CI with:

```
Error: browserType.launch: Executable doesn't exist at /home/runner/.cache/ms-playwright/chromium-1234/chrome-linux/chrome
```

Or:

```
Error: browserType.launch: spawn ENOENT
```

**Cause:** Playwright requires browser binaries and system dependencies that are not present on the GitHub Actions runner by default. The `npx playwright install` step (or the equivalent) must run before any test that launches a browser.

**Fix:** Add an explicit browser installation step before the E2E test step:

```yaml
- name: Install Playwright browsers
  run: npx playwright install chromium --with-deps
```

The `--with-deps` flag installs the system library dependencies required by Chromium on Ubuntu (fonts, audio libraries, graphics libraries). Without it, Chromium may fail to launch even if the binary is present.

Install only `chromium` unless your test suite explicitly tests Firefox or WebKit — installing all three browsers wastes CI time and disk space.

If the installation step passes but the browser still fails to launch, check:

1. The Playwright version in `package.json` — it must match the installed browser binaries. Run `npx playwright install chromium --with-deps` again after updating `@playwright/test`.
2. The runner OS — the `ubuntu-24.04` runner is supported. If you are using a custom runner or a non-Ubuntu image, check the Playwright documentation for that environment's system requirements.
