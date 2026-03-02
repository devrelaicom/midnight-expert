# Version Mismatch Errors

Diagnose and resolve version incompatibilities across Midnight Network components.

## Fetch Documentation

Fetch the version mismatch troubleshooting guide:

```
githubGetFileContent(
  owner: "midnightntwrk",
  repo: "midnight-docs",
  path: "docs/troubleshoot/fix-version-mismatch-errors.mdx",
  fullContent: true
)
```

## Fetch Compatibility Matrix

The compatibility matrix defines which component versions work together. Check both possible locations:

```
githubGetFileContent(
  owner: "midnightntwrk",
  repo: "midnight-docs",
  path: "docs/relnotes/support-matrix.mdx",
  fullContent: true
)
```

```
githubGetFileContent(
  owner: "midnightntwrk",
  repo: "midnight-docs",
  path: "docs/relnotes/overview.mdx",
  matchString: "compatibility",
  matchStringContextLines: 50
)
```

**Conflict resolution:** If the two sources show different version numbers for the same component, use whichever matrix specifies the **higher version number for Ledger**.

## Checking Installed JavaScript Package Versions

Midnight JS packages may be **transitive dependencies** - checking only `package.json` is insufficient. Inspect lock files and use package manager commands to find the actual resolved versions.

### Detect the Package Manager

Check which lock files exist in the project:

| Lock File | Package Manager |
|---|---|
| `package-lock.json` | npm |
| `npm-shrinkwrap.json` | npm (legacy/publishable) |
| `pnpm-lock.yaml` | pnpm |
| `yarn.lock` | Yarn (v1 or v2+) |
| `.yarn/` directory | Yarn Berry (v2+) |
| `bun.lockb` or `bun.lock` | Bun |
| `common/config/rush/pnpm-lock.yaml` | Rush (pnpm-based) |

Lerna and Corepack delegate to the underlying package manager's lock file.

### List Installed Packages

Use the appropriate command for the detected package manager:

**npm:**
```bash
npm list --depth=0          # direct deps
npm list                    # full tree
npm list -g --depth=0       # global packages
```

**pnpm:**
```bash
pnpm list --depth 0         # direct deps
pnpm list                   # full tree
pnpm list -g --depth 0      # global packages
```

**Yarn v1:**
```bash
yarn list --depth=0          # direct deps
yarn list                    # full tree
yarn global list             # global packages
```

**Yarn v2+:**
```bash
yarn list --depth=0          # direct deps
yarn list                    # full tree
```

**Bun:**
```bash
bun pm ls                    # direct deps
bun pm ls --all              # full tree
```

### JSON Output (for programmatic analysis)

```bash
npm list --json              # npm - most universally supported
pnpm list --json             # pnpm - cleanest structured graph
yarn list --json             # yarn
```

pnpm gives the cleanest structured graph by default. npm's JSON output is the most universally supported.

### Check for Global Package Conflicts

Global installations can shadow or conflict with project-local versions. Always check globals:

```bash
npm list -g --depth=0 2>/dev/null | grep -i midnight
pnpm list -g --depth 0 2>/dev/null | grep -i midnight
yarn global list 2>/dev/null | grep -i midnight
```

### Search Lock Files for Midnight Packages

To find the exact resolved version of Midnight packages (including transitive deps):

```bash
# npm
grep -i "midnight" package-lock.json 2>/dev/null | head -20

# pnpm
grep -i "midnight" pnpm-lock.yaml 2>/dev/null | head -20

# yarn
grep -i "midnight" yarn.lock 2>/dev/null | head -20
```

## Resolution Steps

1. Fetch the compatibility matrix (above)
2. Identify all Midnight components in use and their current versions
3. Compare against the matrix to find mismatches
4. Update mismatched packages to compatible versions
5. Clear caches and reinstall:
   ```bash
   rm -rf node_modules
   # then reinstall with the project's package manager
   ```
6. Verify the fix by listing packages again to confirm versions match

## If Issues Persist

1. Search for version-related issues: `gh search issues "version mismatch org:midnightntwrk" --state=open --limit=20 --sort=updated --json "title,url,updatedAt,commentsCount"`
2. Check `references/checking-release-notes.md` for known compatibility issues in recent releases
3. If endpoints may also be wrong, see `references/environment-urls.md` for current URL lookup and environment diagnosis
