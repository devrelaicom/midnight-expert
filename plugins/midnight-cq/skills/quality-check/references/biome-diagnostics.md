# Biome Diagnostics Reference

## Reading Biome Output

Every Biome violation follows this format:

```
path/to/file.ts:line:col rule/name LEVEL description
```

Example:

```
src/contract/TokenLedger.ts:34:7 style/noUnusedTemplateLiteral ERROR Useless template literal. Use a regular string literal instead.
```

- **`path/to/file.ts`** — path relative to the project root.
- **`line:col`** — 1-indexed line and column of the offending token.
- **`rule/name`** — the Biome rule identifier. Navigate to `https://biomejs.dev/linter/rules/<rule-name>` (kebab-case) for rationale and examples. For example, `style/noUnusedTemplateLiteral` → `https://biomejs.dev/linter/rules/no-unused-template-literal`.
- **`LEVEL`** — always `ERROR` in Midnight projects. No warnings in CI.
- **Format violations** — reported as `format` with a unified diff showing the expected layout. Fix with `npx biome check --write`.
- **Exit codes** — `0` means clean. `1` means at least one violation.

### Suppressed output

Biome prints a summary line at the end:

```
Found 4 errors.
```

Pipe the full output to a file if you need to triage all violations at once:

```bash
npx biome ci 2>&1 | tee biome-report.txt
```

---

## The Midnight Biome Ruleset

All rules below are enforced at `error` level. There are no warnings — every violation blocks CI.

| Rule | Category | What it catches | Why enabled | How to fix |
|------|----------|-----------------|-------------|------------|
| `noUnusedVariables` | correctness | Variables declared but never read | Dead code — indicates incomplete refactors or copy-paste errors | Delete the variable, or use it. Prefix with `_` only when the variable is required by a destructure pattern or callback signature you do not control. |
| `noUnusedImports` | correctness | Import statements whose bindings are never used | Bloats bundles and misleads readers about dependencies | Delete the import, or use the imported binding. Type-only imports that are used in type positions should be prefixed with `import type`. |
| `noBarrelFile` | performance | A file that only re-exports from other modules (`export { ... } from '...'`) | Barrel files force bundlers to load every export even when only one is needed, defeating tree-shaking | Replace barrel re-exports with direct imports at each call site. If the file is a genuine public API entrypoint, suppress with `biome-ignore` and a justification comment (see below). |
| `noReExportAll` | performance | `export * from '...'` wildcard re-exports | Wildcard re-exports make it impossible for bundlers to statically analyse what is exported, blocking tree-shaking | Replace with named re-exports (`export { Foo, Bar } from '...'`) or with direct imports at call sites. |
| `noParameterAssign` | style | Reassignment of a function parameter (`param = newValue`) | Mutating parameters hides side effects and makes the function's contract ambiguous to callers | Introduce a local variable: `const result = param ?? defaultValue;` |
| `useAsConstAssertion` | style | Object or array literal whose type could be narrowed with `as const` | `as const` produces literal types rather than widened types, preventing accidental mutation and improving inference | Add `as const` at the end of the literal expression. |
| `useDefaultParameterLast` | style | Required parameters following optional parameters in a function signature | Callers cannot omit optional parameters that appear before required ones without passing `undefined` | Reorder so required parameters come first, then optional ones. |
| `useSelfClosingElements` | style | JSX elements with no children written with explicit closing tag (`<Foo></Foo>`) | Self-closing form (`<Foo />`) is shorter and signals "no children expected" | Replace `<Foo></Foo>` with `<Foo />`. |
| `useSingleVarDeclarator` | style | Multiple variable declarations in one `const`/`let` statement (`const a = 1, b = 2`) | Comma-separated declarations are easy to misread and harder to add comments to | Split into one declaration per statement. |
| `noUnusedTemplateLiteral` | style | Template literals with no interpolations (`` `plain string` ``) | Template literals without `${...}` add noise and mislead readers into expecting interpolation | Replace with a plain string literal using single quotes: `'plain string'`. |
| `useNumberNamespace` | style | Calls to global `parseInt`, `parseFloat`, `isNaN`, `isFinite` | The global functions have surprising coercion behaviour. The `Number.*` equivalents are strict | Replace with `Number.parseInt`, `Number.parseFloat`, `Number.isNaN`, `Number.isFinite`. |
| `noInferrableTypes` | style | Explicit type annotations that duplicate what the initialiser already tells TypeScript (`const x: string = 'hello'`) | Redundant annotations are noise. TypeScript infers these correctly without help | Delete the type annotation. Keep explicit types where the initialiser is ambiguous or where the annotation serves as documentation. |
| `noUselessElse` | style | `else` block after an `if` block that always returns, throws, or continues | The `else` is unreachable — the `if` already transferred control | Remove the `else` keyword and de-indent the block. The code after the `if` is already the "else" branch. |
| `useConsistentArrayType` | style | `Array<T>` generic syntax mixed with `T[]` shorthand syntax | Inconsistency makes code harder to scan. Midnight projects standardise on `T[]` shorthand | Replace `Array<T>` with `T[]` throughout. For readonly arrays, use `readonly T[]`. |
| `useErrorMessage` | suspicious | `new Error()` or `throw` with no message argument | An error without a message is useless in logs and stack traces | Always pass a descriptive message: `new Error('TokenLedger: insufficient balance')`. |
| `noConsole` | suspicious | `console.warn`, `console.error`, `console.debug`, `console.info`, `console.trace` (everything except `console.log`) | Unintentional console output pollutes logs. `console.log` is allowed for intentional output; other methods typically indicate debugging code left in by accident | Remove the call, replace with a proper logger, or suppress with `biome-ignore` if the call is intentional in a non-test context. |

---

## `biome-ignore` Usage

### Syntax

```ts
// biome-ignore rule/ruleName: <explanation>
const problematicLine = doSomething();
```

For multi-line suppression, place the comment on the line immediately before the offending line. For format suppression, use:

```ts
// biome-ignore format: <explanation>
const matrix = [[1, 0, 0],
                [0, 1, 0],
                [0, 0, 1]];
```

The explanation is **required**. Biome rejects `biome-ignore` comments without a colon and message. The explanation should state why the rule does not apply here — not just restate what the rule is.

Good:
```ts
// biome-ignore performance/noBarrelFile: public SDK entrypoint — consumers import from here
export { TokenLedger } from './ledger';
```

Bad:
```ts
// biome-ignore performance/noBarrelFile: barrel file
export { TokenLedger } from './ledger';
```

### When suppression is acceptable

- `noBarrelFile` on a deliberate public entrypoint (`index.ts` or `mod.ts`) that external consumers import from.
- `noConsole` on intentional diagnostic output inside a test setup file or script (prefer the `overrides` pattern in `biome.json` instead of per-line suppression when the entire file is a script or test helper).
- `noInferrableTypes` when an explicit type annotation serves as a deliberate, readable contract — e.g., a module-level constant that you want reviewers to see typed explicitly.

### When suppression is not acceptable

- `noUnusedVariables` or `noUnusedImports` — clean these up. Dead code must not accumulate behind suppressions.
- `useErrorMessage` — there is no legitimate reason to throw an error without a message.
- `noParameterAssign` — refactor the function instead.
- Any rule where the correct fix is a few-character change. Suppression should be a last resort, not a shortcut.

---

## `--changed` vs Full Run

### `biome ci --changed`

```bash
npx biome ci --changed --no-errors-on-unmatched
```

- Checks only files that differ from the default branch (requires `vcs.enabled: true` in `biome.json` and a Git repo with at least one commit).
- Used in CI `checks.yml` and recommended for local pre-commit checks.
- Fast — proportional to the size of the diff, not the size of the project.
- `--no-errors-on-unmatched` prevents failure when no JS/TS files changed (e.g., a commit that only touches `.compact` files).

### `biome ci` (full run)

```bash
npx biome ci
```

- Checks every file the Biome config includes.
- Use this to audit the entire codebase, or to reproduce a CI failure that uses the full run.
- **Important**: CI `checks.yml` uses `--changed`, but if you introduced a violation in a file you did not touch this branch, `--changed` will not catch it. Run the full check periodically.

### Rule of thumb

| Situation | Command |
|-----------|---------|
| Pre-commit / quick local check | `biome ci --changed --no-errors-on-unmatched` |
| Investigating a CI failure | `biome ci` (reproduce the full run) |
| Applying auto-fixes everywhere | `biome check --write` |
| Applying auto-fixes to changed files only | `biome check --changed --write` |

---

## Common False Positives

### `noBarrelFile` on entrypoints

If your project exposes a public `index.ts` that re-exports the SDK surface, Biome will flag it as a barrel file. This is not a false positive in the strict sense — it is a genuine barrel file — but it is intentional.

Suppress at the file level with an override in `biome.json` rather than per-line comments:

```jsonc
{
  "overrides": [
    {
      "includes": ["src/index.ts"],
      "linter": {
        "rules": {
          "performance": {
            "noBarrelFile": "off",
            "noReExportAll": "off"
          }
        }
      }
    }
  ]
}
```

Alternatively, a single per-file suppression at the top of the file:

```ts
// biome-ignore performance/noBarrelFile: public SDK entrypoint
// biome-ignore performance/noReExportAll: public SDK entrypoint
export * from './ledger';
```

### `noConsole` in test setup

Vitest setup files (`vitest.setup.ts`, `test/setup.ts`) often use `console.warn` or `console.error` to silence noisy third-party warnings during tests. The `noConsole` rule flags these.

Suppress at the directory level with an override rather than per-line comments — the entire setup file is a controlled environment:

```jsonc
{
  "overrides": [
    {
      "includes": ["**/*.test.ts", "**/*.spec.ts", "**/test/**", "**/vitest.setup.ts"],
      "linter": {
        "rules": {
          "suspicious": {
            "noConsole": "off"
          }
        }
      }
    }
  ]
}
```

This is the same override shown in the quality-init `biome-config.md` reference. If the project was scaffolded with `midnight-cq:quality-init`, this override is already present.
