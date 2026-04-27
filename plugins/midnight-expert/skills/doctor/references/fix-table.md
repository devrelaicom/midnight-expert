# Fix Table

Reference for resolving issues found by midnight-expert:doctor. Each section maps diagnostic output to actionable fixes.

## Auto-Fix Classification

### Applied silently with --auto-fix
- Installing missing marketplaces and plugins
- Enabling disabled plugins
- Adding MCP servers via `claude mcp add`
- Installing missing CLI tools
- Initiating `gh auth login` (still interactive)

### Always prompts (even with --auto-fix)
- Upgrading outdated CLI tools
- Adding MCP server to local `.mcp.json` vs global
- Docker Desktop installation
- Docker daemon start on macOS
- Network/proxy configuration

## Plugin Issues

| Issue | Fix |
|-------|-----|
| midnight-expert marketplace not installed | `claude plugin install-marketplace devrelaicom/midnight-expert` |
| agent-foundry marketplace not installed | `claude plugin install-marketplace aaronbassett/agent-foundry` |
| Plugin not installed | Ensure marketplace is installed first, then `claude plugin install <name>` |
| Plugin installed but not enabled | `claude plugin enable <name>` |

## MCP Server Issues

| Issue | Fix |
|-------|-----|
| midnight not configured | `claude mcp add midnight -- npx -y github:devrelaicom/midnight-mcp` |
| octocode not configured | `claude mcp add octocode-mcp -- npx octocode-mcp` |
| midnight-devnet not configured | `claude mcp add midnight-devnet -- npx -y @aaronbassett/midnight-local-devnet` |
| MCP server not responding | Restart Claude Code to reconnect MCP servers |

For any MCP server add, also ask: "Would you prefer to add this to the local project only? I can write it to `.mcp.json` instead."

## External Tool Issues — Install

| Tool | macOS | Linux |
|------|-------|-------|
| node | `nvm install --lts` (install nvm first: https://github.com/nvm-sh/nvm) | `nvm install --lts` (install nvm first: https://github.com/nvm-sh/nvm) |
| npm/npx | Reinstall Node.js via nvm | Reinstall Node.js via nvm |
| git | `brew install git` | `apt install git` |
| gh | `brew install gh` | See https://cli.github.com/ |
| gh auth | `gh auth login` | `gh auth login` |
| docker | Install Docker Desktop: https://www.docker.com/products/docker-desktop/ | Install Docker Desktop: https://www.docker.com/products/docker-desktop/ |
| docker daemon | Start Docker Desktop application | `sudo systemctl start docker` |
| python3 | Install uv: `curl -LsSf https://astral.sh/uv/install.sh \| sh` then `uv python install` | Install uv: `curl -LsSf https://astral.sh/uv/install.sh \| sh` then `uv python install` |
| curl | `brew install curl` | `apt install curl` |
| jq (optional) | `brew install jq` | `apt install jq` |
| tsc | `npm install -g typescript` | `npm install -g typescript` |

## External Tool Issues — Outdated

Always prompt the user before upgrading, even with --auto-fix.

| Tool | macOS | Linux |
|------|-------|-------|
| node | `nvm install --lts && nvm use --lts` | `nvm install --lts && nvm use --lts` |
| git | `brew upgrade git` | `apt upgrade git` |
| gh | `brew upgrade gh` | `gh upgrade` |
| docker | Update Docker Desktop | Follow Docker docs for your distribution |
| python3 | `uv python install <latest>` | `uv python install <latest>` |
| tsc | `npm update -g typescript` | `npm update -g typescript` |

## Cross-Plugin Reference Issues

| Issue | Fix |
|-------|-----|
| Target marketplace not installed | Install the marketplace first (see Plugin Issues) |
| Target plugin not installed | Install from the correct marketplace |
| Skill/agent not found in installed plugin | Plugin may be outdated — run `claude plugin update <name>` |

## NPM Issues

| Issue | Fix |
|-------|-----|
| Registry unreachable | Check network connection and proxy settings |
| @midnight-ntwrk scope inaccessible | Check npm config — no custom registry configuration is needed for @midnight-ntwrk packages |
