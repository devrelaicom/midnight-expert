---
name: midnight-dapp-dev:init
description: >-
  This skill should be used when the user asks to "scaffold a Midnight DApp",
  "initialize a DApp UI", "add a frontend to my Midnight project",
  "create a DApp UI package", "set up a Midnight web app",
  "add a UI to my project", or invokes /midnight-dapp-dev:init.
version: 0.1.0
---

# Initialize Midnight DApp Frontend

Scaffold a Vite + React 19 + shadcn + Tailwind v4 UI package and a TypeScript
API package into the current project.

## Usage

Run the init script:

```bash
bash "${CLAUDE_SKILL_ROOT}/scripts/init.sh"
```

The script:
1. Reads the current project's `package.json` to derive the project name
2. Scans for Compact contract packages (directories with `managed/` output)
3. Detects the package manager from lockfile presence
4. Prompts to confirm or override each derived value
5. Copies the template tree from the core skill's `templates/` directory
6. Runs placeholder substitution across all copied files
7. Updates root `package.json` workspaces if applicable

## After Scaffolding

1. Install dependencies with the detected package manager
2. Configure the `copy-contract-keys` script in the UI `package.json` with the path to the contract's compiled `keys/` and `zkir/` output
3. Wire up the contract in the API package's `src/index.ts` and `src/types.ts`
4. Run `npm run dev` in the UI directory to start the dev server

## Placeholders

The template uses these `{{PLACEHOLDER}}` variables:

| Variable | Description |
|---|---|
| `{{PROJECT_NAME}}` | Project name from root package.json |
| `{{UI_PACKAGE_NAME}}` | UI package name (derived: `{project}-ui`) |
| `{{API_PACKAGE_NAME}}` | API package name (derived: `{project}-api`) |
| `{{UI_DIR}}` | UI directory name (default: `ui`) |
| `{{API_DIR}}` | API directory name (default: `api`) |
| `{{CONTRACT_PACKAGE}}` | Contract package name (scanned or prompted) |
| `{{PACKAGE_MANAGER}}` | Detected package manager |
