# ERR_UNSUPPORTED_DIR_IMPORT

Resolve the Node.js `ERR_UNSUPPORTED_DIR_IMPORT` error in Midnight projects.

## Cause

This error occurs when Node.js attempts to import a directory instead of a specific file. Common triggers:

- **Stale terminal environment** after updating `~/.zshrc`, `~/.bashrc`, or similar shell config
- **Node version switch** without opening a new terminal (e.g., after `nvm install` or `nvm alias default`)
- **Environment variable changes** that haven't taken effect in the current shell session
- **Incorrect Node version** - Midnight requires Node 22+

## Fix

### 1. Open a Fresh Terminal

Do **not** just run `source ~/.zshrc` - this does not fully reset the shell environment. Close the terminal window entirely and open a new one.

### 2. Verify the Node Version

Midnight requires Node 22 or later.

```bash
node --version
```

If a `.nvmrc` file exists in the project, use it:

```bash
nvm use
```

If the version is below 22, install and switch:

```bash
nvm install 22
nvm use 22
```

### 3. Clear Module Caches

```bash
rm -rf node_modules/.cache
```

If the issue persists, do a full reinstall:

```bash
rm -rf node_modules
# reinstall with the project's package manager (npm install / pnpm install / yarn / bun install)
```

### 4. Verify the Fix

Run the command that originally produced the error to confirm resolution.

## If the Issue Persists

- Check that no global Node.js installation is shadowing the project-local version
- Verify `NODE_PATH` is not set to a stale directory: `echo $NODE_PATH`
- Check for conflicting `.node-version` or `.nvmrc` files in parent directories
- Search for related issues: `gh search issues "ERR_UNSUPPORTED_DIR_IMPORT org:midnightntwrk" --state=open --limit=10 --sort=updated --json "title,url"`
