# Midnight Component Map

## Source Repository

- **Repo**: `midnightntwrk/midnight-docs`
- **Branch**: `main`
- **Path**: `docs/relnotes/`
- **Index files**: `docs/relnotes/{component}.mdx`
- **Version files**: `docs/relnotes/{component}/{component}-{version-with-dashes}.mdx`

## Components

| Directory | Display Name | Description |
|-----------|-------------|-------------|
| `compact` | Compact compiler | Midnight's smart contract programming language and compiler |
| `compact-js` | Compact JS | JavaScript/TypeScript bindings for Compact |
| `compact-tools` | Compact developer tools | CLI utility for installing, updating, managing, and running the Compact toolchain and compiler |
| `dapp-connector-api` | DApp Connector API | API for connecting DApps to the Midnight network |
| `dapp-examples-deprecated` | DApp Examples (Deprecated) | Example DApp implementations (no longer maintained) |
| `faucet` | Faucet | Testnet token faucet |
| `lace` | Lace | Browser wallet extension for Midnight |
| `ledger` | Ledger | Core blockchain infrastructure — transaction validation, chain state, ZK proof verification, and WASM bindings |
| `midnight-indexer` | Midnight Indexer | Blockchain data indexing service |
| `midnight-js` | Midnight JS | JavaScript/TypeScript SDK for Midnight DApp development |
| `midnight-wallet-api` | Midnight Wallet API | Programmatic wallet interface for DApp backends |
| `node` | Node | Midnight network node |
| `onchain-runtime` | Onchain Runtime | ZK proof generation and transaction processing (now part of Ledger) |
| `proof-server` | Proof Server | Docker-based ZK proof generation service (now part of Ledger) |
| `vs-code-extension` | VS Code Extension | Visual Studio Code extension for Compact language support |
| `wallet` | Wallet | Wallet backend service |

## Aliases

Use this table for fuzzy matching when a user specifies a component name.

| Alias | Resolves To | Ambiguous? |
|-------|------------|------------|
| compact devtools | compact-tools | No |
| compact dev tools | compact-tools | No |
| compact cli | compact-tools | No |
| devtools | compact-tools | No |
| compact developer tools | compact-tools | No |
| compact-tools | compact-tools | No |
| compact js | compact-js | No |
| compact lang | compact | No |
| compact language | compact | No |
| compact compiler | compact | No |
| compactc | compact | No |
| **compact** | compact OR compact-tools | **Yes — ask user** |
| connector api | dapp-connector-api | No |
| dapp connector | dapp-connector-api | No |
| dapp examples | dapp-examples-deprecated | No |
| lace wallet | lace | No |
| lace extension | lace | No |
| midnight ledger | ledger | No |
| indexer | midnight-indexer | No |
| idx | midnight-indexer | No |
| midnight javascript | midnight-js | No |
| midnightjs | midnight-js | No |
| midnight sdk | midnight-js | No |
| mjs | midnight-js | No |
| wallet api | midnight-wallet-api | No |
| midnight node | node | No |
| runtime | onchain-runtime | No |
| on-chain runtime | onchain-runtime | No |
| prover | proof-server | No |
| proof service | proof-server | No |
| vscode extension | vs-code-extension | No |
| vs code | vs-code-extension | No |
| vscode | vs-code-extension | No |
| midnight wallet | wallet | No |
| **wallet** | wallet OR midnight-wallet-api OR lace | **Context-dependent** |

### Resolving "wallet" Ambiguity

- If context suggests backend/service → `wallet`
- If context suggests API/programmatic access → `midnight-wallet-api`
- If context suggests browser extension → `lace`
- If unclear → ask the user which component they mean

## Stale Components

| Component | Last Standalone Version | Last Release Date | Superseded By |
|-----------|------------------------|-------------------|---------------|
| proof-server | 4.0.0 | 12 May 2025 | Ledger |
| onchain-runtime | 4.0.0 | 12 May 2025 | Ledger |

Both are now developed within the Ledger repository ([midnightntwrk/midnight-ledger](https://github.com/midnightntwrk/midnight-ledger)). Their independent release notes have not been updated since version 4.0.0.

When displaying Ledger release notes as a substitute, include a note such as:

> **Note**: The proof-server is now part of Ledger. The last standalone proof-server release was 4.0.0 (12 May 2025). Showing Ledger release notes instead. If you want the standalone proof-server release notes, let me know.

## Version File Naming

| Component | Example Filename | Extracted Version |
|-----------|-----------------|-------------------|
| compact-tools | `compact-tools-0-4-0.mdx` | 0.4.0 |
| ledger | `ledger-7-0-0.mdx` | 7.0.0 |
| lace | `lace-3-0-0.mdx` | 3.0.0 |
| lace (RC) | `lace-1-0-0-RC1.mdx` | 1.0.0-RC1 |
| wallet | `wallet-5-0-0.mdx` | 5.0.0 |
| compact | `compact-0-20-28-0.mdx` | Check `title` in frontmatter |
| compact (special) | `minokawa-0-18-26-0.mdx` | Check `title` in frontmatter |

### Extraction Rules

1. Strip the component prefix and `.mdx` extension
2. Replace dashes with dots for the remaining segments
3. If the result contains `-RC`, treat it as a pre-release suffix
4. For the Compact compiler, the filename may contain compound version segments — always verify against the `title` field in the YAML frontmatter

### Sorting Versions

Sort versions using semver ordering (major, then minor, then patch). RC versions sort below their corresponding release (e.g., `1.0.0-RC1 < 1.0.0`). When determining the "latest" version, exclude RC versions unless no stable release exists.
