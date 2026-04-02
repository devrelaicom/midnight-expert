# midnight-cq

Code quality tooling for Midnight Network projects — linting, formatting, type checking, testing, Git hooks, and CI workflows.

A [Claude Code plugin](https://docs.anthropic.com/en/docs/claude-code/plugins) that provides skills, commands, and agents for enforcing code quality across Midnight Network projects. Covers Biome configuration, Vitest contract testing with the OpenZeppelin simulator, Playwright DApp E2E testing, Husky Git hooks, and GitHub Actions CI workflows.

## Features

- Configure Biome as the exclusive linter and formatter (no ESLint, no Prettier)
- Migrate existing ESLint/Prettier setups to Biome
- Write Compact contract unit tests using the OpenZeppelin simulator framework
- Test access control, error cases, and ledger state mutations with Vitest
- Write Playwright E2E and integration tests for Midnight DApps
- Mock `ContractProvider` and inject wallet stubs for deterministic CI testing
- Set up Husky pre-commit and pre-push hooks with the correct check split
- Scaffold GitHub Actions workflows with the recommended two-workflow pattern
- Audit a project's code quality setup and produce a structured report
- Run and interpret Biome, tsc, compact-compiler, Vitest, and Playwright output

## Prerequisites

- [Compact CLI](https://docs.midnight.network/) installed
- Node.js for TypeScript development and testing
- [Biome](https://biomejs.dev/) for linting and formatting

## Installation

Install via the Claude Code plugin marketplace:

```
/install-plugin midnight-cq
```

Or add the plugin manually by cloning it into your Claude Code plugins directory.

## Agents

### cq-reviewer

Audits a Midnight project's code quality setup and produces a detailed report with recommendations. Checks Biome configuration, Vitest setup, Playwright config, Husky hooks, CI workflows, test quality, and coverage gaps. Read-only — never modifies files.

### cq-runner

Runs all code quality checks on a Midnight project and produces a structured report interpreting the results. Executes Biome linting, TypeScript type checking, Compact compilation, Vitest tests, and Playwright E2E tests. Read-only — runs checks but never modifies files.

## Skills

### quality-init

Set up all code quality tooling for a Midnight Network project. Scaffolds Biome configuration, Vitest with the simulator pattern for Compact projects, Playwright for DApp projects, Husky pre-commit and pre-push hooks, and GitHub Actions CI workflows. Detects project type automatically and migrates conflicting ESLint/Prettier setups before scaffolding.

**Triggers on**: set up linting, add code quality, configure biome, init project quality, add CI workflows, set up git hooks, add testing, migrate from ESLint, migrate from Prettier

### compact-testing

Write and run Compact contract unit tests using the OpenZeppelin simulator framework (`@openzeppelin-compact/contracts-simulator`). Covers the 4-layer test structure, simulator instantiation and isolation, witness overrides, access control testing, error case assertions, ledger state verification, parameterized tests with `describe.each`, and invariant checks with `afterEach`.

**Triggers on**: write compact tests, test my contract, set up simulator, mock contract, test witnesses, unit tests for compact, createSimulator, witness override, test coverage, simulator pattern

### dapp-testing

Write DApp E2E and integration tests for Midnight DApps using Playwright. Covers the three testing layers (E2E, integration, unit), the page object pattern, `ContractProvider` mocking with the simulator, wallet stub injection via `addInitScript`, async assertions with `waitFor`, and CI-safe headless configuration.

**Triggers on**: test my dapp, write e2e tests, test wallet connection, playwright midnight, test transaction UI, integration test frontend, end-to-end test, browser test, mock ContractProvider, test wallet disconnect

### wallet-testing

Write tests for custom wallet implementations and extensions built on the Midnight Wallet SDK packages (`@midnight-ntwrk/wallet-sdk-*`). Covers Effect/Either unwrapping at the SDK boundary, Observable state assertions, branded type fixture construction, WalletBuilder test setup, and test double patterns for capabilities and services.

**Triggers on**: write wallet tests, test my wallet variant, test my capability, test my wallet service, test WalletBuilder, write wallet SDK tests, test Effect code, test Observable state, mock wallet services, test wallet state management

### dapp-connector-testing

Write tests for DApp Connector API integration — the `window.midnight` injection, `InitialAPI.connect()`, and `ConnectedAPI` methods. Covers configurable wallet stubs implementing the full ConnectedAPI, error code handling (Rejected vs PermissionRejected), progressive enhancement testing, and XSS prevention.

**Triggers on**: test DApp Connector API, test wallet connection, test makeTransfer, test balanceTransaction, mock ConnectedAPI, stub wallet for tests, test wallet errors, test PermissionRejected, test progressive enhancement

### ledger-testing

Write tests for code that uses `@midnight-ntwrk/ledger-v8` and `@midnight-ntwrk/onchain-runtime` directly. Covers proof staging lifecycle (UnprovenTransaction → proved → erased), ZswapLocalState and DustLocalState management, time-dependent Dust balance assertions, CostModel fee calculations, cryptographic fixture generation via `sample*` functions, and serialization round-trip testing.

**Triggers on**: write ledger tests, test transaction construction, test proof staging, test ZswapLocalState, test DustLocalState, test cost model, test coinCommitment, test ledger-v8, test onchain-runtime, test well-formedness

### quality-check

Run and interpret all quality checks for a Midnight project. Covers Biome lint and format output, TypeScript `tsc --noEmit` errors (including stale `managed/` artifacts), Compact compiler errors and disclosure violations, Vitest failures with simulator stack trace interpretation, and Playwright timeout and element-not-found failures.

**Triggers on**: run linting, check code quality, run tests, why is biome failing, fix lint errors, CI is failing, type check errors, biome error, vitest failing, tsc error, interpret Biome output

## Companion Plugins

Some features reference skills from companion plugins:

- **compact-core** — Compact language, testing patterns, and deployment skills used by the reviewer agent
- **midnight-tooling** — CLI installation, proof server management, devnet, and release notes
- **midnight-dapp-dev** — DApp architecture, provider setup, and wallet integration skills

## License

[MIT](LICENSE)
