# midnight-cq Plugin Design Spec

**Date**: 2026-03-30
**Status**: Draft
**Plugin**: `midnight-cq` (Midnight Code Quality)

## Overview

A Claude Code plugin that provides comprehensive code quality tooling for Midnight Network projects. Covers linting, formatting, type checking, testing, Git hooks, and CI workflows for both Compact contract libraries and full DApps.

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Relationship to compact-core | Supersedes testing/review/debugging skills (migration handled separately) | midnight-cq is the authoritative home for all quality concerns |
| Audience | Progressive — opinionated defaults with deeper reference material | Quick-start for beginners, depth for experienced devs |
| Project types | Detect and adapt (Compact-only vs full DApps) | Single plugin serves both; detection drives configuration |
| Linter/formatter | Biome exclusively. No ESLint, no Prettier, no hybrids | Eliminates conflict risk; Biome is production-ready (v2.3, 423+ rules) and proven by OpenZeppelin |
| Biome config | One Midnight-tailored config with overrides per file context | Avoids decision fatigue of multiple presets; Biome overrides handle contract TS vs frontend TS differences |
| Testing | Vitest (contracts/unit) + Playwright (DApp E2E, always headless) | Vitest matches OpenZeppelin's simulator framework; Playwright covers full-stack DApp flows |
| Git hooks | Husky with pre-commit and pre-push | pre-commit: `biome ci --changed` (fast, files changed vs default branch); pre-push: `biome ci && tsc --noEmit && vitest run` (full) |
| CI structure | OpenZeppelin-style split workflows | Fast `checks.yml` (Biome only) + full `test.yml` (compile + tsc + vitest); path filtering for doc-only changes |
| Architecture | Task-oriented skills with shared references + two read-only agents | Skills cover user tasks; agents audit and run checks without modifying code |

## Plugin Structure

```
plugins/midnight-cq/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── skills/
│   ├── quality-init/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── biome-config.md
│   │       ├── vitest-config.md
│   │       ├── playwright-config.md
│   │       ├── husky-hooks.md
│   │       └── ci-workflows.md
│   ├── compact-testing/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── simulator-api.md
│   │       ├── mock-patterns.md
│   │       ├── test-examples.md
│   │       └── witness-testing.md
│   ├── dapp-testing/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── playwright-patterns.md
│   │       └── integration-testing.md
│   └── quality-check/
│       ├── SKILL.md
│       └── references/
│           ├── biome-diagnostics.md
│           ├── test-failures.md
│           └── ci-troubleshooting.md
└── agents/
    ├── cq-reviewer.md
    └── cq-runner.md
```

## Plugin Metadata

**plugin.json**:
- Name: `midnight-cq`
- Description: "Code quality tooling for Midnight Network projects — linting, formatting, type checking, testing, Git hooks, and CI workflows"
- Keywords: `biome`, `vitest`, `playwright`, `testing`, `linting`, `formatting`, `ci`, `github-actions`, `husky`, `compact`, `code-quality`
- No hooks, no commands — skills and agents only.

---

## Skills

### 1. `quality-init` — Set up code quality tooling

**Trigger**: "set up linting", "add code quality", "configure biome", "init project quality", "add CI", "set up git hooks", "add testing"

**SKILL.md** (~250 lines):

1. **Detect project type** — scan for `.compact` files, `package.json` with React/frontend deps, existing configs.
2. **Detect and migrate conflicts** — if ESLint or Prettier configs found:
   - Warn the user about the Biome-only policy.
   - Offer to migrate: run `biome migrate eslint --write --include-inspired` and `biome migrate prettier --write`.
   - Remove old config files (`.eslintrc.*`, `.prettierrc.*`, `.eslintignore`, `.prettierignore`).
   - Remove ESLint/Prettier packages from `package.json` (`eslint`, `prettier`, `eslint-plugin-*`, `eslint-config-*`, `prettier-plugin-*`).
   - Remove ESLint/Prettier scripts from `package.json` `scripts`.
   - Layer Midnight-specific Biome rules on top of the migrated config.
   - Note limitations: YAML ESLint configs need manual conversion, some rule options won't map 1:1.
3. **Scaffold based on detection**:
   - **Always**: Biome (`biome.json`), `.editorconfig`, Husky (pre-commit + pre-push), CI workflows (`checks.yml`, `test.yml`).
   - **If `.compact` files present**: Vitest config with `globalSetup` for `--skip-zk` compilation, `tsconfig.json` for witnesses.
   - **If frontend present**: Playwright config (always headless), Biome overrides for frontend code.

**Reference files**:

| File | Content |
|------|---------|
| `references/biome-config.md` | Complete `biome.json` with every rule explained (why enabled, what it catches). Biome overrides for contract-adjacent TS vs frontend TS. VCS integration. The "no ESLint, no Prettier" enforcement rule with migration procedure. |
| `references/vitest-config.md` | `vitest.config.ts` template. `globalSetup` for Compact compilation with `--skip-zk`. Exclude patterns for `archive/`. Verbose reporter. Globals setup. `@openzeppelin-compact/contracts-simulator` dependency configuration. |
| `references/playwright-config.md` | Playwright config for Midnight DApps. Always headless — no exceptions. Browser setup. Wallet connection handling in tests. Base URL configuration. Timeouts appropriate for blockchain operations. |
| `references/husky-hooks.md` | Pre-commit script: `biome ci --changed`. Pre-push script: `biome ci && tsc --noEmit && vitest run`. Installation via `husky init`. The `prepare` script in `package.json`. |
| `references/ci-workflows.md` | Two workflow templates. `checks.yml`: Biome only, fast, no compiler needed, VCS-aware `--changed`. `test.yml`: compile + tsc + vitest, path-filtered to skip doc-only changes. Setup composite action for Compact compiler installation (`midnightntwrk/setup-compact-action`). `SKIP_ZK` env var usage. |

---

### 2. `compact-testing` — Write and run Compact contract tests

**Trigger**: "write compact tests", "test my contract", "set up simulator", "mock contract", "test witnesses", "write unit tests for compact"

**SKILL.md** (~300 lines):

1. **Test philosophy** — OpenZeppelin's Moloch Testing Guide principle: "the quality of the tests is just as important (if not more so) than the code itself." Flaky tests are categorically unacceptable.
2. **Test structure pattern** — the 4-layer convention: `.compact` source → `witnesses/` → `test/mocks/` → `test/simulators/` → `test/*.test.ts`.
3. **Quick reference: good vs bad test examples** — inline examples showing correct patterns and anti-patterns.
4. **Common patterns** — `.as(caller)` for access control testing, `describe.each` for type combinations (pubkey vs contract address), `it.each` for parameterized tests, `afterEach` invariant checks (e.g., totalSupply unchanged after transfers).
5. **Anti-patterns** — tests that only check happy path, tests that don't assert exact error messages, tests that share mutable state between `it` blocks, tests that test implementation not behavior.

**Reference files**:

| File | Content |
|------|---------|
| `references/simulator-api.md` | `createSimulator()` config shape (`contractFactory`, `defaultPrivateState`, `contractArgs`, `ledgerExtractor`, `witnessesFactory`). `CircuitContextManager` lifecycle. Pure vs impure circuit proxies. `getPublicState()`, `getPrivateState()`. Caller simulation: `.as(callerHexPubKey)`, `setPersistentCaller()`, `resetCaller()`. Witness override: `overrideWitness(key, fn)` vs bulk `witnesses` setter. Private state injection: `circuitContextManager.updatePrivateState()`. |
| `references/mock-patterns.md` | The `isInit: Boolean` constructor pattern for testing initialized vs uninitialized states. The `Maybe<T>` constructor pattern. Re-exporting types and ledger fields from mocks. Thin forwarding circuits. When to mock vs test the real contract. The `archive/` exclusion convention. |
| `references/test-examples.md` | Pairs of good/bad examples for: access control (`.as(OWNER)` vs `.as(UNAUTHORIZED)`), state mutation (verify before and after), error message assertion (exact string matching), initialization guards (`isInit: false`), token operations (balance, allowance, overflow), ZK commitment verification (local recomputation), property-based tests with `fast-check`. Bad examples with explanations of why they're bad. |
| `references/witness-testing.md` | Witness file structure (the `[P, Uint8Array]` return convention). `WitnessContext<L, P>` shape (ledger, privateState, contractAddress). Bulk override vs single `overrideWitness()`. Private state injection for deterministic nonces. Testing witnesses that depend on `ownPublicKey()`. The factory pattern for witness constructors. |

---

### 3. `dapp-testing` — DApp E2E and integration tests

**Trigger**: "test my dapp", "write e2e tests", "test wallet connection", "playwright midnight", "test transaction UI", "integration test frontend"

**SKILL.md** (~200 lines):

1. **Testing layers** — where DApp testing fits: unit tests (Vitest, contracts) → integration tests (Vitest, frontend + contract simulator) → E2E tests (Playwright, full browser flows). Decision guide: "If you're testing contract logic, use `compact-testing`. If you're testing that the UI correctly calls contracts and displays results, you're here."
2. **Playwright conventions** — always headless, test organization, page object pattern for Midnight DApps.
3. **Key DApp test scenarios** — wallet connection/disconnection, transaction submission and confirmation UI, error state handling (rejected transaction, network error), contract state reflected in UI.

**Reference files**:

| File | Content |
|------|---------|
| `references/playwright-patterns.md` | Playwright config (always headless, base URL, blockchain-appropriate timeouts). Page object pattern for Midnight DApps (wallet page, transaction page, dashboard page). Mocking the DApp connector for test isolation vs real wallet testing. Handling async blockchain state updates (polling/waiting patterns). Screenshot on failure. Parallel test execution considerations. |
| `references/integration-testing.md` | Using the Compact simulator in frontend integration tests — test React components calling contract circuits and rendering results without a real network. Mocking the Midnight SDK's `ContractProvider`. Testing error boundaries when contract calls fail. Testing state sync between contract and UI. |

---

### 4. `quality-check` — Run and interpret code quality checks

**Trigger**: "run linting", "check code quality", "run tests", "why is biome failing", "fix lint errors", "CI is failing", "type check errors"

**SKILL.md** (~200 lines):

1. **Quick reference** — commands at a glance:

| Check | Command | Scope |
|-------|---------|-------|
| Lint + format (changed) | `biome ci --changed` | Files changed vs default branch |
| Lint + format (all) | `biome ci` | Entire project |
| Lint + format (fix) | `biome check --write` | Auto-fix |
| Type check | `tsc --noEmit` | All TS files |
| Contract compile | `compact-compiler --skip-zk` | All `.compact` files |
| Unit/contract tests | `vitest run` | All test suites |
| E2E tests | `playwright test` | DApp browser tests |
| Full pre-push suite | `biome ci && tsc --noEmit && vitest run` | Everything |

2. **Interpreting results** — how to read Biome output (rule names map to docs), tsc errors in the context of Compact-generated artifacts, vitest failure output with simulator stack traces.
3. **Common fix patterns** — inline guidance for frequent issues.

**Reference files**:

| File | Content |
|------|---------|
| `references/biome-diagnostics.md` | The Midnight Biome ruleset with each rule explained: what it catches, why enabled, how to fix. Common false-positive scenarios. `// biome-ignore` with required explanation (and when not to). `--changed` vs full run difference. |
| `references/test-failures.md` | Common simulator errors: "contract not initialized" (forgot `isInit: true`), "caller is not the owner" (forgot `.as(OWNER)`), missing artifacts (recompile with `--skip-zk`), stale artifacts after contract changes, witness return type mismatches. Stack trace reading for simulator errors. |
| `references/ci-troubleshooting.md` | `checks.yml` passes but `test.yml` fails (Biome fine, compilation/tests not). Path filter debugging. Compact compiler version mismatches local vs CI. `SKIP_ZK` not set causing slow CI. Caching issues. `midnightntwrk/setup-compact-action` setup. |

---

## Agents

### `cq-reviewer` — CQ Setup Auditor

**Purpose**: Audit a project's code quality setup and produce a detailed report with recommendations. Never modifies files.

**Configuration**:
- `tools`: `Read, Grep, Glob, Bash` (no Edit, no Write)
- `model`: `sonnet`
- `skills`: `midnight-cq:quality-init`, `midnight-cq:compact-testing`, `midnight-cq:dapp-testing`

**Workflow**:
1. Scan for quality tooling presence (Biome, Vitest, Playwright, Husky, CI workflows).
2. Flag conflicts (ESLint/Prettier present alongside or instead of Biome).
3. Validate configs against Midnight-tailored standards (correct Biome rules? `--skip-zk` for test compilation? Correct pre-commit/pre-push hooks?).
4. Assess test quality — coverage gaps, missing mock contracts, untested circuits, simulators not using `.as()` for access control, missing error message assertions.
5. Check CI completeness — `checks.yml` and `test.yml` exist? Path filtering? Compact compiler setup action?
6. Produce structured report:
   - **Critical** — missing or broken quality tooling
   - **Warnings** — suboptimal configuration, coverage gaps
   - **Suggestions** — improvements to test quality, CI optimization

### `cq-runner` — CQ Check Executor

**Purpose**: Run all quality checks and interpret results into a structured report. Never modifies files.

**Configuration**:
- `tools`: `Read, Grep, Glob, Bash` (no Edit, no Write)
- `model`: `sonnet`
- `skills`: `midnight-cq:quality-check`

**Workflow**:
1. Detect project type (Compact-only vs full DApp).
2. Run checks in order: `biome ci` → `tsc --noEmit` → `compact-compiler --skip-zk` (if `.compact` files) → `vitest run` → `playwright test` (if configured).
3. Capture all output.
4. Interpret results — translate Biome rule violations into explanations, categorize tsc errors (artifact issues vs handwritten code), parse vitest failures with simulator context.
5. Produce structured report:
   - **Summary** — pass/fail per check, counts
   - **Details** — each failure with explanation, file location, recommended fix
   - **Patterns** — recurring issues grouped (e.g., "12 files missing semicolons" not listed 12 times)

---

## Cross-Plugin Dependencies

- **compact-core**: midnight-cq will eventually supersede `compact-testing`, `compact-review`, and `compact-debugging` skills. Migration handled as a separate PR.
- **midnight-tooling**: Referenced for Compact compiler installation (`compact-cli` skill) and `midnightntwrk/setup-compact-action` in CI.
- **dapp-development**: Referenced for DApp connector context in `dapp-testing` integration patterns.

## Out of Scope

- Compact language semantics (stays in compact-core)
- DApp connector API details (stays in dapp-development)
- Removing/migrating skills from compact-core (separate PR)
- Code formatting for `.compact` files (no formatter exists for the Compact language)
- Security auditing / formal verification (separate concern)
