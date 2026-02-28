---
name: compact-init-project
description: This skill should be used when the user asks to create a new Midnight project, scaffold a Compact smart contract project, use create-mn-app, initialize a DApp, set up a new Midnight application, start a new project, use a project template, set up hello-world or counter template, or is doing first-time Midnight development environment setup. Also triggered by "new project", "start a project", "init project", "create-mn-app", or "scaffold".
---

# Initialize a New Midnight/Compact Project

This skill guides you through creating a new Midnight project using `create-mn-app`, the official scaffolding tool. Follow the workflow in `references/create-mn-app-workflow.md` step by step.

## Supported Templates

| Template | Type | Description |
|----------|------|-------------|
| **Hello World** | Bundled | Simple message storage contract. Best for first-time Midnight developers. |
| **Counter** | Remote (clone) | Increment/decrement counter with ZK proofs. Demonstrates state management and npm workspaces. |

## Quick Start

Follow `references/create-mn-app-workflow.md` phases in order:

1. **Environment Check** — Run `/midnight-tooling:doctor` to verify Node 22+, Docker, and Compact CLI
2. **Template Selection** — Ask user which template (hello-world or counter)
3. **Scaffolding** — Run `npx create-mn-app@latest <name> --template <template>`
4. **Proof Server** — Run `/midnight-tooling:run-proof-server` to start Docker proof server
5. **Compile** — Compile the Compact contract and verify managed output
6. **Summary** — Show what was created and next steps

## Key Dependencies

This skill delegates to midnight-tooling plugin commands:
- `/midnight-tooling:doctor` — prerequisite verification
- `/midnight-tooling:run-proof-server` — Docker proof server lifecycle
- `/midnight-tooling:install-cli` — Compact compiler installation (if needed)

## Not For

- Existing project troubleshooting → use `midnight-tooling:troubleshooting`
- Writing custom Compact contracts → use `compact-structure`, `compact-ledger`, etc.
- Deploying to Preprod → out of scope (involves wallet creation and faucet funding)
- Adding features to an existing project → use domain-specific compact-core skills

## Reference Files

| Topic | Reference |
|-------|-----------|
| Step-by-step workflow (follow this) | `references/create-mn-app-workflow.md` |
| Project layouts, SDK versions, network URLs | `references/project-structure.md` |
| Common init failures and fixes | `references/troubleshooting.md` |
