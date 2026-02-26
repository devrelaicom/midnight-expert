# Custom Toolchain Directories

By default, the Compact CLI stores compiler versions and artifacts in `$HOME/.compact`. Override this to use a different location, most commonly a project-local `.compact/` directory for version isolation.

## The `--directory` Flag

Pass `--directory <DIR>` to any Compact CLI command:

```bash
compact --directory ./.compact update 0.25.0
compact --directory ./.compact compile src/contract.compact build/
compact --directory ./.compact list --installed
```

The directory is created automatically if it does not exist.

**Important**: The `--directory` flag must appear before the subcommand, not after.

## The `COMPACT_DIRECTORY` Environment Variable

Set `COMPACT_DIRECTORY` to avoid passing `--directory` on every command:

```bash
export COMPACT_DIRECTORY=./.compact
compact update 0.25.0     # Uses ./.compact
compact compile src/contract.compact build/  # Uses ./.compact
```

When both `--directory` and `COMPACT_DIRECTORY` are set, the flag takes precedence.

## Per-Project Configuration

When different projects need different compiler versions, configure `COMPACT_DIRECTORY` to load automatically when entering the project directory.

### direnv (Recommended for Most Developers)

[direnv](https://direnv.net/) automatically loads and unloads environment variables based on `.envrc` files when changing directories.

**Install direnv:**

```bash
# macOS
brew install direnv

# Ubuntu/Debian
sudo apt install direnv
```

**Add the shell hook** (one-time setup):

```bash
# For zsh - add to ~/.zshrc
eval "$(direnv hook zsh)"

# For bash - add to ~/.bashrc
eval "$(direnv hook bash)"
```

**Create `.envrc` in the project root:**

```bash
# .envrc
export COMPACT_DIRECTORY="${PWD}/.compact"
```

**Allow the file:**

```bash
direnv allow
```

Now `COMPACT_DIRECTORY` is automatically set to the project's `.compact/` directory whenever the shell enters the project, and unset when leaving.

### mise (Popular in Rust/Polyglot Ecosystems)

[mise](https://mise.jdx.dev/) (formerly rtx) is a polyglot tool version manager that also handles environment variables. Popular with Rust developers.

**Install mise:**

```bash
# macOS
brew install mise

# Via installer
curl https://mise.run | sh
```

**Add the shell hook** (one-time setup):

```bash
# For zsh - add to ~/.zshrc
eval "$(mise activate zsh)"

# For bash - add to ~/.bashrc
eval "$(mise activate bash)"
```

**Create `.mise.toml` in the project root:**

```toml
[env]
COMPACT_DIRECTORY = "{{config_root}}/.compact"
```

`{{config_root}}` resolves to the directory containing `.mise.toml`, making the path project-relative regardless of where commands are run from.

### dotenv-cli (Common in TypeScript/Node.js Ecosystems)

[dotenv-cli](https://www.npmjs.com/package/dotenv-cli) loads environment variables from `.env` files. Widely used in Node.js/TypeScript projects.

**Install:**

```bash
npm install -g dotenv-cli
# or
npx dotenv-cli
```

**Create `.env` in the project root:**

```env
COMPACT_DIRECTORY=./.compact
```

**Prefix commands with dotenv:**

```bash
dotenv compact compile src/contract.compact build/
```

Or add to `package.json` scripts:

```json
{
  "scripts": {
    "compile": "dotenv compact compile src/contract.compact build/",
    "format": "dotenv compact format"
  }
}
```

> **Important**: Unlike direnv and mise, dotenv-cli does **not** automatically activate when you enter a directory. Every command must be explicitly prefixed with `dotenv` or wrapped in an npm script. Without this, `COMPACT_DIRECTORY` will not be set.

### Claude Code Settings

Configure `COMPACT_DIRECTORY` in Claude Code settings so it is available in all Claude sessions for the project, without requiring direnv or any shell-level tool.

**Project-level** (shared with team via version control):

Create or edit `.claude/settings.json` in the project root:

```json
{
  "env": {
    "COMPACT_DIRECTORY": "./.compact"
  }
}
```

**Local-only** (not committed, developer-specific):

Create or edit `.claude/settings.local.json` in the project root:

```json
{
  "env": {
    "COMPACT_DIRECTORY": "./.compact"
  }
}
```

**User-level** (applies to all projects for this user):

Edit `~/.claude/settings.json`:

```json
{
  "env": {
    "COMPACT_DIRECTORY": "/path/to/custom/compact"
  }
}
```

Claude Code merges settings from all scopes. Local settings override project settings, which override user settings.

**Important**: Claude Code settings only affect commands run within Claude Code sessions. For the same behavior in a regular terminal, also configure one of the shell-level tools above.

## Choosing the Right Tool

| Tool | Auto-activates? | Ecosystem | Best For |
|------|----------------|-----------|----------|
| **direnv** | Yes (on `cd`) | Universal | Most developers; simple, reliable |
| **mise** | Yes (on `cd`) | Rust/polyglot | Developers already using mise for tool management |
| **dotenv-cli** | No (manual) | TypeScript/Node.js | Projects with existing `.env` usage and npm scripts |
| **Claude Code settings** | Yes (in Claude) | Claude Code | Ensuring Claude sessions use the right directory |

For full coverage, combine Claude Code settings with one shell-level tool:
- Use Claude Code settings so Claude sessions pick up `COMPACT_DIRECTORY`
- Use direnv or mise so regular terminal sessions also pick it up

## Setting Up a Project-Local Toolchain (Full Example)

```bash
# 1. Install compiler version into project directory
compact --directory ./.compact update 0.25.0

# 2. Create .envrc for direnv
echo 'export COMPACT_DIRECTORY="${PWD}/.compact"' > .envrc
direnv allow

# 3. Configure Claude Code settings
mkdir -p .claude
cat > .claude/settings.json << 'EOF'
{
  "env": {
    "COMPACT_DIRECTORY": "./.compact"
  }
}
EOF

# 4. Add .compact/ to .gitignore (compiler binaries should not be committed)
echo '.compact/' >> .gitignore

# 5. Verify
compact --version          # CLI version (global)
compact compile --version  # Compiler version (from ./.compact)
compact list --installed   # Shows versions in ./.compact
```
