# Environment Tooling Issues

Resolve misconfiguration of direnv, mise, dotenv-cli, and COMPACT_DIRECTORY.

## COMPACT_DIRECTORY Overview

`COMPACT_DIRECTORY` is an environment variable that tells the Compact CLI where to find a project-local toolchain installation (compiler binaries and related files). When misconfigured, the CLI may use the wrong compiler version, fail to find the compiler, or use a global installation unexpectedly.

## direnv Issues

**Symptom:** `COMPACT_DIRECTORY` not set, or set to wrong value, when using direnv.

### Check direnv Status

```bash
direnv status
```

Look for:
- Whether `.envrc` was loaded
- Any errors or blocks

### Common Problems

1. **direnv not hooked into shell** - The shell hook must be added:
   ```bash
   # For zsh (in ~/.zshrc):
   eval "$(direnv hook zsh)"

   # For bash (in ~/.bashrc):
   eval "$(direnv hook bash)"
   ```
   After adding, **open a new terminal** (don't just source the config).

2. **`.envrc` not allowed** - direnv blocks untrusted `.envrc` files:
   ```bash
   direnv allow
   ```

3. **Wrong `.envrc` content** - Verify the file exports COMPACT_DIRECTORY correctly:
   ```bash
   cat .envrc
   ```
   Expected content (example):
   ```
   export COMPACT_DIRECTORY="$PWD/.compact"
   ```

4. **Stale cache** - Force direnv to reload:
   ```bash
   direnv reload
   ```

## mise Issues

**Symptom:** Environment variables not set when using mise (formerly rtx).

### Check mise Status

```bash
mise doctor
mise env
```

### Common Problems

1. **mise not activated** - The shell hook must be added:
   ```bash
   # For zsh (in ~/.zshrc):
   eval "$(mise activate zsh)"

   # For bash (in ~/.bashrc):
   eval "$(mise activate bash)"
   ```

2. **Wrong `.mise.toml` content** - Verify environment variable configuration:
   ```bash
   cat .mise.toml
   ```
   Expected section:
   ```toml
   [env]
   COMPACT_DIRECTORY = "{{config_root}}/.compact"
   ```

3. **Trust required** - mise may require trusting the config:
   ```bash
   mise trust
   ```

## dotenv-cli Issues

**Symptom:** Environment variables from `.env` file not available to commands.

### Common Problems

1. **Forgetting to prefix commands** - dotenv-cli requires commands to be run through it:
   ```bash
   dotenv -- compact compile
   ```
   Not just:
   ```bash
   compact compile
   ```

2. **Wrong `.env` content** - Verify the file:
   ```bash
   cat .env
   ```
   Expected:
   ```
   COMPACT_DIRECTORY=./.compact
   ```
   Note: No quotes around the value, no `export` keyword.

3. **dotenv-cli not installed** - Verify installation:
   ```bash
   npx dotenv --help
   ```

## Stale Caches After Version Switches

**Symptom:** After switching compiler versions, the old version's artifacts or behavior persist.

**Fix:**
1. Clear the project-local compact directory:
   ```bash
   rm -rf .compact
   ```
2. Clear global compiler caches:
   ```bash
   compact clean
   ```
3. Ensure environment variables reflect the intended version:
   ```bash
   echo $COMPACT_DIRECTORY
   compact --version
   ```
4. **Open a new terminal** if environment tool configurations were changed during the switch.
5. Reinstall the desired compiler version and set it as default:
   ```bash
   compact update <version>
   ```

## Claude Code Settings for COMPACT_DIRECTORY

If using Claude Code's project settings to set COMPACT_DIRECTORY, verify the configuration in `.claude/settings.json` or `.claude/settings.local.json`:

```json
{
  "env": {
    "COMPACT_DIRECTORY": "./.compact"
  }
}
```

The compact-cli skill's `references/custom-directories.md` has additional detail on per-project toolchain directory setup across all supported tools.

## If Issues Persist

1. Search for environment tooling issues: `gh search issues "direnv mise COMPACT_DIRECTORY org:midnightntwrk" --state=open --limit=20 --sort=updated --json "title,url,updatedAt,commentsCount"`
2. Check `references/checking-release-notes.md` for changes to environment variable handling in recent releases
