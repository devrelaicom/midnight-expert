---
name: compact-cli-dev:init
description: Initialize a new CLI package for a Midnight Compact contract
allowed-tools: Bash, Read, AskUserQuestion
argument-hint: "[directory] [--project-name <name>] [--contract-name <name>] [--contract-path <path>]"
---

Scaffold a new Oclif CLI for a Midnight Compact smart contract using the template engine. Handles argument parsing, value inference, template rendering, and post-scaffold setup.

## Step 1 -- Parse Arguments

Analyze `$ARGUMENTS` to extract:

| Argument | Description | Default |
|----------|-------------|---------|
| `directory` | Target directory for the CLI (positional, first arg) | `./cli` |
| `--project-name` | Project name, used to derive the package name | inferred |
| `--contract-name` | Contract name, used for import paths and package references | inferred |
| `--contract-path` | Path to the compiled contract's ZK config directory | inferred |

All values are optional. Missing values are inferred in Step 2.

## Step 2 -- Infer Missing Values

For each value not provided in the arguments, attempt automatic inference:

### project-name

1. Read `package.json` in the project root. If it exists, use the `name` field (strip any `@scope/` prefix).
2. If no `package.json` exists, use the current working directory name.

### contract-name

1. Scan for `.compact` files in standard locations: `contract/src/`, `contracts/src/`, `../contract/src/`, `src/`.
2. Look for `managed/` directories that indicate a compiled contract: `contract/src/managed/`, `contracts/managed/`, `../contract/src/managed/`.
3. Extract the contract name from the `.compact` filename (without extension) or from the `managed/` subdirectory name.

### contract-path

1. If `contract-name` is known, check these standard locations in order:
   - `../contract/src/managed/<contract-name>`
   - `./contract/src/managed/<contract-name>`
   - `../contracts/managed/<contract-name>`
   - `./contracts/src/managed/<contract-name>`
2. Use the first path that exists.

If any value still cannot be inferred after these checks, use AskUserQuestion to ask the user. Ask for all missing values in a single question to avoid multiple round-trips.

## Step 3 -- Build Context Object

Construct the template context from the resolved values:

| Key | Value |
|-----|-------|
| `PROJECT_NAME` | The resolved project name |
| `CLI_PACKAGE_NAME` | `${PROJECT_NAME}-cli` |
| `CONTRACT_NAME` | The resolved contract name |
| `CONTRACT_PACKAGE` | `@midnight-ntwrk/${CONTRACT_NAME}-contract` |
| `CONTRACT_ZK_CONFIG_PATH` | The resolved path to the contract's ZK config directory |
| `GENERATED_AT` | Current ISO 8601 timestamp (from `date -u +"%Y-%m-%dT%H:%M:%SZ"`) |

## Step 4 -- Resolve Template Path

The templates live inside this plugin's installation directory. Since `${CLAUDE_PLUGIN_ROOT}` does not expand in markdown files, resolve the path at runtime:

```bash
PLUGIN_ROOT=$(find ~/.claude -path "*/compact-cli-dev/.claude-plugin/plugin.json" -exec dirname {} \; 2>/dev/null | head -1 | xargs dirname)
TEMPLATE_DIR="${PLUGIN_ROOT}/skills/core/templates/cli"
```

Verify the template directory exists before proceeding:

```bash
[ -d "$TEMPLATE_DIR" ] && echo "Template directory found: $TEMPLATE_DIR" || echo "ERROR: Template directory not found"
```

If the template directory is not found, report the error and stop.

## Step 5 -- Run Template Engine

Invoke the template engine via stdin/stdout. Construct the JSON input with the template directory, output directory, and context object:

```bash
echo '{"template":"<TEMPLATE_DIR>","output":"<directory>","context":{"PROJECT_NAME":"...","CLI_PACKAGE_NAME":"...","CONTRACT_NAME":"...","CONTRACT_PACKAGE":"...","CONTRACT_ZK_CONFIG_PATH":"...","GENERATED_AT":"..."}}' | npx @aaronbassett/template-engine
```

The template engine will:
- Copy all files from the template directory to the output directory
- Substitute `{{VARIABLE}}` placeholders in `.tmpl` files and rename them (removing `.tmpl`)
- Copy non-template files as-is

Parse the stdout JSON result. It returns `{"success": true, "filesCreated": [...]}` on success. If it fails, the stderr will contain the error message -- report it to the user.

## Step 6 -- Post-Scaffold Setup

Run the following from the scaffolded directory:

```bash
cd <directory>
npm install
```

After `npm install`, initialize husky for git hooks:

```bash
cd <directory>
npx husky init
```

The template includes `.husky/pre-commit` and `.husky/pre-push` hook files. After `npx husky init`, verify these files are in place:

```bash
ls -la <directory>/.husky/pre-commit <directory>/.husky/pre-push
```

If `npx husky init` overwrote the template's hook files, restore them by re-running the template engine for just those files, or by writing the expected content back. The pre-commit hook should run `npx biome check .` and the pre-push hook should run `npx tsc --noEmit && npx vitest run`.

## Step 7 -- Report

Print a summary to the user:

```
CLI scaffolded at <directory>

Files created: <count>
Package name: <CLI_PACKAGE_NAME>
Contract: <CONTRACT_NAME> (<CONTRACT_PACKAGE>)

Next steps:
  cd <directory>
  npm run dev -- wallet:create
  npm run dev -- wallet:fund <wallet-name>
  npm run dev -- deploy
```
