---
name: midnight-tooling:install-cli
description: Install, update, or configure the Compact CLI tool. Supports global installation and per-project configuration with automatic environment setup.
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
argument-hint: "[install for this project | update | --directory <path>]"
---

Install or update the Compact CLI tool, with intelligent handling of global vs. project-local installations.

## Terminology Reminder

- **Compact CLI** (`compact`): The management tool installed globally
- **Compact compiler**: The compiler managed by the CLI, stored in the artifact directory
- These are separate. Installing the CLI is separate from downloading a compiler version.

## Step 1: Parse Intent from Arguments

Analyze `$ARGUMENTS` to determine what the user wants:

**Project-local installation** if arguments contain phrases like:
- "for this project", "project only", "local", "project-local"
- "only for this project", "in this directory"
- An explicit `--directory` path

**Global installation/update** if:
- No arguments provided
- Arguments say "update", "upgrade", "install"
- No mention of "project" or "local"

## Step 2: Check Current State

```bash
which compact 2>&1
compact --version 2>&1
compact compile --version 2>&1
```

Determine whether the CLI is already installed and what versions are present.

## Step 3A: Global Installation (CLI Not Installed)

If `compact` is not found on PATH:

1. Inform the user that the Compact CLI is not installed
2. Install via the official installer:

```bash
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/midnightntwrk/compact/releases/latest/download/compact-installer.sh | sh
```

3. After installation, check if PATH needs to be updated. Read the shell profile to see if the installer added the PATH entry:

```bash
grep "compact" ~/.zshrc 2>/dev/null || grep "compact" ~/.bashrc 2>/dev/null
```

4. If the PATH entry is missing, offer to add it:

```bash
echo 'export PATH="$HOME/.compact/bin:$PATH"' >> ~/.zshrc
```

Adjust for the user's shell (check `$SHELL` to determine zsh vs bash).

5. Remind the user to reload their shell or open a new terminal.

6. Download the latest compiler:

```bash
compact update
```

7. Verify:

```bash
compact --version
compact compile --version
```

## Step 3B: Global Update (CLI Already Installed)

If `compact` is already on PATH:

1. Report current versions:
   - CLI version: `compact --version`
   - Compiler version: `compact compile --version`

2. Check for updates:

```bash
compact self check 2>&1
compact check 2>&1
```

3. Report findings:
   - If CLI update available: offer to run `compact self update`
   - If compiler update available: offer to run `compact update`
   - If both are up to date: report that everything is current

4. If updates are applied, verify the new versions.

## Step 3C: Project-Local Installation

When the user wants a project-specific toolchain:

1. Determine the target directory:
   - Default: `./.compact` (relative to project root)
   - Or use the explicit `--directory` path from arguments

2. Install the compiler into the project directory:

```bash
compact --directory ./.compact update
```

If the CLI is not installed globally, install it first (Step 3A), then proceed with the project-local setup.

3. **Configure environment automatically.** Check which environment tools are present and offer to configure them:

### Check for existing tools

```bash
# Check for direnv
which direnv 2>/dev/null
ls .envrc 2>/dev/null

# Check for mise
which mise 2>/dev/null
ls .mise.toml 2>/dev/null

# Check for dotenv
ls .env 2>/dev/null
ls package.json 2>/dev/null

# Check for Claude settings
ls .claude/settings.json 2>/dev/null
ls .claude/settings.local.json 2>/dev/null
```

### Configure detected tools

For each tool found, offer to add `COMPACT_DIRECTORY` configuration:

**direnv** (if `direnv` is on PATH or `.envrc` exists):

Check if `.envrc` already contains `COMPACT_DIRECTORY`. If not, append:

```bash
export COMPACT_DIRECTORY="${PWD}/.compact"
```

Then run `direnv allow`.

**mise** (if `mise` is on PATH or `.mise.toml` exists):

Check if `.mise.toml` already contains `COMPACT_DIRECTORY`. If not, add:

```toml
[env]
COMPACT_DIRECTORY = "{{config_root}}/.compact"
```

**Claude Code settings** (always offer):

Check if `.claude/settings.json` exists and already has `COMPACT_DIRECTORY` in the `env` field. If not, create or update the file:

```json
{
  "env": {
    "COMPACT_DIRECTORY": "./.compact"
  }
}
```

Use AskUserQuestion if the file already exists and has other settings, to confirm merging. If `.claude/settings.json` does not exist, create the `.claude/` directory and write the file.

4. **Update .gitignore:**

Check if `.gitignore` exists and contains `.compact/`. If not, offer to add it:

```
.compact/
```

Compiler binaries and proving keys should not be committed to version control.

5. **Verify the setup:**

```bash
compact --directory ./.compact list --installed
compact --directory ./.compact compile --version
```

6. **Report what was configured:**

Summarize all changes made:
- Compiler version installed in `./.compact/`
- Environment files updated (list which ones)
- `.gitignore` updated
- How to use: just run `compact compile` normally (env var handles the directory)

## Step 4: Final Summary

Present a summary of what was done:
- Installation status (new install, updated, or already current)
- CLI version
- Compiler version
- If project-local: directory and configured environment tools
- Any manual steps the user still needs to take (e.g., reload shell)
