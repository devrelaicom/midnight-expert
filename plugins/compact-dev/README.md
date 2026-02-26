# compact-dev

Compact smart contract code generation and validation plugin for the Midnight Network.

## Overview

This plugin helps write correct, privacy-aware Compact smart contracts by combining:

- **8 specialized skills** with interconnected knowledge graphs covering every aspect of the Compact language
- **A `compact-dev` agent** that orchestrates skills and MCP tools to write and validate code
- **Midnight MCP integration** for real-time compiler validation and code search

## Skills

| Skill | Purpose |
|-------|---------|
| `compact-syntax` | Type system, expressions, control flow, pragma versioning |
| `compact-circuits` | Circuit declarations, exports, parameters, return types |
| `compact-witnesses` | Witness declarations, TypeScript implementations, type mappings |
| `compact-ledger-design` | Choosing ADTs (Cell, Counter, Map, Set, MerkleTree, etc.) |
| `compact-privacy` | Disclosure rules, commit-reveal, nullifiers, transient vs persistent |
| `compact-tokens` | Token minting, sending, receiving, Zswap operations |
| `compact-stdlib` | Standard library functions, crypto primitives, utility types |
| `compact-contract-structure` | File organization, imports, modules, naming conventions |

Each skill includes a knowledge graph in `references/knowledge-graph.json` with deeply interconnected concepts, patterns, and anti-patterns that cross-reference other skills.

## Agent

The `compact-dev` agent orchestrates all skills and MCP tools to:

1. Design contract architecture based on requirements
2. Write valid Compact code following canonical structure
3. Validate syntax using the Midnight MCP compiler
4. Generate TypeScript witness implementations
5. Check privacy patterns for correctness

## MCP Integration

The plugin includes the [Midnight MCP](https://github.com/Olanetsoft/midnight-mcp) server which provides:

- **Compiler validation** - Syntax checking and ZK circuit compilation
- **Static analysis** - 15 security checks for common issues
- **Code search** - Search across Compact examples and documentation
- **Contract analysis** - Structure extraction and deprecation detection

No API keys required - the MCP server runs in hosted mode by default.

## Installation

Add this plugin to your Claude Code configuration:

```bash
claude --plugin-dir /path/to/plugins/compact-dev
```

## Prerequisites

- Node.js 20+ (for Midnight MCP server via npx)
- Claude Code with plugin support

## Usage

The plugin activates automatically when you ask Claude to write or validate Compact code:

- "Create a Compact smart contract for..."
- "Add a circuit that..."
- "Fix this Compact code..."
- "How do I implement X in Compact?"

The `compact-dev` agent will be selected automatically for complex contract generation tasks.

## Version Compatibility

- Compact language version: `>= 0.18.0`
- Midnight MCP: latest via npx
