# midnight-wallet

Wallet management, token operations, and test wallet workflows for Midnight Network development -- wraps the midnight-wallet-cli MCP server for balance checking, transfers, airdrop, dust registration, and multi-wallet test setups.

## Skills

### midnight-wallet:wallet-cli

Core skill for the midnight-wallet-cli MCP tools covering wallet generation, balance checking, NIGHT token transfers, airdrops on devnet, dust registration, wallet listing and selection, configuration management, and troubleshooting wallet operation errors.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| devnet-integration.md | How the wallet CLI integrates with the local devnet managed by midnight-tooling | Working with wallets on the local development network |
| mcp-tools.md | Complete reference for all 25 MCP tools exposed by the midnight-wallet-mcp server | Looking up tool names, parameters, and return values |
| transactions.md | Balance checking, token transfers, airdrops, dust registration, and error handling | Performing token operations or diagnosing transaction failures |
| troubleshooting.md | Error codes, exit codes, and diagnostic steps for wallet CLI failures | Resolving wallet operation errors |
| wallet-management.md | Wallet generation, listing, selection, inspection, and removal | Managing wallets through their lifecycle |

### midnight-wallet:setup-test-wallets

Orchestrated skill for creating, funding, and registering test wallets on the Midnight devnet. Generates wallets, airdrops NIGHT tokens, registers dust, and saves aliases in one flow. Supports batch creation of named wallets.

### midnight-wallet:wallet-aliases

Manages the wallet alias system that maps human-readable nicknames to Midnight wallet addresses. Covers the `#name` syntax, alias file locations and search order, and the wallet-aliases.sh script interface.

## Commands

### midnight-wallet:fund-mnemonic

Derive a wallet from a BIP-39 mnemonic, fund it via airdrop, and register dust in a single flow.

#### Output

Confirmation that the wallet was derived from the mnemonic, funded with NIGHT tokens, registered for dust, and saved as a wallet alias.

#### Invokes

- midnight-wallet:setup-test-wallets (skill)

## Hooks

### SessionStart

Runs a health check script at the start of each session. The script checks wallet CLI availability and devnet connectivity, reporting any issues asynchronously so they do not block session startup.

### PreToolUse

#### Devnet check (all wallet MCP tools)

Before any wallet MCP tool call, checks whether the local devnet appears to be running when the target network is "undeployed". Warns the user if the devnet is not active but does not block the tool call.

#### Nickname resolution (midnight_transfer, midnight_balance)

Before transfer or balance tool calls, inspects address arguments for wallet nicknames (e.g., "alice", "#bob") and resolves them to full addresses via the wallet-aliases.sh script. Warns if a nickname cannot be resolved.

#### Airdrop network guard (midnight_airdrop)

Before airdrop tool calls, verifies the target network is "undeployed" (local devnet). Blocks the call if the network is preprod or preview, directing the user to the public faucets instead.

#### Transfer self-check (midnight_transfer)

Before transfer tool calls, compares the recipient address to the active wallet's own address. Warns the user if the transfer would send tokens to themselves.

### PostToolUse

#### Transfer failure guidance (midnight_transfer)

After a transfer completes, inspects the result for known failure patterns. Provides specific guidance for dust-related failures (register dust first) and stale UTXO errors (retry after a short wait).
