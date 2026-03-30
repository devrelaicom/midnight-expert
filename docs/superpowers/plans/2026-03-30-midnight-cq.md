# midnight-cq Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the `midnight-cq` plugin with 4 skills, 2 agents, and a README that provides comprehensive code quality tooling for Midnight Network projects.

**Architecture:** Plugin with task-oriented skills (quality-init, compact-testing, dapp-testing, quality-check), each containing a SKILL.md entrypoint and reference files for deep detail. Two read-only agents (cq-reviewer for auditing CQ setup, cq-runner for executing checks) complement the skills. All content is based on OpenZeppelin's compact-contracts patterns.

**Tech Stack:** Claude Code plugin system (SKILL.md + YAML frontmatter), Biome 2.x, Vitest 4.x, Playwright, Husky, GitHub Actions

**Spec:** `docs/superpowers/specs/2026-03-30-midnight-cq-design.md`

**Source of truth for Compact testing patterns:** `/tmp/compact-contracts` (clone of OpenZeppelin/compact-contracts). If not present, clone it: `git clone https://github.com/OpenZeppelin/compact-contracts /tmp/compact-contracts`

---

## File Map

All paths relative to `plugins/midnight-cq/`:

| File | Responsibility |
|------|---------------|
| `.claude-plugin/plugin.json` | Plugin metadata, keywords, author info |
| `README.md` | Overview, features, skill/agent documentation, installation |
| `skills/quality-init/SKILL.md` | Entrypoint: detect project type, migrate conflicts, scaffold quality tooling |
| `skills/quality-init/references/biome-config.md` | Complete Biome config with rules explained, migration procedure |
| `skills/quality-init/references/vitest-config.md` | Vitest setup for Compact simulator testing |
| `skills/quality-init/references/playwright-config.md` | Playwright config (always headless) for DApp E2E |
| `skills/quality-init/references/husky-hooks.md` | Pre-commit and pre-push hook scripts |
| `skills/quality-init/references/ci-workflows.md` | GitHub Actions workflow templates |
| `skills/compact-testing/SKILL.md` | Entrypoint: test philosophy, structure, patterns, anti-patterns |
| `skills/compact-testing/references/simulator-api.md` | createSimulator(), proxies, caller sim, witness overrides |
| `skills/compact-testing/references/mock-patterns.md` | Mock contract conventions, isInit pattern, re-exports |
| `skills/compact-testing/references/test-examples.md` | Good vs bad test pairs across all categories |
| `skills/compact-testing/references/witness-testing.md` | Witness file structure, override patterns, private state injection |
| `skills/dapp-testing/SKILL.md` | Entrypoint: testing layers, Playwright conventions, key scenarios |
| `skills/dapp-testing/references/playwright-patterns.md` | Page objects, wallet mocking, async blockchain assertions |
| `skills/dapp-testing/references/integration-testing.md` | Simulator in frontend tests, ContractProvider mocking |
| `skills/quality-check/SKILL.md` | Entrypoint: command reference, interpreting results, common fixes |
| `skills/quality-check/references/biome-diagnostics.md` | Each Biome rule explained with fix guidance |
| `skills/quality-check/references/test-failures.md` | Common simulator errors and how to fix them |
| `skills/quality-check/references/ci-troubleshooting.md` | CI-specific debugging guide |
| `agents/cq-reviewer.md` | Read-only agent: audits CQ setup, produces report |
| `agents/cq-runner.md` | Read-only agent: runs all checks, interprets results |

---

## Task 1: Plugin Scaffold

**Files:**
- Create: `plugins/midnight-cq/.claude-plugin/plugin.json`
- Create: all empty directories for the full plugin tree

- [ ] **Step 1: Create directory structure**

Run:
```bash
cd /Users/aaronbassett/Projects/midnight/midnight-expert/.claude/worktrees/feat+midnight-cq
mkdir -p plugins/midnight-cq/.claude-plugin
mkdir -p plugins/midnight-cq/agents
mkdir -p plugins/midnight-cq/skills/quality-init/references
mkdir -p plugins/midnight-cq/skills/compact-testing/references
mkdir -p plugins/midnight-cq/skills/dapp-testing/references
mkdir -p plugins/midnight-cq/skills/quality-check/references
```

- [ ] **Step 2: Write plugin.json**

Create `plugins/midnight-cq/.claude-plugin/plugin.json`:

```json
{
  "name": "midnight-cq",
  "version": "0.1.0",
  "description": "Code quality tooling for Midnight Network projects — linting, formatting, type checking, testing, Git hooks, and CI workflows.",
  "author": {
    "name": "Aaron Bassett",
    "email": "aaron@devrel-ai.com"
  },
  "homepage": "https://github.com/devrelaicom/midnight-expert",
  "repository": "https://github.com/devrelaicom/midnight-expert.git",
  "license": "MIT",
  "keywords": [
    "midnight",
    "compact",
    "biome",
    "vitest",
    "playwright",
    "testing",
    "linting",
    "formatting",
    "ci",
    "github-actions",
    "husky",
    "code-quality"
  ]
}
```

- [ ] **Step 3: Verify structure**

Run:
```bash
find plugins/midnight-cq -type d | sort
```

Expected output:
```
plugins/midnight-cq
plugins/midnight-cq/.claude-plugin
plugins/midnight-cq/agents
plugins/midnight-cq/skills
plugins/midnight-cq/skills/compact-testing
plugins/midnight-cq/skills/compact-testing/references
plugins/midnight-cq/skills/dapp-testing
plugins/midnight-cq/skills/dapp-testing/references
plugins/midnight-cq/skills/quality-check
plugins/midnight-cq/skills/quality-check/references
plugins/midnight-cq/skills/quality-init
plugins/midnight-cq/skills/quality-init/references
```

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-cq/.claude-plugin/plugin.json
git commit -m "feat(midnight-cq): scaffold plugin directory structure and metadata"
```

---

## Task 2: quality-init Skill — SKILL.md

**Files:**
- Create: `plugins/midnight-cq/skills/quality-init/SKILL.md`

**Context needed:** Read the OpenZeppelin repo structure to understand what a well-configured Compact project looks like:
- `/tmp/compact-contracts/biome.json` — their Biome config
- `/tmp/compact-contracts/package.json` — their workspace config and scripts
- `/tmp/compact-contracts/.editorconfig` — their editor config
- `/tmp/compact-contracts/.github/workflows/` — their CI workflows
- `/tmp/compact-contracts/contracts/vitest.config.ts` — their vitest setup

- [ ] **Step 1: Write SKILL.md**

Create `plugins/midnight-cq/skills/quality-init/SKILL.md`. The skill must:
- Have YAML frontmatter with `name: quality-init`, a `description` that includes all trigger keywords from the spec ("set up linting", "add code quality", "configure biome", "init project quality", "add CI", "set up git hooks", "add testing"), and `version: 0.1.0`
- Start with the hard rule: **Biome exclusively. Never install ESLint or Prettier alongside Biome.**
- Document the 3-step flow: (1) detect project type, (2) detect and migrate conflicts, (3) scaffold based on detection
- For detection: scan for `.compact` files (Compact project), `package.json` with `react`/`next`/`vue`/`svelte` deps (frontend/DApp), existing `.eslintrc.*`/`.prettierrc.*` configs (conflict)
- For conflict migration: the exact `biome migrate eslint --write --include-inspired` and `biome migrate prettier --write` commands, what to remove after migration, limitations (YAML configs, rule option gaps)
- For scaffolding: what is always created (Biome, .editorconfig, Husky, CI), what is conditional (Vitest if Compact, Playwright if frontend)
- Include the reference file routing table at the bottom
- Keep under 300 lines total
- Use the same markdown conventions as compact-core skills (H1 title, H2 sections, tables for quick reference, code blocks for commands)

- [ ] **Step 2: Verify the file renders correctly**

Run:
```bash
wc -l plugins/midnight-cq/skills/quality-init/SKILL.md
head -5 plugins/midnight-cq/skills/quality-init/SKILL.md
```

Expected: line count under 300, first line is `---` (YAML frontmatter start).

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-cq/skills/quality-init/SKILL.md
git commit -m "feat(midnight-cq): add quality-init skill entrypoint"
```

---

## Task 3: quality-init References

**Files:**
- Create: `plugins/midnight-cq/skills/quality-init/references/biome-config.md`
- Create: `plugins/midnight-cq/skills/quality-init/references/vitest-config.md`
- Create: `plugins/midnight-cq/skills/quality-init/references/playwright-config.md`
- Create: `plugins/midnight-cq/skills/quality-init/references/husky-hooks.md`
- Create: `plugins/midnight-cq/skills/quality-init/references/ci-workflows.md`

**Context needed:** Read these OpenZeppelin files to base configs on proven patterns:
- `/tmp/compact-contracts/biome.json` — their complete Biome config
- `/tmp/compact-contracts/.editorconfig` — editor settings
- `/tmp/compact-contracts/contracts/vitest.config.ts` — vitest setup
- `/tmp/compact-contracts/.github/workflows/checks.yml` — lint CI
- `/tmp/compact-contracts/.github/workflows/test.yml` — test CI
- `/tmp/compact-contracts/.github/actions/setup/action.yml` — composite setup action
- `/tmp/compact-contracts/package.json` — root scripts

- [ ] **Step 1: Write biome-config.md**

Create `plugins/midnight-cq/skills/quality-init/references/biome-config.md`. Must contain:

1. **The Biome-Only Rule** — explicit statement: never use ESLint or Prettier. If detected, migrate and remove.
2. **Migration Procedure** — step-by-step: `biome migrate eslint --write --include-inspired`, `biome migrate prettier --write`, files to delete (`.eslintrc.*`, `.eslintignore`, `.prettierrc.*`, `.prettierignore`, `eslint.config.*`), packages to remove from `package.json` (all `eslint-*`, `prettier*`, `@typescript-eslint/*` packages), scripts to remove. Limitations: YAML ESLint configs need manual JSON conversion first, some rule options won't map 1:1, behavior differences expected.
3. **Complete Midnight biome.json** — a ready-to-use config based on OpenZeppelin's but adapted for broader Midnight projects. Include:
   - VCS integration (`vcs.enabled: true`, `vcs.clientKind: "git"`, `vcs.useIgnoreFile: true`, `vcs.defaultBranch: "main"`)
   - Files to exclude: `tsconfig*.json`, `*.compact`, `artifacts/`, `test-artifacts/`, `coverage/`, `dist/`, `reports/`, `node_modules/`
   - Formatter: spaces (2), single quotes, semicolons always, line width 100
   - Assist: `organizeImports: "on"`
   - Linter rules (all at "error" level): `noUnusedVariables`, `noUnusedImports`, `noBarrelFile`, `noReExportAll`, `noParameterAssign`, `useAsConstAssertion`, `useDefaultParameterLast`, `useSelfClosingElements`, `useSingleVarDeclarator`, `noUnusedTemplateLiteral`, `useNumberNamespace`, `noInferrableTypes`, `noUselessElse`, `useConsistentArrayType` (shorthand), `useErrorMessage`, `noConsole` (allow `["log"]`)
   - Each rule must have a one-line explanation of why it's enabled
4. **Biome Overrides** — how to use the `overrides` array for different file contexts (stricter rules for witness/simulator TS near `.compact` files, slightly relaxed for frontend React components if needed)
5. **.editorconfig** — complete file: UTF-8, 2-space indent, LF, trim trailing whitespace, insert final newline, markdown trailing spaces preserved, TS max line 100

- [ ] **Step 2: Write vitest-config.md**

Create `plugins/midnight-cq/skills/quality-init/references/vitest-config.md`. Must contain:

1. **Dependencies to install** — `vitest`, `@openzeppelin-compact/contracts-simulator`, `@midnight-ntwrk/compact-runtime`, `@types/node`, `typescript`, `@tsconfig/node24`
2. **vitest.config.ts template** — `globals: true`, `environment: 'node'`, include `src/**/*.test.ts`, exclude `src/archive/**`, reporter `verbose`
3. **globalSetup for Compact compilation** — a `test/setup.ts` file that runs `compact compile --skip-zk` for each `.compact` file before tests. Based on OpenZeppelin's pattern: check if artifact is newer than source (incremental compilation), handle exit code 127 ("compact not found"), sequential compilation to avoid race conditions.
4. **tsconfig.json for witnesses** — extends `@tsconfig/node24`, `rootDir: ./src`, `outDir: ./dist`, `declaration: true`, `rewriteRelativeImportExtensions: true`, `erasableSyntaxOnly: true`, `verbatimModuleSyntax: true`. Excludes `src/archive/`.
5. **package.json scripts** — `"test": "compact-compiler --skip-zk && vitest run"`, `"types": "tsc --noEmit"`

- [ ] **Step 3: Write playwright-config.md**

Create `plugins/midnight-cq/skills/quality-init/references/playwright-config.md`. Must contain:

1. **Dependencies to install** — `@playwright/test`, `playwright`
2. **playwright.config.ts template** — always `headless: true` (no exceptions), `baseURL` from env or localhost, extended `timeout` and `actionTimeout` (blockchain operations are slow — 30s action timeout, 60s test timeout), `retries: 0` in CI (flaky tests are not acceptable), screenshot on failure, `reporter: [['html'], ['list']]`
3. **Browser configuration** — chromium only by default (sufficient for DApp testing), projects array with a single chromium project
4. **Web server configuration** — `webServer` block for starting the DApp dev server before tests, with `reuseExistingServer: !process.env.CI`
5. **The headless rule** — explain why: consistent CI behavior, no display server dependency, faster execution. If a developer needs headed mode for debugging, they run `npx playwright test --headed` manually — the config itself never allows headed mode.

- [ ] **Step 4: Write husky-hooks.md**

Create `plugins/midnight-cq/skills/quality-init/references/husky-hooks.md`. Must contain:

1. **Dependencies to install** — `husky`
2. **Setup commands** — `npx husky init`, add `"prepare": "husky"` to `package.json` scripts
3. **Pre-commit hook** — file at `.husky/pre-commit`:
   ```bash
   biome ci --changed
   ```
   Explain: runs Biome on files changed vs the default branch. Fast (~1 second). Catches lint and format errors before they enter the commit.
4. **Pre-push hook** — file at `.husky/pre-push`:
   ```bash
   biome ci
   tsc --noEmit
   vitest run
   ```
   Explain: runs the full quality suite on the entire codebase. Catches anything the pre-commit hook missed (type errors, test failures, format issues in unchanged files that were affected by changes). Takes longer but prevents pushing broken code.
5. **Bypassing hooks** — document that `git commit --no-verify` and `git push --no-verify` skip hooks, and when this is acceptable (emergency hotfix only, never for routine work).

- [ ] **Step 5: Write ci-workflows.md**

Create `plugins/midnight-cq/skills/quality-init/references/ci-workflows.md`. Must contain:

1. **Two-workflow architecture** — explain the split: `checks.yml` is fast (Biome only, no compiler needed), `test.yml` is thorough (compile + typecheck + test). Both run on every PR and push to main.
2. **checks.yml template** — complete GitHub Actions workflow:
   - Trigger: `push` to main, `pull_request`
   - Single job: checkout, setup Node (from `.nvmrc`), install deps, run `biome ci --changed --no-errors-on-unmatched`
   - No Compact compiler installation needed
   - Fast: typically completes in <30 seconds
3. **test.yml template** — complete GitHub Actions workflow:
   - Trigger: `push` to main, `pull_request`
   - Path filter: skip if only `.md`, `.gitignore`, `biome.json` changed
   - Steps: checkout, setup Node, install deps, install Compact compiler (via `midnightntwrk/setup-compact-action` or `compact update <version>`), run `compact-compiler --skip-zk` (compile contracts), run `tsc --noEmit` (typecheck), run `vitest run` (tests)
   - Timeout: 15 minutes
   - Env: `SKIP_ZK: 'true'` to skip ZK proof generation in CI
4. **Playwright E2E job (optional)** — additional job in `test.yml` for DApp projects: install Playwright browsers, start dev server, run `npx playwright test`. Only include if Playwright config exists.
5. **Path filtering** — the exact `paths-ignore` configuration to skip CI on doc-only changes

- [ ] **Step 6: Commit**

```bash
git add plugins/midnight-cq/skills/quality-init/references/
git commit -m "feat(midnight-cq): add quality-init reference files"
```

---

## Task 4: compact-testing Skill — SKILL.md

**Files:**
- Create: `plugins/midnight-cq/skills/compact-testing/SKILL.md`

**Context needed:** Read the OpenZeppelin test files to understand their patterns:
- `/tmp/compact-contracts/contracts/src/access/test/Ownable.test.ts`
- `/tmp/compact-contracts/contracts/src/access/test/ZOwnablePK.test.ts`
- `/tmp/compact-contracts/contracts/src/token/test/FungibleToken.test.ts`
- `/tmp/compact-contracts/contracts/src/access/test/simulators/OwnableSimulator.ts`
- `/tmp/compact-contracts/contracts/src/access/test/mocks/MockOwnable.compact`

- [ ] **Step 1: Write SKILL.md**

Create `plugins/midnight-cq/skills/compact-testing/SKILL.md`. The skill must:
- Have YAML frontmatter with `name: compact-testing`, a `description` including triggers ("write compact tests", "test my contract", "set up simulator", "mock contract", "test witnesses", "write unit tests for compact", "simulator pattern", "createSimulator", "mock contract pattern", "witness override", "test coverage"), and `version: 0.1.0`
- Open with the Moloch Testing Guide philosophy: "For mission critical Compact code, the quality of the tests is just as important (if not more so) than the code itself."
- State explicitly: flaky tests are categorically unacceptable.
- Document the 4-layer test structure convention: `.compact` source → `witnesses/` → `test/mocks/` → `test/simulators/` → `test/*.test.ts`
- Include a quick-reference section with inline good vs bad test examples (abbreviated — the full set goes in `references/test-examples.md`). Show at minimum:
  - GOOD: testing both authorized and unauthorized callers for access control
  - BAD: only testing the happy path
  - GOOD: asserting exact error messages
  - BAD: only catching that "something threw"
- Document common test patterns: `.as(caller)`, `describe.each`, `it.each`, `afterEach` invariant checks, `beforeEach` for fresh simulator per test
- List anti-patterns with explanations
- Include the reference file routing table at the bottom
- Keep under 350 lines total

- [ ] **Step 2: Verify**

Run:
```bash
wc -l plugins/midnight-cq/skills/compact-testing/SKILL.md
head -5 plugins/midnight-cq/skills/compact-testing/SKILL.md
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-cq/skills/compact-testing/SKILL.md
git commit -m "feat(midnight-cq): add compact-testing skill entrypoint"
```

---

## Task 5: compact-testing References

**Files:**
- Create: `plugins/midnight-cq/skills/compact-testing/references/simulator-api.md`
- Create: `plugins/midnight-cq/skills/compact-testing/references/mock-patterns.md`
- Create: `plugins/midnight-cq/skills/compact-testing/references/test-examples.md`
- Create: `plugins/midnight-cq/skills/compact-testing/references/witness-testing.md`

**Context needed:** Read these OpenZeppelin files for accurate API details and patterns:
- `/tmp/compact-contracts/packages/simulator/src/factory/SimulatorConfig.ts`
- `/tmp/compact-contracts/packages/simulator/src/factory/createSimulator.ts`
- `/tmp/compact-contracts/packages/simulator/src/core/AbstractSimulator.ts`
- `/tmp/compact-contracts/packages/simulator/src/core/ContractSimulator.ts`
- `/tmp/compact-contracts/packages/simulator/src/core/CircuitContextManager.ts`
- `/tmp/compact-contracts/packages/simulator/src/types/`
- `/tmp/compact-contracts/contracts/src/access/test/mocks/MockOwnable.compact`
- `/tmp/compact-contracts/contracts/src/access/test/mocks/MockZOwnablePK.compact`
- `/tmp/compact-contracts/contracts/src/token/test/mocks/MockFungibleToken.compact`
- `/tmp/compact-contracts/contracts/src/token/test/mocks/MockMultiToken.compact`
- `/tmp/compact-contracts/contracts/src/access/test/simulators/OwnableSimulator.ts`
- `/tmp/compact-contracts/contracts/src/access/test/simulators/ZOwnablePKSimulator.ts`
- `/tmp/compact-contracts/contracts/src/token/test/simulators/FungibleTokenSimulator.ts`
- `/tmp/compact-contracts/contracts/src/access/witnesses/ZOwnablePKWitnesses.ts`
- `/tmp/compact-contracts/contracts/src/access/test/Ownable.test.ts`
- `/tmp/compact-contracts/contracts/src/access/test/ZOwnablePK.test.ts`
- `/tmp/compact-contracts/contracts/src/token/test/FungibleToken.test.ts`
- `/tmp/compact-contracts/contracts/src/token/test/NonFungibleToken.test.ts`

- [ ] **Step 1: Write simulator-api.md**

Create `plugins/midnight-cq/skills/compact-testing/references/simulator-api.md`. Must contain:

1. **Overview** — the simulator framework from `@openzeppelin-compact/contracts-simulator` eliminates manual context threading. Users call `simulator.circuits.impure.setValue(42n)` instead of manually managing `CircuitContext`.
2. **`createSimulator()` config** — document each field of `SimulatorConfig`:
   - `contractFactory: (witnesses: W) => TContract` — why it must be a factory (witness swapping recreates contract instances)
   - `defaultPrivateState: () => P` — factory for initial private state
   - `contractArgs: (...args: TArgs) => any[]` — maps user-friendly args to raw array for `initialState`
   - `ledgerExtractor: (state: StateValue) => L` — decodes raw state using generated `ledger()` function
   - `witnessesFactory: () => W` — factory for default witnesses
3. **Constructor options** (`BaseSimulatorOptions`) — `privateState`, `witnesses`, `coinPK` (default `'0'.repeat(64)`), `contractAddress` (default `dummyContractAddress()`)
4. **Circuit access** — `simulator.circuits.pure.<name>(args)` vs `simulator.circuits.impure.<name>(args)`. Pure circuits don't update context. Impure circuits persist new state automatically.
5. **Caller simulation** — `.as(hexPubKey)` for single-use override, `setPersistentCaller(hexPubKey)` for sticky override, `resetCaller()` to clear. Explain the priority: `callerOverride` > `persistentCallerOverride` > default from initialization.
6. **State access** — `getPublicState()` (typed ledger), `getPrivateState()` (current private state), `getContractState()` (raw `StateValue`), `contractAddress` (readonly string)
7. **Witness management** — `overrideWitness(key, fn)` replaces one witness, `simulator.witnesses = newWitnesses` replaces all. Both trigger proxy reset. `getWitnessContext()` returns `{ ledger, privateState, contractAddress }`.
8. **Private state injection** — `circuitContextManager.updatePrivateState(newState)` for surgical state updates between circuit calls.
9. **Building a simulator class** — complete example showing how to extend `createSimulator()` output with user-friendly methods.

- [ ] **Step 2: Write mock-patterns.md**

Create `plugins/midnight-cq/skills/compact-testing/references/mock-patterns.md`. Must contain:

1. **Why mocks?** — Compact modules are imported, not inherited. To test a module, you create a thin wrapper contract ("mock") that imports the module and forwards all circuits. The mock adds a constructor that the module itself may not have.
2. **The standard mock pattern** — complete example:
   ```compact
   pragma language_version >= 0.21.0;
   import CompactStandardLibrary;
   import "../../ModuleName" prefix ModuleName_;
   export { ZswapCoinPublicKey, ContractAddress, Either, Maybe };

   constructor(args..., isInit: Boolean) {
     if (disclose(isInit)) {
       ModuleName_initialize(args...);
     }
   }

   export circuit method(args...): ReturnType {
     return ModuleName_method(args...);
   }
   ```
3. **The `isInit: Boolean` pattern** — the constructor takes a boolean flag to optionally skip initialization. This enables testing pre-initialization state (passing `false`) vs initialized state (passing `true`). Show both usages.
4. **The `Maybe<T>` constructor pattern** — used by MultiToken: `if (disclose(uri.is_some)) { initialize(uri.value); }`. For optional initialization parameters.
5. **Re-exporting types** — mocks must `export { ZswapCoinPublicKey, ContractAddress, Either, Maybe }` so tests can import these types from the mock's compiled artifacts.
6. **Re-exporting ledger fields** — for read access in tests: `export { ModuleName__fieldName }`. Show examples from ZOwnablePK (`ZOwnablePK__ownerCommitment`, `ZOwnablePK__counter`) and MultiToken.
7. **Thin forwarding circuits** — each mock circuit is a single-line forwarder. No logic in the mock beyond the constructor.
8. **When NOT to mock** — if you're testing the module itself and it has a constructor, you may not need a mock. Mocks are for testing modules that don't have their own constructor (like Initializable, Pausable, Utils).
9. **The `archive/` exclusion** — mock files named `Mock*` are excluded from the production build. Archive directories are excluded from compilation, testing, and distribution.

- [ ] **Step 3: Write test-examples.md**

Create `plugins/midnight-cq/skills/compact-testing/references/test-examples.md`. This is the example-heavy file. Must contain pairs of GOOD and BAD examples for each category:

1. **Access Control Testing**
   - GOOD: test both `.as(OWNER)` succeeding and `.as(UNAUTHORIZED)` throwing with exact error message
   - BAD: only testing that the owner can call the function
2. **State Mutation Testing**
   - GOOD: assert state before AND after the mutation
   - BAD: only asserting final state without checking initial state
3. **Error Message Assertion**
   - GOOD: `expect(() => contract.method(badArgs)).toThrow('Ownable: caller is not the owner')`
   - BAD: `expect(() => contract.method(badArgs)).toThrow()` (any throw passes)
4. **Initialization Guard Testing**
   - GOOD: test every exported circuit fails when uninitialized using `it.each`
   - BAD: only testing one circuit's initialization check
5. **Token Operations**
   - GOOD: test balance, allowance, overflow with `afterEach` invariant check on totalSupply
   - BAD: testing transfer without checking sender balance decreased AND receiver balance increased
6. **ZK Commitment Verification**
   - GOOD: recompute the commitment locally in TypeScript and compare against contract output
   - BAD: just checking the commitment is "not zero"
7. **Parameterized Testing**
   - GOOD: `describe.each` for pubkey vs contract address, `it.each` for multiple key/counter combos
   - BAD: copy-pasting the same test with different values
8. **Test Isolation**
   - GOOD: `beforeEach` creates a fresh simulator instance
   - BAD: shared mutable state between `it` blocks
9. **Property-Based Testing with fast-check**
   - GOOD: using `fc.assert(fc.property(...))` for math-heavy circuits
   - BAD: testing with only a few hardcoded values for arithmetic

All examples must use realistic code based on OpenZeppelin's actual test patterns (Ownable, FungibleToken, ZOwnablePK).

- [ ] **Step 4: Write witness-testing.md**

Create `plugins/midnight-cq/skills/compact-testing/references/witness-testing.md`. Must contain:

1. **Witness file structure** — the TypeScript convention:
   - `PrivateState` type (interface or `Record<string, never>` if empty)
   - `PrivateState` factory (with `.generate()` for random, `.withNonce()` etc. for deterministic)
   - Witness function object returned from a factory function (not an object literal)
   - The `[P, Uint8Array]` return convention (return updated private state + witness value)
2. **`WitnessContext<L, P>` shape** — `ledger` (current public state), `privateState` (current private state), `contractAddress` (deployed address). This is the first argument every witness receives.
3. **Bulk witness override** — `simulator.witnesses = newWitnessesFactory()` replaces all witnesses and triggers contract + proxy rebuild. Use for testing entirely different witness behavior.
4. **Single witness override** — `simulator.overrideWitness('wit_secretNonce', (ctx) => [ctx.privateState, customValue])`. Replaces one witness function while keeping others at default. Use for isolating individual witness behavior in tests.
5. **Private state injection** — `simulator.circuitContextManager.updatePrivateState({ ...current, secretNonce: Buffer.from(knownValue) })`. For injecting deterministic values between circuit calls. Show the pattern: inject nonce → call circuit → verify output matches local computation.
6. **Testing witnesses that depend on `ownPublicKey()`** — combine `.as(caller)` with witness overrides. The `.as()` sets the caller identity, while the witness reads from private state. Both must be correct for access control circuits.
7. **The factory pattern requirement** — explain why `witnessesFactory` and `defaultPrivateState` must be functions, not values: the simulator may recreate instances when witnesses are overridden.
8. **Complete example** — a full witness test file for a ZOwnablePK-style contract showing: default witnesses, override witness, inject nonce, verify commitment.

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-cq/skills/compact-testing/references/
git commit -m "feat(midnight-cq): add compact-testing reference files"
```

---

## Task 6: dapp-testing Skill — SKILL.md

**Files:**
- Create: `plugins/midnight-cq/skills/dapp-testing/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

Create `plugins/midnight-cq/skills/dapp-testing/SKILL.md`. The skill must:
- Have YAML frontmatter with `name: dapp-testing`, a `description` including triggers ("test my dapp", "write e2e tests", "test wallet connection", "playwright midnight", "test transaction UI", "integration test frontend", "end-to-end test", "browser test"), and `version: 0.1.0`
- Open with the testing layers diagram: unit tests (Vitest, contracts via `compact-testing`) → integration tests (Vitest, frontend + contract simulator) → E2E tests (Playwright, full browser flows)
- Include the decision guide: "If you're testing contract logic, use `midnight-cq:compact-testing`. If you're testing that the UI correctly calls contracts and displays results, you're here."
- Document Playwright conventions: always headless, page object pattern, test file organization (`tests/e2e/` directory)
- List key DApp test scenarios: wallet connection/disconnection, transaction submission flow, confirmation UI, error states (rejected tx, network error), contract state displayed in UI
- Include the reference routing table
- Keep under 250 lines

- [ ] **Step 2: Verify**

Run:
```bash
wc -l plugins/midnight-cq/skills/dapp-testing/SKILL.md
head -5 plugins/midnight-cq/skills/dapp-testing/SKILL.md
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-cq/skills/dapp-testing/SKILL.md
git commit -m "feat(midnight-cq): add dapp-testing skill entrypoint"
```

---

## Task 7: dapp-testing References

**Files:**
- Create: `plugins/midnight-cq/skills/dapp-testing/references/playwright-patterns.md`
- Create: `plugins/midnight-cq/skills/dapp-testing/references/integration-testing.md`

- [ ] **Step 1: Write playwright-patterns.md**

Create `plugins/midnight-cq/skills/dapp-testing/references/playwright-patterns.md`. Must contain:

1. **Playwright Config Recap** — reference `midnight-cq:quality-init` for initial setup. This file covers usage patterns, not installation.
2. **Page Object Pattern for Midnight DApps** — complete examples for three page objects:
   - `WalletPage` — connect wallet, disconnect, get connected status, get connected address
   - `TransactionPage` — submit transaction, wait for confirmation, get transaction status, get error message
   - `DashboardPage` — get contract state display, refresh state, get balance display
3. **Mocking the DApp Connector** — how to intercept and mock the Midnight wallet/DApp connector for test isolation. Provide a mock implementation that simulates wallet connection without a real wallet extension. Explain when to use mocks (unit/integration) vs real wallet (full E2E).
4. **Handling Async Blockchain State** — blockchain operations are not instant. Document polling/waiting patterns:
   - `expect.poll()` for polling assertions (check every N ms until condition met or timeout)
   - `page.waitForSelector()` for UI state updates after transaction confirmation
   - Custom `waitForTransactionConfirmation()` helper
   - Appropriate timeout values (30s for transaction confirmation, 60s for complex operations)
5. **Screenshot on Failure** — configuration for automatic screenshot capture on test failure. How to review screenshots in CI artifacts.
6. **Parallel Execution** — Playwright runs tests in parallel by default. Document considerations: each test gets its own browser context (isolated), but if tests share a backend/contract state, they may conflict. Recommend: each E2E test deploys its own contract instance or uses test-specific state.

- [ ] **Step 2: Write integration-testing.md**

Create `plugins/midnight-cq/skills/dapp-testing/references/integration-testing.md`. Must contain:

1. **What is integration testing here?** — testing React components that call Compact contract circuits, using the simulator (not a real network) as the backend. The component renders real UI, calls real contract code, but through the simulator instead of a deployed contract.
2. **Mocking `ContractProvider`** — the Midnight SDK's `ContractProvider` is the bridge between frontend and blockchain. Show how to create a test mock that wraps the simulator: component calls `contractProvider.callCircuit('transfer', args)`, the mock routes this to `simulator.circuits.impure.transfer(args)`.
3. **Testing Error Boundaries** — when a contract call fails (e.g., "insufficient balance"), the frontend should display an error. Show how to make the simulator throw (call with bad args) and assert the React error boundary renders the correct message.
4. **State Synchronization Testing** — after an impure circuit call, the contract state changes. The frontend must re-read state and update the UI. Show the pattern: call circuit via mock provider → assert component re-renders with new state from `simulator.getPublicState()`.
5. **Test Setup Pattern** — `beforeEach` creates fresh simulator + mock provider + renders component. `afterEach` cleans up. Each test is isolated.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-cq/skills/dapp-testing/references/
git commit -m "feat(midnight-cq): add dapp-testing reference files"
```

---

## Task 8: quality-check Skill — SKILL.md

**Files:**
- Create: `plugins/midnight-cq/skills/quality-check/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

Create `plugins/midnight-cq/skills/quality-check/SKILL.md`. The skill must:
- Have YAML frontmatter with `name: quality-check`, a `description` including triggers ("run linting", "check code quality", "run tests", "why is biome failing", "fix lint errors", "CI is failing", "type check errors", "biome error", "vitest failing", "tsc error"), and `version: 0.1.0`
- Lead with the command quick reference table:

| Check | Command | Scope |
|-------|---------|-------|
| Lint + format (changed) | `biome ci --changed` | Files changed vs default branch |
| Lint + format (all) | `biome ci` | Entire project |
| Lint + format (fix) | `biome check --write` | Auto-fix |
| Type check | `tsc --noEmit` | All TS files |
| Contract compile | `compact-compiler --skip-zk` | All `.compact` files |
| Unit/contract tests | `vitest run` | All test suites |
| E2E tests | `npx playwright test` | DApp browser tests |
| Full pre-push suite | `biome ci && tsc --noEmit && vitest run` | Everything |

- Include a "How to read results" section for each tool (Biome output format, tsc error format, vitest failure format with simulator stack traces)
- Include a "Common quick fixes" section with the top 5 most frequent issues and one-liner fixes
- Include the reference routing table
- Keep under 250 lines

- [ ] **Step 2: Verify**

Run:
```bash
wc -l plugins/midnight-cq/skills/quality-check/SKILL.md
head -5 plugins/midnight-cq/skills/quality-check/SKILL.md
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-cq/skills/quality-check/SKILL.md
git commit -m "feat(midnight-cq): add quality-check skill entrypoint"
```

---

## Task 9: quality-check References

**Files:**
- Create: `plugins/midnight-cq/skills/quality-check/references/biome-diagnostics.md`
- Create: `plugins/midnight-cq/skills/quality-check/references/test-failures.md`
- Create: `plugins/midnight-cq/skills/quality-check/references/ci-troubleshooting.md`

- [ ] **Step 1: Write biome-diagnostics.md**

Create `plugins/midnight-cq/skills/quality-check/references/biome-diagnostics.md`. Must contain:

1. **Reading Biome output** — format is `path/file.ts:line:col rule/name LEVEL description`. Rule names map to `https://biomejs.dev/linter/rules/<rule-name>`.
2. **The Midnight Biome ruleset** — table with every rule from the Midnight config, grouped by category (correctness, style, performance, suspicious). Each row: rule name, what it catches, why it's enabled, how to fix it. Based on the config from `biome-config.md`.
3. **`biome-ignore` usage** — syntax: `// biome-ignore lint/rule/name: explanation`. The explanation is REQUIRED by convention. Document when it's acceptable (generated code, intentional patterns) and when it's not (laziness, "I'll fix it later").
4. **`--changed` vs full run** — `--changed` compares against the VCS default branch. In CI, this means changes in the PR. Locally, this means changes since you branched. A full `biome ci` (no flag) checks everything. Use `--changed` for pre-commit speed, full run for pre-push thoroughness.
5. **Common false positives** — `noBarrelFile` on intentional entrypoint `index.ts` files (use `// biome-ignore`), `noConsole` on legitimate logging in test setup files.

- [ ] **Step 2: Write test-failures.md**

Create `plugins/midnight-cq/skills/quality-check/references/test-failures.md`. Must contain:

1. **"contract not initialized"** — forgot `isInit: true` in mock constructor, or forgot to call `initialize()`. Fix: pass `true` as the `isInit` arg, or call the initialize circuit before testing.
2. **"caller is not the owner"** — forgot `.as(OWNER)` before calling an owner-restricted circuit. Fix: `simulator.as(OWNER_HEX_KEY).method(args)`.
3. **Missing artifact errors** — `Cannot find module '../artifacts/MockContract/contract/index.js'`. Compact contracts need to be compiled before tests. Fix: run `compact-compiler --skip-zk` or check that `globalSetup` in vitest config is configured.
4. **Stale artifacts** — tests pass locally but fail after pulling changes because artifacts were compiled against old contract source. Fix: run `compact-compiler --skip-zk` to recompile (or delete `artifacts/` and recompile).
5. **Witness return type mismatch** — witness function returns wrong type (e.g., `Buffer` instead of `Uint8Array`, or wrong tuple shape). Fix: witness must return `[PrivateState, WitnessValue]` tuple. Check `[P, Uint8Array]` convention.
6. **"failed assert:" messages** — Compact `assert()` failures surface as JavaScript errors with `"failed assert: <message>"`. The message comes from the Compact source code. Grep the `.compact` files for the message to find the assertion.
7. **Stack trace reading** — simulator errors often have deep stack traces through proxy handlers and runtime code. The useful information is: (1) the error message (maps to a Compact assert), (2) the test file and line that triggered it. Ignore intermediate frames in `AbstractSimulator`, `ContractSimulator`, and `Proxy` handlers.
8. **`compact-runtime` version mismatch** — if the runtime version doesn't match what the compiler expects, you get cryptic errors. Fix: ensure `@midnight-ntwrk/compact-runtime` version in `package.json` matches the version used by your Compact compiler.

- [ ] **Step 3: Write ci-troubleshooting.md**

Create `plugins/midnight-cq/skills/quality-check/references/ci-troubleshooting.md`. Must contain:

1. **"checks.yml passes but test.yml fails"** — checks.yml only runs Biome (lint + format). test.yml compiles and runs tests. The code is well-formatted but doesn't compile or tests fail. These are independent checks — both must pass.
2. **Path filter not triggering** — changes only to `.md` files should skip test.yml. If it still runs, check the `paths-ignore` configuration. If it doesn't run when it should, check that the changed files aren't all in the ignore list.
3. **Compact compiler version mismatch** — local compiler is v0.29.0 but CI installs v0.28.0 (or vice versa). Fix: pin the version in CI setup action AND in `versions.ts` / `.nvmrc`. Use `midnightntwrk/setup-compact-action@v1` with `compact-version: '0.29.0'`.
4. **`SKIP_ZK` not set** — if `SKIP_ZK: 'true'` is missing from CI env, the compiler generates ZK proofs which takes 10-60x longer. CI will timeout. Fix: add `SKIP_ZK: 'true'` to the env section of the compile step.
5. **Node version mismatch** — CI uses a different Node version than local. Fix: use `.nvmrc` file and `setup-node` with `node-version-file: '.nvmrc'`.
6. **Caching issues** — stale Turbo cache or npm cache causing old artifacts to be used. Fix: clear caches (`turbo clean` or delete `node_modules/.cache`), or ensure cache keys include relevant file hashes.
7. **Playwright in CI** — browsers not installed. Fix: add `npx playwright install --with-deps chromium` step before E2E tests. Only install chromium (not all browsers) to save time.

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-cq/skills/quality-check/references/
git commit -m "feat(midnight-cq): add quality-check reference files"
```

---

## Task 10: cq-reviewer Agent

**Files:**
- Create: `plugins/midnight-cq/agents/cq-reviewer.md`

- [ ] **Step 1: Write cq-reviewer.md**

Create `plugins/midnight-cq/agents/cq-reviewer.md`. The agent must:
- Have YAML frontmatter:
  ```yaml
  name: cq-reviewer
  description: >-
    Use this agent to audit a Midnight project's code quality setup and produce
    a detailed report with recommendations. Checks Biome configuration, Vitest
    setup, Playwright config, Husky hooks, CI workflows, test quality, and
    coverage gaps. Read-only — never modifies files.

    Example 1: "Review my project's code quality setup" — scans for all CQ
    tooling and validates against Midnight standards.

    Example 2: "Are my tests good enough?" — analyzes test files for coverage
    gaps, missing error assertions, unused simulator features.

    Example 3: "Is my CI configured correctly?" — validates workflow files
    against the recommended two-workflow pattern.
  tools: Read, Grep, Glob, Bash
  model: sonnet
  color: green
  skills: midnight-cq:quality-init, midnight-cq:compact-testing, midnight-cq:dapp-testing
  ```
- System prompt must define the agent as a read-only auditor that NEVER modifies files
- Document the 6-step workflow from the spec: scan tooling presence → flag conflicts → validate configs → assess test quality → check CI completeness → produce report
- The report format must use three severity tiers: Critical (missing/broken tooling), Warnings (suboptimal config, coverage gaps), Suggestions (improvements)
- Include specific checks to perform:
  - Does `biome.json` exist? Does it include the Midnight rules?
  - Are ESLint/Prettier configs present? (conflict)
  - Does `vitest.config.ts` exist with correct `globalSetup`?
  - Does `.husky/pre-commit` exist with `biome ci --changed`?
  - Does `.husky/pre-push` exist with the full suite?
  - Do `.github/workflows/checks.yml` and `test.yml` exist?
  - For each `.compact` file: does a corresponding mock exist? Does a simulator exist? Does a test file exist?
  - In test files: are `.as()` calls used for access control tests? Are error messages asserted exactly? Are there `beforeEach` blocks creating fresh simulators?

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-cq/agents/cq-reviewer.md
git commit -m "feat(midnight-cq): add cq-reviewer agent"
```

---

## Task 11: cq-runner Agent

**Files:**
- Create: `plugins/midnight-cq/agents/cq-runner.md`

- [ ] **Step 1: Write cq-runner.md**

Create `plugins/midnight-cq/agents/cq-runner.md`. The agent must:
- Have YAML frontmatter:
  ```yaml
  name: cq-runner
  description: >-
    Use this agent to run all code quality checks on a Midnight project and
    produce a structured report interpreting the results. Executes Biome linting,
    TypeScript type checking, Compact compilation, Vitest tests, and Playwright
    E2E tests. Read-only — runs checks but never modifies files.

    Example 1: "Run all quality checks" — executes the full suite and reports
    results with explanations and fix recommendations.

    Example 2: "Why are my tests failing?" — runs vitest, captures output,
    interprets simulator errors, and suggests fixes.

    Example 3: "Check if my code is ready to push" — runs the same checks as
    the pre-push hook and reports any issues.
  tools: Read, Grep, Glob, Bash
  model: sonnet
  color: yellow
  skills: midnight-cq:quality-check
  ```
- System prompt must define the agent as a check executor that NEVER modifies files
- Document the 5-step workflow: detect project type → run checks in order → capture output → interpret results → produce report
- Check execution order: `biome ci` → `tsc --noEmit` → `compact-compiler --skip-zk` (if `.compact` files present) → `vitest run` → `npx playwright test` (if `playwright.config.ts` present)
- Report format: Summary (pass/fail per check with counts), Details (each failure with explanation, file location, recommended fix), Patterns (recurring issues grouped)
- Include error interpretation rules: how to translate Biome rule names to explanations, how to categorize tsc errors (artifact issue vs handwritten code), how to parse vitest simulator failures
- Emphasize: if a check's tooling is not installed (e.g., no Biome, no vitest), report that as a finding rather than crashing. Suggest running `midnight-cq:quality-init` to set up missing tooling.

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-cq/agents/cq-runner.md
git commit -m "feat(midnight-cq): add cq-runner agent"
```

---

## Task 12: README.md

**Files:**
- Create: `plugins/midnight-cq/README.md`

- [ ] **Step 1: Write README.md**

Create `plugins/midnight-cq/README.md` following the compact-core README convention. Must contain:

1. **Title and description** — `# midnight-cq` + one-paragraph description matching plugin.json
2. **Features** — bulleted list of all capabilities
3. **Prerequisites** — Compact CLI, Node.js, Biome (`npm install --save-dev @biomejs/biome`)
4. **Installation** — plugin marketplace install command
5. **Agents** section:
   - `cq-reviewer` — description and example usage
   - `cq-runner` — description and example usage
6. **Skills** section (each with description and **Triggers on** keywords):
   - `quality-init`
   - `compact-testing`
   - `dapp-testing`
   - `quality-check`
7. **Companion Plugins** — compact-core, midnight-tooling, dapp-development
8. **License** — MIT

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-cq/README.md
git commit -m "feat(midnight-cq): add README"
```

---

## Task 13: Final Verification

- [ ] **Step 1: Verify complete file tree**

Run:
```bash
find plugins/midnight-cq -type f | sort
```

Expected output (22 files):
```
plugins/midnight-cq/.claude-plugin/plugin.json
plugins/midnight-cq/README.md
plugins/midnight-cq/agents/cq-reviewer.md
plugins/midnight-cq/agents/cq-runner.md
plugins/midnight-cq/skills/compact-testing/SKILL.md
plugins/midnight-cq/skills/compact-testing/references/mock-patterns.md
plugins/midnight-cq/skills/compact-testing/references/simulator-api.md
plugins/midnight-cq/skills/compact-testing/references/test-examples.md
plugins/midnight-cq/skills/compact-testing/references/witness-testing.md
plugins/midnight-cq/skills/dapp-testing/SKILL.md
plugins/midnight-cq/skills/dapp-testing/references/integration-testing.md
plugins/midnight-cq/skills/dapp-testing/references/playwright-patterns.md
plugins/midnight-cq/skills/quality-check/SKILL.md
plugins/midnight-cq/skills/quality-check/references/biome-diagnostics.md
plugins/midnight-cq/skills/quality-check/references/ci-troubleshooting.md
plugins/midnight-cq/skills/quality-check/references/test-failures.md
plugins/midnight-cq/skills/quality-init/SKILL.md
plugins/midnight-cq/skills/quality-init/references/biome-config.md
plugins/midnight-cq/skills/quality-init/references/ci-workflows.md
plugins/midnight-cq/skills/quality-init/references/husky-hooks.md
plugins/midnight-cq/skills/quality-init/references/playwright-config.md
plugins/midnight-cq/skills/quality-init/references/vitest-config.md
```

- [ ] **Step 2: Verify all SKILL.md files have valid frontmatter**

Run:
```bash
for f in plugins/midnight-cq/skills/*/SKILL.md; do echo "=== $f ==="; head -4 "$f"; echo; done
```

Expected: each file starts with `---`, has `name:`, `description:`, and closes with `---`.

- [ ] **Step 3: Verify all agent files have valid frontmatter**

Run:
```bash
for f in plugins/midnight-cq/agents/*.md; do echo "=== $f ==="; head -6 "$f"; echo; done
```

Expected: each file starts with `---`, has `name:`, `description:`, `tools:`, `model:`.

- [ ] **Step 4: Verify no files reference ESLint or Prettier as something to install**

Run:
```bash
grep -r "npm install.*eslint\|npm install.*prettier\|yarn add.*eslint\|yarn add.*prettier" plugins/midnight-cq/ || echo "PASS: no ESLint/Prettier install commands found"
```

Expected: `PASS: no ESLint/Prettier install commands found`

- [ ] **Step 5: Verify Playwright is always headless**

Run:
```bash
grep -r "headless" plugins/midnight-cq/
```

Expected: all occurrences set `headless: true` or discuss the headless-only policy. No `headless: false`.

- [ ] **Step 6: Final commit if any files were adjusted**

```bash
git status
# If clean, skip. If changes exist:
git add plugins/midnight-cq/
git commit -m "fix(midnight-cq): address verification findings"
```
