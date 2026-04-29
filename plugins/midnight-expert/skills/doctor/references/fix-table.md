# Fix Table

Reference for resolving issues found by midnight-expert:doctor. Each section maps diagnostic output to actionable fixes.

## Auto-Fix Classification

### Applied silently with --auto-fix
- Installing missing marketplaces
- Installing missing CLI tools
- Initiating `gh auth login` (still interactive)

### Always prompts (even with --auto-fix)
- Installing or enabling individual plugins (these are user-curated)
- Upgrading outdated CLI tools
- Adding MCP servers to local `.mcp.json` vs global
- Docker Desktop installation
- Docker daemon start on macOS
- Network/proxy configuration

## Plugin Issues

Plugin not-installed and not-enabled rows are emitted as **info** — install only the plugins you actually need.

| Issue | Fix |
|-------|-----|
| midnight-expert marketplace not installed | `claude plugin install-marketplace devrelaicom/midnight-expert` |
| agent-foundry marketplace not installed | `claude plugin install-marketplace aaronbassett/agent-foundry` |
| Plugin not installed (info) | Install with `claude plugin install <name>` if the plugin is needed for your work |
| Plugin installed but not enabled (info) | `claude plugin enable <name>` |

## MCP Server Issues

| Issue | Fix |
|-------|-----|
| octocode not configured | `claude mcp add octocode-mcp -- npx octocode-mcp` |
| MCP server not responding | Restart Claude Code to reconnect MCP servers |

For any MCP server add, also ask: "Would you prefer to add this to the local project only? I can write it to `.mcp.json` instead."

## External Tool Issues — Install

`jq` is **required** (used by several plugins for JSON parsing).

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
| jq | `brew install jq` | `apt install jq` |
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

The cross-refs check resolves three reference types: skills (`skills/<name>/SKILL.md`), agents (`agents/<name>.md`), and slash commands (`commands/<name>.md`).

| Issue | Fix |
|-------|-----|
| Target marketplace not installed | Install the marketplace first (see Plugin Issues) |
| Target plugin not installed | Install from the correct marketplace |
| Skill / agent / command not found in installed plugin | Plugin may be outdated — run `claude plugin update <name>` |
| Reference points to renamed or removed item | Source plugin's prose is stale; report to the plugin maintainer or open an issue against this repo |

## NPM Issues

| Issue | Fix |
|-------|-----|
| Registry unreachable | Check network connection and proxy settings |
| @midnight-ntwrk scope inaccessible | Check npm config — no custom registry configuration is needed for @midnight-ntwrk packages |
| `@aaronbassett/midnight-fact-checker-utils` not published | Trigger the `Publish - Fact Checker Utils` workflow on GitHub (Actions tab → Run workflow). Until published, `/midnight-fact-check:check` and `/midnight-fact-check:fast-check` cannot run. |
| `@aaronbassett/template-engine` not published | Trigger the `Publish - Template Engine` workflow on GitHub. Until published, `/compact-cli-dev:init` cannot run. |
