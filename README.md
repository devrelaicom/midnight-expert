<p align="center">
  <img src="assets/banner.png" alt="midnight expert" width="100%" />
</p>

**midnight-expert** is a marketplace of [Claude Code plugins](https://docs.anthropic.com/en/docs/claude-code/plugins) for developers building on the [Midnight Network](https://midnight.network/). The plugins help you write and review Compact smart contracts, scaffold and wire up DApp frontends, mechanically verify claims about your code and the SDK, manage the local toolchain and devnet, and look up whichever error code just spoiled your afternoon — all from inside Claude Code, without leaving your editor or stitching together half a dozen browser tabs.

This project extends the Midnight Network with additional developer tooling.

**[midnightntwrk.expert](https://midnightntwrk.expert/)** — documentation, guides, and resources for Midnight developers.

## Install

### Automatic install for Claude Code

Run this in your terminal and follow the prompts:

```bash
curl -fsSL midnightntwrk.expert/install.sh | bash
```

The installer detects your Claude Code setup, registers the marketplace, and walks you through picking which plugins to enable.

> [!TIP]
> Updates are published to [`midnightntwrk.expert`](https://midnightntwrk.expert/) **3–5 days after they're merged into the GitHub repository**. The delay gives the community time for public testing and feedback. If you'd rather live on the bleeding edge, use the GitHub repo directly as your marketplace address — substitute `devrelaicom/midnight-expert` for `https://midnightntwrk.expert/` anywhere it appears in the manual install instructions below.

### Install from within Claude Code

You can ask Claude itself to handle the install for you. From any session:

> Please fetch <https://midnightntwrk.expert> and follow the instructions for installing Midnight Expert.

Or do it manually with the built-in plugin manager:

1. Run `/plugin` to open the plugin manager.
2. Choose **Add marketplace** and paste `https://midnightntwrk.expert` (or `devrelaicom/midnight-expert` for bleeding edge).
3. Use **Browse plugins** to pick which plugins from the marketplace you want enabled.

### Install using the Claude CLI

If you prefer working from a terminal, register the marketplace and then install plugins individually:

```bash
claude plugin marketplace add https://midnightntwrk.expert
# or, for bleeding-edge releases:
claude plugin marketplace add devrelaicom/midnight-expert
```

Install the meta-plugin first and run its diagnostics to confirm your environment is ready:

```bash
claude plugin install --scope user midnight-expert@midnight-expert
```

```
/midnight-expert:doctor
```

The `--scope user` flag installs the plugin **globally for your user** so it's available in every project. Drop the flag to install only for the current project.

## Plugins

You can install any plugin from inside Claude Code with `/plugin`, or from the terminal with `claude plugin install --scope user <plugin>@midnight-expert`. The 13 plugins are grouped by what they do:

### Smart Contract Development

| | Plugin | Description |
|---|--------|-------------|
| <img src="plugins/compact-core/assets/mascot.png" width="60" /> | **[compact-core](plugins/compact-core/)** | Core knowledge for writing Compact — contract structure, data types, ledger declarations, circuits, witnesses, privacy/disclosure rules, tokens, circuit costs, debugging, and code review.<br /><br />```bash<br>claude plugin install --scope user compact-core@midnight-expert<br>``` |
| <img src="plugins/compact-examples/assets/mascot.png" width="60" /> | **[compact-examples](plugins/compact-examples/)** | Compilable Compact examples — beginner contracts, reusable modules, token implementations, and full applications with witnesses and tests, all at `pragma language_version >= 0.22`.<br /><br />```bash<br>claude plugin install --scope user compact-examples@midnight-expert<br>``` |
| <img src="plugins/compact-cli-dev/assets/mascot.png" width="60" /> | **[compact-cli-dev](plugins/compact-cli-dev/)** | Scaffold and develop Oclif CLIs for Compact contracts — wallet management, contract deployment, devnet control, plus an agent for ongoing CLI work.<br /><br />```bash<br>claude plugin install --scope user compact-cli-dev@midnight-expert<br>``` |

### DApp Development

| | Plugin | Description |
|---|--------|-------------|
| <img src="plugins/midnight-dapp-dev/assets/mascot.png" width="60" /> | **[midnight-dapp-dev](plugins/midnight-dapp-dev/)** | Scaffold and build Midnight DApp frontends — Vite + React 19 + shadcn + Tailwind v4 templates, wallet integration, provider architecture, and a development agent for ongoing UI work.<br /><br />```bash<br>claude plugin install --scope user midnight-dapp-dev@midnight-expert<br>``` |

### Testing & Code Quality

| | Plugin | Description |
|---|--------|-------------|
| <img src="plugins/midnight-cq/assets/mascot.png" width="60" /> | **[midnight-cq](plugins/midnight-cq/)** | Code quality tooling for Midnight projects — linting, formatting, type checking, contract/DApp/ledger/wallet testing, Git hooks, and CI workflows.<br /><br />```bash<br>claude plugin install --scope user midnight-cq@midnight-expert<br>``` |
| <img src="plugins/midnight-verify/assets/mascot.png" width="60" /> | **[midnight-verify](plugins/midnight-verify/)** | Verification framework for Midnight claims — compile + execute Compact, type-check SDK code, run ZKIR through the WASM checker, cross-check witness implementations, and inspect compiler/ledger/wallet source. Multi-agent pipeline behind `/verify`.<br /><br />```bash<br>claude plugin install --scope user midnight-verify@midnight-expert<br>``` |
| <img src="plugins/midnight-fact-check/assets/mascot.png" width="60" /> | **[midnight-fact-check](plugins/midnight-fact-check/)** | Fact-checking pipeline for Midnight content — extracts testable claims from markdown, code, PDFs, URLs or GitHub repos, classifies them by domain, verifies each via `midnight-verify`, and produces structured reports.<br /><br />```bash<br>claude plugin install --scope user midnight-fact-check@midnight-expert<br>``` |

### Toolchain & Infrastructure

| | Plugin | Description |
|---|--------|-------------|
| <img src="plugins/midnight-tooling/assets/mascot.png" width="60" /> | **[midnight-tooling](plugins/midnight-tooling/)** | Install, configure, and manage the Compact CLI, the local devnet (node, indexer, proof server), compiler version switching, diagnostics, and ecosystem release notes.<br /><br />```bash<br>claude plugin install --scope user midnight-tooling@midnight-expert<br>``` |
| <img src="plugins/midnight-wallet/assets/mascot.png" width="60" /> | **[midnight-wallet](plugins/midnight-wallet/)** | Wallet SDK reference, test-wallet management patterns, and SDK regression checking for Midnight Network development.<br /><br />```bash<br>claude plugin install --scope user midnight-wallet@midnight-expert<br>``` |
| <img src="plugins/midnight-status-codes/assets/mascot.png" width="60" /> | **[midnight-status-codes](plugins/midnight-status-codes/)** | Catalog and lookup for every Midnight error code, status code, and tagged error across the node, ledger, indexer, wallet, SDK, compiler, proof server, and DApp connector.<br /><br />```bash<br>claude plugin install --scope user midnight-status-codes@midnight-expert<br>``` |

### Knowledge & Education

| | Plugin | Description |
|---|--------|-------------|
| <img src="plugins/core-concepts/assets/mascot.png" width="60" /> | **[core-concepts](plugins/core-concepts/)** | Conceptual foundations for the Midnight Network — architecture, data models, privacy patterns, protocols (Kachina, Zswap), tokenomics, and zero-knowledge proofs.<br /><br />```bash<br>claude plugin install --scope user core-concepts@midnight-expert<br>``` |

### Meta

| | Plugin | Description |
|---|--------|-------------|
| <img src="plugins/midnight-expert/assets/mascot.png" width="60" /> | **[midnight-expert](plugins/midnight-expert/)** | Ecosystem diagnostics — health-checks plugin installation, MCP server connectivity, external CLI tools, cross-plugin references, and NPM registry access in one report.<br /><br />```bash<br>claude plugin install --scope user midnight-expert@midnight-expert<br>``` |
| <img src="plugins/midnight-plugin-utils/assets/mascot.png" width="60" /> | **[midnight-plugin-utils](plugins/midnight-plugin-utils/)** | Audits and resolves Claude plugin dependencies — validates installed plugins against `extends-plugin.json` declarations and resolves install paths with fuzzy matching.<br /><br />```bash<br>claude plugin install --scope user midnight-plugin-utils@midnight-expert<br>``` |

## Example Prompts

Most of the time you don't need to remember a slash command — once a plugin is installed, its skills activate based on what you're asking for. A few starting points:

- "Is my local Midnight proof server healthy, and is the indexer caught up to the node?"
- "Review `contracts/Report.compact` for potential privacy leaks before I push."
- "Why is my proof generation failing with status code `0x4b`?"
- "Scaffold a Vite + React DApp wired to my counter contract and connect it to the Lace wallet."
- "Fact-check this Midnight blog post against the current SDK and tell me what's drifted."
- "Set up `alice`, `bob`, and `charlie` as funded test wallets on the local devnet, with DUST registered for each."
- "Compile `MyToken.compact`, simulate a mint + transfer + burn, and show me the resulting ledger state."
- "Write a Compact contract for a sealed-bid voting system and walk me through the disclosure rules."
- "I'm getting `Implicit disclosure of witness value` — what does that mean and how do I fix it?"

Slash commands are also available when you want to invoke a specific workflow directly:

```
/midnight-verify:verify "Compact tuples are 0-indexed"
/midnight-tooling:devnet start
/midnight-wallet:setup-test-wallets alice bob charlie
/midnight-status-codes:lookup 0x4b
/midnight-fact-check:check path/to/article.md
/midnight-expert:doctor
```

## By the numbers

- **13** plugins
- **69** skills
- **13** slash commands
- **16** subagents
- **2** hook bundles
- **~37,700** lines of reference documentation
- **~21,800** lines of compilable example contracts, witnesses, and tests

## License

[MIT](LICENSE) — Copyright (c) 2026 Aaron Bassett
