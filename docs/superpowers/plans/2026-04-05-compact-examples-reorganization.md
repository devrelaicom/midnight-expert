# Compact Examples Plugin Reorganization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize the compact-examples plugin from a single author-based skill (`openzeppelin`) to a single routing skill (`code-examples`) with topic-based reference files and compiled examples from 8 repositories, all at `pragma language_version >= 0.22`.

**Architecture:** One skill with a SKILL.md routing table pointing to 5 reference files (`getting-started.md`, `modules.md`, `tokens.md`, `privacy-and-cryptography.md`, `applications.md`). Each reference file catalogues examples in its domain with file paths. Examples organized in `examples/` subdirectories by capability domain. All `.compact` files must pass `compact build` with full proof generation.

**Tech Stack:** Compact smart contracts, TypeScript witnesses/tests, Vitest, compact compiler v0.30.0+

**Spec:** `docs/superpowers/specs/2026-04-05-compact-examples-reorganization-design.md`

**Source repos (already cloned to `/tmp/midnight-examples/`):**
- `example-counter`, `example-bboard`, `example-zkloan`, `example-kitties`
- `midnight-contracts`, `compact-contracts`, `midnight-apps`, `midnight-rwa`

**Language version map (current → target 0.22):**
| Source | Current Version | Migration Effort |
|---|---|---|
| compact-contracts (OZ) | 0.21.0 | Low — `from` keyword rename, minor fixes |
| midnight-apps (OZ) | 0.20.0 | Low-Medium — `from` keyword, possible API changes |
| example-counter | 0.20 | Low |
| example-bboard | 0.20 | Low |
| example-zkloan | 0.21 | Low |
| example-kitties | 0.16.0 | High — 6 versions behind, expect significant changes |
| midnight-contracts | 0.16.0 | High — 6 versions behind |
| midnight-rwa | 0.18 | Medium — 4 versions behind |

**Plugin root:** `plugins/compact-examples/`

---

### Task 1: Scaffold the new directory structure and remove old skill

**Files:**
- Delete: `plugins/compact-examples/skills/openzeppelin/` (entire directory)
- Create: `plugins/compact-examples/skills/code-examples/SKILL.md`
- Create: `plugins/compact-examples/skills/code-examples/references/` (empty, populated later)
- Create: `plugins/compact-examples/skills/code-examples/examples/` (subdirectories)

- [ ] **Step 1: Create the new skill directory tree**

```bash
mkdir -p plugins/compact-examples/skills/code-examples/references
mkdir -p plugins/compact-examples/skills/code-examples/examples/getting-started/counter
mkdir -p plugins/compact-examples/skills/code-examples/examples/getting-started/bboard
mkdir -p plugins/compact-examples/skills/code-examples/examples/modules/access/witnesses
mkdir -p plugins/compact-examples/skills/code-examples/examples/modules/access/test/mocks
mkdir -p plugins/compact-examples/skills/code-examples/examples/modules/access/test/simulators
mkdir -p plugins/compact-examples/skills/code-examples/examples/modules/security/witnesses
mkdir -p plugins/compact-examples/skills/code-examples/examples/modules/security/test/mocks
mkdir -p plugins/compact-examples/skills/code-examples/examples/modules/security/test/simulators
mkdir -p plugins/compact-examples/skills/code-examples/examples/modules/token/witnesses
mkdir -p plugins/compact-examples/skills/code-examples/examples/modules/token/test/mocks
mkdir -p plugins/compact-examples/skills/code-examples/examples/modules/token/test/simulators
mkdir -p plugins/compact-examples/skills/code-examples/examples/modules/math/witnesses
mkdir -p plugins/compact-examples/skills/code-examples/examples/modules/math/test/mocks
mkdir -p plugins/compact-examples/skills/code-examples/examples/modules/crypto
mkdir -p plugins/compact-examples/skills/code-examples/examples/modules/data-structures/witnesses
mkdir -p plugins/compact-examples/skills/code-examples/examples/modules/data-structures/test/mocks
mkdir -p plugins/compact-examples/skills/code-examples/examples/modules/identity
mkdir -p plugins/compact-examples/skills/code-examples/examples/modules/utils/witnesses
mkdir -p plugins/compact-examples/skills/code-examples/examples/modules/utils/test/mocks
mkdir -p plugins/compact-examples/skills/code-examples/examples/modules/utils/test/simulators
mkdir -p plugins/compact-examples/skills/code-examples/examples/tokens/witnesses
mkdir -p plugins/compact-examples/skills/code-examples/examples/tokens/test
mkdir -p plugins/compact-examples/skills/code-examples/examples/applications/kitties
mkdir -p plugins/compact-examples/skills/code-examples/examples/applications/zkloan
mkdir -p plugins/compact-examples/skills/code-examples/examples/applications/midnight-rwa
mkdir -p plugins/compact-examples/skills/code-examples/examples/applications/tbtc
```

- [ ] **Step 2: Delete the old openzeppelin skill**

```bash
rm -rf plugins/compact-examples/skills/openzeppelin/
```

- [ ] **Step 3: Verify the directory structure**

```bash
find plugins/compact-examples/skills/ -type d | sort
```

Expected: `code-examples/` with `references/`, `examples/getting-started/`, `examples/modules/`, `examples/tokens/`, `examples/applications/` and their subdirectories. No `openzeppelin/` directory.

- [ ] **Step 4: Commit**

```bash
git add -A plugins/compact-examples/skills/
git commit -m "refactor(compact-examples): scaffold code-examples skill, remove openzeppelin skill

Replace single author-based skill with topic-based directory structure.
Old references and examples will be migrated in subsequent tasks."
```

---

### Task 2: Migrate getting-started examples (counter + bboard)

**Files:**
- Create: `plugins/compact-examples/skills/code-examples/examples/getting-started/counter/counter.compact`
- Create: `plugins/compact-examples/skills/code-examples/examples/getting-started/counter/witnesses.ts`
- Create: `plugins/compact-examples/skills/code-examples/examples/getting-started/bboard/bboard.compact`
- Create: `plugins/compact-examples/skills/code-examples/examples/getting-started/bboard/witnesses.ts`

**Source:**
- `/tmp/midnight-examples/example-counter/contract/src/counter.compact` (version 0.20)
- `/tmp/midnight-examples/example-counter/contract/src/witnesses.ts`
- `/tmp/midnight-examples/example-bboard/contract/src/bboard.compact` (version 0.20)
- `/tmp/midnight-examples/example-bboard/contract/src/witnesses.ts`

- [ ] **Step 1: Copy source files**

```bash
cp /tmp/midnight-examples/example-counter/contract/src/counter.compact \
   plugins/compact-examples/skills/code-examples/examples/getting-started/counter/
cp /tmp/midnight-examples/example-counter/contract/src/witnesses.ts \
   plugins/compact-examples/skills/code-examples/examples/getting-started/counter/
cp /tmp/midnight-examples/example-bboard/contract/src/bboard.compact \
   plugins/compact-examples/skills/code-examples/examples/getting-started/bboard/
cp /tmp/midnight-examples/example-bboard/contract/src/witnesses.ts \
   plugins/compact-examples/skills/code-examples/examples/getting-started/bboard/
```

- [ ] **Step 2: Update pragma in counter.compact**

Change `pragma language_version >= 0.20;` to `pragma language_version >= 0.22;`

- [ ] **Step 3: Update pragma in bboard.compact**

Change `pragma language_version >= 0.20;` to `pragma language_version >= 0.22;`

- [ ] **Step 4: Compile counter.compact with full proof generation**

```bash
cd plugins/compact-examples/skills/code-examples/examples/getting-started/counter
compact build counter.compact
```

Expected: Successful compilation with proof keys generated. If it fails, fix the errors (likely minor syntax changes between 0.20 and 0.22) and re-run.

- [ ] **Step 5: Compile bboard.compact with full proof generation**

```bash
cd plugins/compact-examples/skills/code-examples/examples/getting-started/bboard
compact build bboard.compact
```

Expected: Successful compilation with proof keys generated. Fix any errors and re-run.

- [ ] **Step 6: Clean up build artifacts**

Remove any `build/` or output directories created by `compact build` — we only keep source files in the plugin.

```bash
rm -rf plugins/compact-examples/skills/code-examples/examples/getting-started/counter/build
rm -rf plugins/compact-examples/skills/code-examples/examples/getting-started/bboard/build
```

- [ ] **Step 7: Commit**

```bash
git add plugins/compact-examples/skills/code-examples/examples/getting-started/
git commit -m "feat(compact-examples): add getting-started examples (counter, bboard)

Migrated from midnightntwrk/example-counter and midnightntwrk/example-bboard.
Updated to pragma language_version >= 0.22. Both compile with full proof generation."
```

---

### Task 3: Migrate modules/access (Ownable, ZOwnablePK, AccessControl)

**Files:**
- Create: `examples/modules/access/Ownable.compact`
- Create: `examples/modules/access/ZOwnablePK.compact`
- Create: `examples/modules/access/AccessControl.compact`
- Create: `examples/modules/access/witnesses/OwnableWitnesses.ts`
- Create: `examples/modules/access/witnesses/ZOwnablePKWitnesses.ts`
- Create: `examples/modules/access/witnesses/AccessControlWitnesses.ts`
- Create: `examples/modules/access/test/Ownable.test.ts`
- Create: `examples/modules/access/test/ZOwnablePK.test.ts`
- Create: `examples/modules/access/test/AccessControl.test.ts`
- Create: `examples/modules/access/test/mocks/MockOwnable.compact`
- Create: `examples/modules/access/test/mocks/MockZOwnablePK.compact`
- Create: `examples/modules/access/test/mocks/MockAccessControl.compact`
- Create: `examples/modules/access/test/simulators/OwnableSimulator.ts`
- Create: `examples/modules/access/test/simulators/ZOwnablePKSimulator.ts`
- Create: `examples/modules/access/test/simulators/AccessControlSimulator.ts`

All paths below are relative to `plugins/compact-examples/skills/code-examples/`.

**Source:** `/tmp/midnight-examples/compact-contracts/contracts/src/access/` (version 0.21.0)

- [ ] **Step 1: Copy all access module source files**

```bash
SRC=/tmp/midnight-examples/compact-contracts/contracts/src/access
DEST=plugins/compact-examples/skills/code-examples/examples/modules/access

cp $SRC/Ownable.compact $DEST/
cp $SRC/ZOwnablePK.compact $DEST/
cp $SRC/AccessControl.compact $DEST/
cp $SRC/witnesses/OwnableWitnesses.ts $DEST/witnesses/
cp $SRC/witnesses/ZOwnablePKWitnesses.ts $DEST/witnesses/
cp $SRC/witnesses/AccessControlWitnesses.ts $DEST/witnesses/
cp $SRC/test/Ownable.test.ts $DEST/test/
cp $SRC/test/ZOwnablePK.test.ts $DEST/test/
cp $SRC/test/AccessControl.test.ts $DEST/test/
cp $SRC/test/mocks/MockOwnable.compact $DEST/test/mocks/
cp $SRC/test/mocks/MockZOwnablePK.compact $DEST/test/mocks/
cp $SRC/test/mocks/MockAccessControl.compact $DEST/test/mocks/
cp $SRC/test/simulators/OwnableSimulator.ts $DEST/test/simulators/
cp $SRC/test/simulators/ZOwnablePKSimulator.ts $DEST/test/simulators/
cp $SRC/test/simulators/AccessControlSimulator.ts $DEST/test/simulators/
```

- [ ] **Step 2: Update pragma to >= 0.22 in all .compact files**

Update `pragma language_version >= 0.21.0;` to `pragma language_version >= 0.22;` in:
- `Ownable.compact`
- `ZOwnablePK.compact`
- `AccessControl.compact`
- `test/mocks/MockOwnable.compact`
- `test/mocks/MockZOwnablePK.compact`
- `test/mocks/MockAccessControl.compact`

- [ ] **Step 3: Fix `from` keyword usage**

In 0.22+, `from` is a reserved keyword. Search all `.compact` files for parameters named `from` and rename to `fromAddress`. Also update any witnesses or tests that reference the old parameter name.

```bash
grep -rn "\bfrom\b" plugins/compact-examples/skills/code-examples/examples/modules/access/ --include="*.compact"
```

- [ ] **Step 4: Compile each mock contract with full proof generation**

Modules cannot be compiled standalone — they must be compiled via a contract that imports them. Compile each mock contract (which imports and uses its corresponding module):

```bash
cd plugins/compact-examples/skills/code-examples/examples/modules/access/test/mocks
compact build MockOwnable.compact
compact build MockZOwnablePK.compact
compact build MockAccessControl.compact
```

Fix any compilation errors. The mock contracts import the module files, so successful mock compilation proves both the module and mock are valid.

**Note:** Import paths in the mock `.compact` files reference relative paths to the module files. These paths may need updating since the files have been moved from their original repo structure. Check and fix import paths before compiling.

- [ ] **Step 5: Clean up build artifacts**

```bash
find plugins/compact-examples/skills/code-examples/examples/modules/access/ -name "build" -type d -exec rm -rf {} +
```

- [ ] **Step 6: Commit**

```bash
git add plugins/compact-examples/skills/code-examples/examples/modules/access/
git commit -m "feat(compact-examples): add access control modules (Ownable, ZOwnablePK, AccessControl)

Migrated from OpenZeppelin/compact-contracts. Updated to pragma >= 0.22.
Includes witnesses, tests, mocks, and simulators. All mocks compile with full proof generation."
```

---

### Task 4: Migrate modules/security (Initializable, Pausable)

**Files:** Same structure as Task 3 but for security modules.

**Source:** `/tmp/midnight-examples/compact-contracts/contracts/src/security/` (version 0.21.0)

- [ ] **Step 1: Copy all security module source files**

```bash
SRC=/tmp/midnight-examples/compact-contracts/contracts/src/security
DEST=plugins/compact-examples/skills/code-examples/examples/modules/security

cp $SRC/Initializable.compact $DEST/
cp $SRC/Pausable.compact $DEST/
cp $SRC/witnesses/InitializableWitnesses.ts $DEST/witnesses/
cp $SRC/witnesses/PausableWitnesses.ts $DEST/witnesses/
cp $SRC/test/Initializable.test.ts $DEST/test/
cp $SRC/test/Pausable.test.ts $DEST/test/
cp $SRC/test/mocks/MockInitializable.compact $DEST/test/mocks/
cp $SRC/test/mocks/MockPausable.compact $DEST/test/mocks/
cp $SRC/test/simulators/InitializableSimulator.ts $DEST/test/simulators/
cp $SRC/test/simulators/PausableSimulator.ts $DEST/test/simulators/
```

- [ ] **Step 2: Update pragma to >= 0.22 in all .compact files**

Update in: `Initializable.compact`, `Pausable.compact`, `test/mocks/MockInitializable.compact`, `test/mocks/MockPausable.compact`

- [ ] **Step 3: Fix `from` keyword and any other 0.22 breaking changes**

- [ ] **Step 4: Fix import paths in mock contracts**

Mock contracts reference relative paths to their module files. Update paths to match the new directory structure.

- [ ] **Step 5: Compile mock contracts with full proof generation**

```bash
cd plugins/compact-examples/skills/code-examples/examples/modules/security/test/mocks
compact build MockInitializable.compact
compact build MockPausable.compact
```

- [ ] **Step 6: Clean up build artifacts**

- [ ] **Step 7: Commit**

```bash
git add plugins/compact-examples/skills/code-examples/examples/modules/security/
git commit -m "feat(compact-examples): add security modules (Initializable, Pausable)

Migrated from OpenZeppelin/compact-contracts. Updated to pragma >= 0.22.
All mocks compile with full proof generation."
```

---

### Task 5: Migrate modules/token (FungibleToken, NonFungibleToken, MultiToken)

**Files:** Same structure as Task 3 but for OZ token modules.

**Source:** `/tmp/midnight-examples/compact-contracts/contracts/src/token/` (version 0.21.0)

- [ ] **Step 1: Copy all OZ token module source files**

```bash
SRC=/tmp/midnight-examples/compact-contracts/contracts/src/token
DEST=plugins/compact-examples/skills/code-examples/examples/modules/token

cp $SRC/FungibleToken.compact $DEST/
cp $SRC/NonFungibleToken.compact $DEST/
cp $SRC/MultiToken.compact $DEST/
cp $SRC/witnesses/FungibleTokenWitnesses.ts $DEST/witnesses/
cp $SRC/witnesses/NonFungibleTokenWitnesses.ts $DEST/witnesses/
cp $SRC/witnesses/MultiTokenWitnesses.ts $DEST/witnesses/
cp $SRC/test/FungibleToken.test.ts $DEST/test/
cp $SRC/test/NonFungibleToken.test.ts $DEST/test/
cp $SRC/test/nonFungibleToken.test.ts $DEST/test/ 2>/dev/null
cp $SRC/test/MultiToken.test.ts $DEST/test/
cp $SRC/test/mocks/MockFungibleToken.compact $DEST/test/mocks/
cp $SRC/test/mocks/MockNonFungibleToken.compact $DEST/test/mocks/
cp $SRC/test/mocks/MockMultiToken.compact $DEST/test/mocks/
cp $SRC/test/simulators/FungibleTokenSimulator.ts $DEST/test/simulators/
cp $SRC/test/simulators/NonFungibleTokenSimulator.ts $DEST/test/simulators/
cp $SRC/test/simulators/MultiTokenSimulator.ts $DEST/test/simulators/
```

- [ ] **Step 2: Copy Nft and NftZk modules from midnight-contracts**

```bash
SRC_NFT=/tmp/midnight-examples/midnight-contracts/contracts/tokens/nft/src
SRC_NFTZK=/tmp/midnight-examples/midnight-contracts/contracts/tokens/nft-zk/src

cp $SRC_NFT/modules/Nft.compact $DEST/Nft.compact
cp $SRC_NFTZK/modules/NftZk.compact $DEST/NftZk.compact
cp $SRC_NFT/witnesses.ts $DEST/witnesses/NftWitnesses.ts
cp $SRC_NFTZK/witnesses.ts $DEST/witnesses/NftZkWitnesses.ts
```

- [ ] **Step 3: Update pragma to >= 0.22 in all .compact files**

This includes the OZ files (from 0.21.0) and the Nft/NftZk modules (no pragma — add `pragma language_version >= 0.22;` at the top of `Nft.compact` and `NftZk.compact` since they are module files that may be compiled via importing contracts).

- [ ] **Step 4: Fix `from` keyword and any other 0.22 breaking changes**

Token contracts are the most likely to use `from` as a parameter name (e.g., `transferFrom`). Search and replace:

```bash
grep -rn "\bfrom\b" plugins/compact-examples/skills/code-examples/examples/modules/token/ --include="*.compact" --include="*.ts"
```

Rename `from` → `fromAddress` in `.compact` files and update any corresponding TypeScript references.

- [ ] **Step 5: Fix import paths in mock contracts and module files**

The Nft/NftZk modules were originally imported from different relative paths. The mock contracts for OZ tokens also need path updates.

- [ ] **Step 6: Compile all mock contracts with full proof generation**

```bash
cd plugins/compact-examples/skills/code-examples/examples/modules/token/test/mocks
compact build MockFungibleToken.compact
compact build MockNonFungibleToken.compact
compact build MockMultiToken.compact
```

Note: Nft and NftZk are module files without their own mocks in the source repo. They will be compiled when used by the token contracts in Task 8 (`nft.compact`, `nft-zk.compact`).

- [ ] **Step 7: Clean up build artifacts**

- [ ] **Step 8: Commit**

```bash
git add plugins/compact-examples/skills/code-examples/examples/modules/token/
git commit -m "feat(compact-examples): add token modules (FungibleToken, NFT, MultiToken, Nft, NftZk)

OZ modules from OpenZeppelin/compact-contracts (0.21 → 0.22).
Nft/NftZk from riusricardo/midnight-contracts (0.16 → 0.22).
All OZ mocks compile with full proof generation."
```

---

### Task 6: Migrate modules/math (Uint64, Uint128, Uint256, Bytes8, Bytes32, Field255, Pack, Types)

**Files:**
- Create: `examples/modules/math/Uint64.compact`, `Uint128.compact`, `Uint256.compact`, `Bytes8.compact`, `Bytes32.compact`, `Field255.compact`, `Pack.compact`, `Types.compact`
- Create: corresponding witnesses and test files from midnight-apps

**Source:** `/tmp/midnight-examples/midnight-apps/contracts/src/math/` (version 0.20.0)

- [ ] **Step 1: Copy all math module source files**

```bash
SRC=/tmp/midnight-examples/midnight-apps/contracts/src/math
DEST=plugins/compact-examples/skills/code-examples/examples/modules/math

cp $SRC/Uint64.compact $DEST/
cp $SRC/Uint128.compact $DEST/
cp $SRC/Uint256.compact $DEST/
cp $SRC/Bytes8.compact $DEST/
cp $SRC/Bytes32.compact $DEST/
cp $SRC/Field255.compact $DEST/
cp $SRC/Pack.compact $DEST/
cp $SRC/Types.compact $DEST/
```

- [ ] **Step 2: Copy math witnesses if they exist**

```bash
ls /tmp/midnight-examples/midnight-apps/contracts/src/math/witnesses/
```

Copy any witness files found to `$DEST/witnesses/`.

- [ ] **Step 3: Copy math test files**

```bash
# Copy mock contracts
for f in /tmp/midnight-examples/midnight-apps/contracts/src/math/test/mocks/contracts/*.compact; do
  cp "$f" $DEST/test/mocks/
done

# Copy test files
for f in /tmp/midnight-examples/midnight-apps/contracts/src/math/test/*.test.ts; do
  cp "$f" $DEST/test/
done
```

- [ ] **Step 4: Update pragma to >= 0.22 in all .compact files**

All math files are at 0.20.0. Update all `.compact` files in `$DEST/` and `$DEST/test/mocks/`.

- [ ] **Step 5: Fix any 0.22 breaking changes**

Math modules use parametric types and complex arithmetic. Check for:
- `from` keyword conflicts
- Any stdlib function signature changes between 0.20 and 0.22
- Changes to type casting syntax

- [ ] **Step 6: Fix import paths in mock contracts**

- [ ] **Step 7: Compile mock contracts with full proof generation**

```bash
cd plugins/compact-examples/skills/code-examples/examples/modules/math/test/mocks
compact build Uint64.mock.compact
compact build Uint128.mock.compact
compact build Uint256.mock.compact
compact build Bytes8.mock.compact
compact build Bytes32.mock.compact
compact build Field255.mock.compact
compact build Pack.mock.compact
```

These are large modules. Full proof generation may take significant time per file. If a module fails compilation, diagnose and fix before proceeding.

- [ ] **Step 8: Clean up build artifacts**

- [ ] **Step 9: Commit**

```bash
git add plugins/compact-examples/skills/code-examples/examples/modules/math/
git commit -m "feat(compact-examples): add math modules (Uint64/128/256, Bytes8/32, Field255, Pack, Types)

Migrated from OpenZeppelin/midnight-apps. Updated from 0.20 to pragma >= 0.22.
All mock contracts compile with full proof generation."
```

---

### Task 7: Migrate modules/crypto, data-structures, identity, utils

**Source files:**
- crypto: `/tmp/midnight-examples/example-zkloan/contract/src/schnorr.compact` (0.21, no pragma), `/tmp/midnight-examples/midnight-rwa/rwa-contract/src/crypto.compact` (0.18)
- data-structures: `/tmp/midnight-examples/midnight-apps/contracts/src/structs/Queue.compact` (0.20.0) + test/mocks
- identity: `/tmp/midnight-examples/midnight-rwa/rwa-contract/src/passportidentity.compact` (0.18)
- utils: `/tmp/midnight-examples/compact-contracts/contracts/src/utils/` (0.21.0), `/tmp/midnight-examples/midnight-apps/contracts/src/shielded-token/openzeppelin/Utils.compact` (0.20.0)

- [ ] **Step 1: Copy crypto modules**

```bash
DEST=plugins/compact-examples/skills/code-examples/examples/modules

cp /tmp/midnight-examples/example-zkloan/contract/src/schnorr.compact $DEST/crypto/schnorr.compact
cp /tmp/midnight-examples/midnight-rwa/rwa-contract/src/crypto.compact $DEST/crypto/crypto.compact
```

- [ ] **Step 2: Copy data-structures module**

```bash
cp /tmp/midnight-examples/midnight-apps/contracts/src/structs/Queue.compact $DEST/data-structures/Queue.compact

# Copy witnesses if they exist
ls /tmp/midnight-examples/midnight-apps/contracts/src/structs/witnesses/ 2>/dev/null && \
  cp /tmp/midnight-examples/midnight-apps/contracts/src/structs/witnesses/* $DEST/data-structures/witnesses/

# Copy mock
cp /tmp/midnight-examples/midnight-apps/contracts/src/structs/test/mocks/contracts/Queue.mock.compact \
   $DEST/data-structures/test/mocks/
```

- [ ] **Step 3: Copy identity module**

```bash
cp /tmp/midnight-examples/midnight-rwa/rwa-contract/src/passportidentity.compact $DEST/identity/passportidentity.compact
```

- [ ] **Step 4: Copy utils modules**

```bash
# OZ Utils
cp /tmp/midnight-examples/compact-contracts/contracts/src/utils/Utils.compact $DEST/utils/Utils.compact
cp /tmp/midnight-examples/compact-contracts/contracts/src/utils/witnesses/UtilsWitnesses.ts $DEST/utils/witnesses/
cp /tmp/midnight-examples/compact-contracts/contracts/src/utils/test/utils.test.ts $DEST/utils/test/
cp /tmp/midnight-examples/compact-contracts/contracts/src/utils/test/mocks/MockUtils.compact $DEST/utils/test/mocks/
cp /tmp/midnight-examples/compact-contracts/contracts/src/utils/test/simulators/UtilsSimulator.ts $DEST/utils/test/simulators/

# Shielded Utils (rename to avoid collision)
cp /tmp/midnight-examples/midnight-apps/contracts/src/shielded-token/openzeppelin/Utils.compact \
   $DEST/utils/ShieldedUtils.compact
```

- [ ] **Step 5: Update pragma to >= 0.22 in ALL copied .compact files**

Files span versions 0.18 to 0.21. Update every `.compact` file in:
- `$DEST/crypto/`
- `$DEST/data-structures/` and `$DEST/data-structures/test/mocks/`
- `$DEST/identity/`
- `$DEST/utils/` and `$DEST/utils/test/mocks/`

For `schnorr.compact` (no pragma): add `pragma language_version >= 0.22;` at the top.

- [ ] **Step 6: Fix 0.22 breaking changes**

The crypto and identity modules from midnight-rwa (0.18) are 4 versions behind. Expect:
- `from` keyword conflicts
- Possible changes to EC operations or hash function signatures
- Type casting syntax changes
- Potential stdlib function renames

The schnorr module from zkloan has no pragma and may use syntax not supported in 0.22.

Read each file carefully and fix compilation errors iteratively.

- [ ] **Step 7: Fix import paths**

Modules that import other modules (e.g., crypto.compact imports passportidentity) need path updates. Queue mock imports Queue. MockUtils imports Utils.

- [ ] **Step 8: Compile all compilable files with full proof generation**

Modules (schnorr, crypto, passportidentity, Queue, Utils, ShieldedUtils) cannot be compiled directly — only contracts can. Compile via their mock contracts where available:

```bash
# Queue mock
cd plugins/compact-examples/skills/code-examples/examples/modules/data-structures/test/mocks
compact build Queue.mock.compact

# Utils mock
cd plugins/compact-examples/skills/code-examples/examples/modules/utils/test/mocks
compact build MockUtils.compact
```

For modules without mocks (crypto, schnorr, identity, ShieldedUtils): these will be validated when the application contracts that import them are compiled in Tasks 8 and 9.

- [ ] **Step 9: Clean up build artifacts**

- [ ] **Step 10: Commit**

```bash
git add plugins/compact-examples/skills/code-examples/examples/modules/crypto/ \
       plugins/compact-examples/skills/code-examples/examples/modules/data-structures/ \
       plugins/compact-examples/skills/code-examples/examples/modules/identity/ \
       plugins/compact-examples/skills/code-examples/examples/modules/utils/
git commit -m "feat(compact-examples): add crypto, data-structures, identity, and utils modules

crypto: Schnorr (zkloan, 0.21→0.22) + EC ops (midnight-rwa, 0.18→0.22)
data-structures: Queue (midnight-apps, 0.20→0.22)
identity: PassportIdentity (midnight-rwa, 0.18→0.22)
utils: Utils (OZ, 0.21→0.22) + ShieldedUtils (midnight-apps, 0.20→0.22)"
```

---

### Task 8: Migrate tokens (composed token contracts)

**Files:**
- Create: `examples/tokens/AccessControlledToken.compact`
- Create: `examples/tokens/FungibleTokenMintablePausableOwnable.compact`
- Create: `examples/tokens/SimpleNonFungibleToken.compact`
- Create: `examples/tokens/MultiTokenTwoTypes.compact`
- Create: `examples/tokens/ShieldedFungibleToken.compact`
- Create: `examples/tokens/ShieldedERC20.compact`
- Create: `examples/tokens/nft.compact`
- Create: `examples/tokens/nft-zk.compact`
- Create: `examples/tokens/tbtc.compact`
- Create: corresponding witnesses in `examples/tokens/witnesses/`

**Sources:**
- OZ composed examples: `/tmp/midnight-examples/compact-contracts/packages/simulator/test/fixtures/sample-contracts/` and various locations in the compact-contracts repo
- nft.compact: `/tmp/midnight-examples/midnight-contracts/contracts/tokens/nft/src/nft.compact` (0.16.0)
- nft-zk.compact: `/tmp/midnight-examples/midnight-contracts/contracts/tokens/nft-zk/src/nft-zk.compact` (0.16.0)
- ShieldedFungibleToken: `/tmp/midnight-examples/midnight-apps/contracts/src/shielded-token/ShieldedFungibleToken.compact` (0.20.0)
- ShieldedERC20: `/tmp/midnight-examples/midnight-apps/contracts/src/shielded-token/openzeppelin/ShieldedERC20.compact` (0.20.0)
- tbtc: `/tmp/midnight-examples/midnight-rwa/tbtc-contract/src/tbtc.compact` (0.18)

**Note:** The OZ composed examples (AccessControlledToken, FungibleTokenMintablePausableOwnable, SimpleNonFungibleToken, MultiTokenTwoTypes) were previously in `skills/openzeppelin/examples/`. They were deleted in Task 1. Retrieve them from the compact-contracts repo or from git history.

- [ ] **Step 1: Locate and copy OZ composed example contracts**

Check where these files exist in the compact-contracts repo:

```bash
find /tmp/midnight-examples/compact-contracts/ -name "AccessControlledToken.compact" -o -name "FungibleTokenMintablePausableOwnable.compact" -o -name "SimpleNonFungibleToken.compact" -o -name "MultiTokenTwoTypes.compact" 2>/dev/null
```

If not found in the cloned repo, retrieve from git history:

```bash
git show HEAD:plugins/compact-examples/skills/openzeppelin/examples/AccessControlledToken.compact
```

Copy each file to `plugins/compact-examples/skills/code-examples/examples/tokens/`.

- [ ] **Step 2: Copy non-OZ token contracts**

```bash
DEST=plugins/compact-examples/skills/code-examples/examples/tokens

cp /tmp/midnight-examples/midnight-contracts/contracts/tokens/nft/src/nft.compact $DEST/
cp /tmp/midnight-examples/midnight-contracts/contracts/tokens/nft-zk/src/nft-zk.compact $DEST/
cp /tmp/midnight-examples/midnight-apps/contracts/src/shielded-token/ShieldedFungibleToken.compact $DEST/
cp /tmp/midnight-examples/midnight-apps/contracts/src/shielded-token/openzeppelin/ShieldedERC20.compact $DEST/
cp /tmp/midnight-examples/midnight-rwa/tbtc-contract/src/tbtc.compact $DEST/
```

- [ ] **Step 3: Copy token witnesses**

```bash
DEST=plugins/compact-examples/skills/code-examples/examples/tokens/witnesses

cp /tmp/midnight-examples/midnight-contracts/contracts/tokens/nft/src/witnesses.ts $DEST/nft-witnesses.ts
cp /tmp/midnight-examples/midnight-contracts/contracts/tokens/nft-zk/src/witnesses.ts $DEST/nft-zk-witnesses.ts
```

- [ ] **Step 4: Update pragma to >= 0.22 in all token .compact files**

Versions range from 0.16.0 (nft, nft-zk) to 0.21.0 (OZ examples). Update all.

- [ ] **Step 5: Fix import paths**

Token contracts import modules. Update all import paths to point to the modules in `../modules/` or to wherever the modules are accessible from the token directory. This is the most complex path-fixing task because:
- OZ tokens import OZ modules via `node_modules` paths
- nft.compact imports `./modules/Nft`
- ShieldedFungibleToken imports ShieldedERC20

Decide: either update import paths to relative references within the plugin, or document that these are standalone example files that show the contract source code (agents copy and adapt, not import directly).

**Recommended approach:** Update imports to use relative paths within the plugin directory structure. For example:
```compact
import "../../modules/access/Ownable" prefix Ownable_;
```

- [ ] **Step 6: Fix all 0.22 breaking changes**

The 0.16.0 files (nft, nft-zk) will likely need significant changes. Common issues:
- `from` keyword reservation
- Changed type syntax
- Removed or renamed stdlib functions
- New disclosure requirements

- [ ] **Step 7: Compile every token contract with full proof generation**

```bash
cd plugins/compact-examples/skills/code-examples/examples/tokens
compact build AccessControlledToken.compact
compact build FungibleTokenMintablePausableOwnable.compact
compact build SimpleNonFungibleToken.compact
compact build MultiTokenTwoTypes.compact
compact build ShieldedFungibleToken.compact
compact build nft.compact
compact build nft-zk.compact
compact build tbtc.compact
```

Note: ShieldedERC20 is a module, not a contract — it will be compiled via ShieldedFungibleToken which imports it.

Fix errors iteratively. The 0.16 → 0.22 migration for nft/nft-zk may require substantial rewriting.

- [ ] **Step 8: Clean up build artifacts**

- [ ] **Step 9: Commit**

```bash
git add plugins/compact-examples/skills/code-examples/examples/tokens/
git commit -m "feat(compact-examples): add composed token contracts

9 token contracts from 4 repos, all updated to pragma >= 0.22.
Includes: OZ composed examples, Nft, NftZk, ShieldedFungibleToken,
ShieldedERC20, tBTC. All compile with full proof generation."
```

---

### Task 9: Migrate applications (kitties, zkloan, midnight-rwa, tbtc)

**Files:**
- Create: `examples/applications/kitties/kitties.compact` + `witnesses.ts`
- Create: `examples/applications/zkloan/schnorr.compact` + `zkloan-credit-scorer.compact` + `witnesses.ts`
- Create: `examples/applications/midnight-rwa/midnight-rwa.compact` + `passportidentity.compact` + `crypto.compact` + `witnesses.ts`
- Create: `examples/applications/tbtc/tbtc.compact`

**Sources:**
- kitties: `/tmp/midnight-examples/example-kitties/packages/contracts/kitties/src/` (0.16.0 — highest migration effort)
- zkloan: `/tmp/midnight-examples/example-zkloan/contract/src/` (0.21)
- midnight-rwa: `/tmp/midnight-examples/midnight-rwa/rwa-contract/src/` (0.18)
- tbtc: `/tmp/midnight-examples/midnight-rwa/tbtc-contract/src/` (0.18)

- [ ] **Step 1: Copy kitties application**

```bash
DEST=plugins/compact-examples/skills/code-examples/examples/applications/kitties
cp /tmp/midnight-examples/example-kitties/packages/contracts/kitties/src/kitties.compact $DEST/
cp /tmp/midnight-examples/example-kitties/packages/contracts/kitties/src/witnesses.ts $DEST/
```

- [ ] **Step 2: Copy zkloan application**

```bash
DEST=plugins/compact-examples/skills/code-examples/examples/applications/zkloan
cp /tmp/midnight-examples/example-zkloan/contract/src/schnorr.compact $DEST/
cp /tmp/midnight-examples/example-zkloan/contract/src/zkloan-credit-scorer.compact $DEST/
cp /tmp/midnight-examples/example-zkloan/contract/src/witnesses.ts $DEST/
```

- [ ] **Step 3: Copy midnight-rwa application**

```bash
DEST=plugins/compact-examples/skills/code-examples/examples/applications/midnight-rwa
cp /tmp/midnight-examples/midnight-rwa/rwa-contract/src/midnight-rwa.compact $DEST/
cp /tmp/midnight-examples/midnight-rwa/rwa-contract/src/passportidentity.compact $DEST/
cp /tmp/midnight-examples/midnight-rwa/rwa-contract/src/crypto.compact $DEST/
cp /tmp/midnight-examples/midnight-rwa/rwa-contract/src/witnesses.ts $DEST/
```

- [ ] **Step 4: Copy tbtc application**

```bash
DEST=plugins/compact-examples/skills/code-examples/examples/applications/tbtc
cp /tmp/midnight-examples/midnight-rwa/tbtc-contract/src/tbtc.compact $DEST/
```

- [ ] **Step 5: Update pragma to >= 0.22 in all .compact files**

- kitties: 0.16.0 → 0.22 (6 version jump — expect major changes)
- zkloan: 0.21 → 0.22 (add `>=` prefix if missing)
- midnight-rwa: 0.18 → 0.22 (4 version jump)
- tbtc: 0.18 → 0.22

- [ ] **Step 6: Fix import paths within each application**

Each application is self-contained. Internal imports (e.g., zkloan-credit-scorer imports schnorr) should use relative paths within the application directory:

```compact
// In zkloan-credit-scorer.compact
import "./schnorr" prefix Schnorr_;
```

- [ ] **Step 7: Fix all 0.22 breaking changes — kitties (HIGH EFFORT)**

kitties.compact is at 0.16.0 — the oldest code. Expect:
- Major syntax changes across 6 language versions
- Likely changes to Map/Set/Counter APIs
- `from` keyword reservation
- Possible changes to struct syntax, enum syntax, or type casting
- New disclosure requirements

Read the full file, compare against 0.22 syntax, and fix systematically.

- [ ] **Step 8: Fix all 0.22 breaking changes — midnight-rwa (MEDIUM EFFORT)**

midnight-rwa at 0.18 with complex Merkle tree operations and identity verification. Expect:
- EC operation API changes
- Hash function changes
- Disclosure rule changes

- [ ] **Step 9: Fix all 0.22 breaking changes — zkloan (LOW EFFORT)**

zkloan at 0.21 is close to 0.22. Likely just `from` keyword and minor fixes.

- [ ] **Step 10: Compile every application contract with full proof generation**

```bash
cd plugins/compact-examples/skills/code-examples/examples/applications/kitties
compact build kitties.compact

cd ../zkloan
compact build zkloan-credit-scorer.compact

cd ../midnight-rwa
compact build midnight-rwa.compact

cd ../tbtc
compact build tbtc.compact
```

Fix errors iteratively. The kitties and midnight-rwa compilations may require multiple rounds of fixes.

- [ ] **Step 11: Clean up build artifacts**

- [ ] **Step 12: Commit**

```bash
git add plugins/compact-examples/skills/code-examples/examples/applications/
git commit -m "feat(compact-examples): add application examples (kitties, zkloan, midnight-rwa, tbtc)

Full multi-module apps from 3 repos, all updated to pragma >= 0.22.
kitties (0.16→0.22), zkloan (0.21→0.22), midnight-rwa (0.18→0.22),
tbtc (0.18→0.22). All compile with full proof generation."
```

---

### Task 10: Write SKILL.md routing file

**Files:**
- Create: `plugins/compact-examples/skills/code-examples/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

```markdown
---
version: 0.2.0
name: compact-examples:code-examples
description: Use this skill when an agent needs real, compilable examples of Compact smart contracts, TypeScript witnesses, or tests. Covers beginner contracts (counter, bulletin board), reusable modules (access control, security, tokens, math, crypto, data structures, identity, utils), composed token contracts (fungible, NFT, multi-token, shielded), and full applications (CryptoKitties, ZK lending, real-world assets). All examples compile with pragma language_version >= 0.22 and full proof generation.
---

# Compact Code Examples

Compilable Compact smart contracts, TypeScript witnesses, and tests sourced from 8 repositories. All code uses `pragma language_version >= 0.22` and passes `compact build` with full proof generation.

## How to use this skill

1. Find your topic in the routing table below
2. Read the reference file — it catalogues every example with file paths and descriptions
3. Read only the specific `.compact` and witness files you need

Do NOT load all examples into context. Use the reference files to pick precisely what you need.

## Routing Table

| Topic | Reference | When to use |
|---|---|---|
| Beginner examples | references/getting-started.md | Simple contracts, learning basics, minimal state management |
| Reusable modules | references/modules.md | Access control, math, crypto, data structures, utils — building blocks you import |
| Token contracts | references/tokens.md | Fungible, NFT, multi-token, shielded tokens — complete deployable contracts |
| Privacy & cryptography | references/privacy-and-cryptography.md | ZK patterns, signatures, identity proofs, privacy techniques |
| Full applications | references/applications.md | Multi-module DApps, real-world architecture, how pieces compose |
```

- [ ] **Step 2: Commit**

```bash
git add plugins/compact-examples/skills/code-examples/SKILL.md
git commit -m "feat(compact-examples): add SKILL.md routing file for code-examples skill"
```

---

### Task 11: Write references/getting-started.md

**Files:**
- Create: `plugins/compact-examples/skills/code-examples/references/getting-started.md`

- [ ] **Step 1: Write getting-started.md**

This reference file catalogues the 2 beginner examples. It should contain:

1. **Overview**: 2-3 sentences about what these examples demonstrate
2. **Example index table** with columns: Name, Path, Description, Witnesses, Complexity
3. **Cross-references** to modules.md for when the agent needs more advanced patterns

Content for the table:

| Name | Path | Description | Witnesses | Complexity |
|---|---|---|---|---|
| Counter | `examples/getting-started/counter/` | Minimal state counter — increments a public ledger `Counter` by 1 per transaction. Simplest possible Compact contract. | `witnesses.ts` — empty witnesses object (no private state) | Beginner |
| Bulletin Board | `examples/getting-started/bboard/` | Bulletin board with ownership — post messages, take down your own posts. Demonstrates public key derivation from secret key, ownership verification, `Opaque` types. | `witnesses.ts` — `localSecretKey` witness providing user's secret key | Beginner |

- [ ] **Step 2: Commit**

```bash
git add plugins/compact-examples/skills/code-examples/references/getting-started.md
git commit -m "feat(compact-examples): add getting-started reference file"
```

---

### Task 12: Write references/modules.md

**Files:**
- Create: `plugins/compact-examples/skills/code-examples/references/modules.md`

- [ ] **Step 1: Write modules.md**

This is the largest reference file. It catalogues all reusable building blocks organized by subdomain. Structure:

1. **Overview**: Reusable modules imported into contracts, not deployed standalone
2. **Subdomain sections** (one per directory): access, security, token, math, crypto, data-structures, identity, utils
3. Each subdomain has its own table with: Name, Path, Description, Witnesses, Tests, Complexity

Content for tables (derive from the actual migrated files — read each one to confirm descriptions are accurate):

**Access Control:**

| Name | Path | Description | Witnesses | Tests | Complexity |
|---|---|---|---|---|---|
| Ownable | `examples/modules/access/Ownable.compact` | Single-owner access control with ownership transfer | `witnesses/OwnableWitnesses.ts` | Yes (mock, simulator, test) | Intermediate |
| ZOwnablePK | `examples/modules/access/ZOwnablePK.compact` | Privacy-preserving ownership using commitment scheme | `witnesses/ZOwnablePKWitnesses.ts` | Yes | Advanced |
| AccessControl | `examples/modules/access/AccessControl.compact` | Role-based access control (RBAC) with role granting/revoking | `witnesses/AccessControlWitnesses.ts` | Yes | Intermediate |

**Security:**

| Name | Path | Description | Witnesses | Tests | Complexity |
|---|---|---|---|---|---|
| Initializable | `examples/modules/security/Initializable.compact` | One-time initialization guard preventing re-initialization | `witnesses/InitializableWitnesses.ts` | Yes | Beginner |
| Pausable | `examples/modules/security/Pausable.compact` | Emergency stop mechanism to pause/unpause contract operations | `witnesses/PausableWitnesses.ts` | Yes | Beginner |

**Token:**

| Name | Path | Description | Witnesses | Tests | Complexity |
|---|---|---|---|---|---|
| FungibleToken | `examples/modules/token/FungibleToken.compact` | ERC-20 approximation with transfers, approvals, minting, burning | `witnesses/FungibleTokenWitnesses.ts` | Yes | Intermediate |
| NonFungibleToken | `examples/modules/token/NonFungibleToken.compact` | ERC-721 approximation with ownership, approvals, URI storage | `witnesses/NonFungibleTokenWitnesses.ts` | Yes | Intermediate |
| MultiToken | `examples/modules/token/MultiToken.compact` | ERC-1155 approximation for multi-type token collections | `witnesses/MultiTokenWitnesses.ts` | Yes | Intermediate |
| Nft | `examples/modules/token/Nft.compact` | Standard NFT module with minting, burning, transfers, approvals | `witnesses/NftWitnesses.ts` | No | Intermediate |
| NftZk | `examples/modules/token/NftZk.compact` | Privacy-enhanced NFT using hash-based identity obfuscation | `witnesses/NftZkWitnesses.ts` | No | Advanced |

**Math:**

| Name | Path | Description | Witnesses | Tests | Complexity |
|---|---|---|---|---|---|
| Uint64 | `examples/modules/math/Uint64.compact` | 64-bit unsigned integer library with checked arithmetic, division, square root | See test/ | Yes | Intermediate |
| Uint128 | `examples/modules/math/Uint128.compact` | 128-bit unsigned integer (two Uint<64> limbs) with arithmetic | See test/ | Yes | Advanced |
| Uint256 | `examples/modules/math/Uint256.compact` | 256-bit unsigned integer (two U128 limbs) with comparisons | See test/ | Yes | Advanced |
| Bytes8 | `examples/modules/math/Bytes8.compact` | 8-byte to Uint<64> conversions, little-endian packing | See test/ | Yes | Intermediate |
| Bytes32 | `examples/modules/math/Bytes32.compact` | 32-byte operations: comparisons, U256 conversion, zero-check | See test/ | Yes | Intermediate |
| Field255 | `examples/modules/math/Field255.compact` | BLS12-381 scalar field operations via Bytes<32> | See test/ | Yes | Advanced |
| Pack | `examples/modules/math/Pack.compact` | Generic byte packing/unpacking with witness-based computation | See test/ | Yes | Advanced |
| Types | `examples/modules/math/Types.compact` | Shared type definitions (U128, U256 structs) for multi-limb integers | None | No | Beginner |

**Crypto:**

| Name | Path | Description | Witnesses | Tests | Complexity |
|---|---|---|---|---|---|
| schnorr | `examples/modules/crypto/schnorr.compact` | Schnorr signature verification polyfill for Jubjub curve | None (pure circuits) | No | Advanced |
| crypto | `examples/modules/crypto/crypto.compact` | EC cryptographic primitives: challenge computation, signing, verification | None (pure circuits) | No | Advanced |

**Data Structures:**

| Name | Path | Description | Witnesses | Tests | Complexity |
|---|---|---|---|---|---|
| Queue | `examples/modules/data-structures/Queue.compact` | Generic FIFO queue using Map<Uint<64>, T> with head/tail Counters | See test/ | Yes | Intermediate |

**Identity:**

| Name | Path | Description | Witnesses | Tests | Complexity |
|---|---|---|---|---|---|
| passportidentity | `examples/modules/identity/passportidentity.compact` | Passport/identity document data structures from MRZ format | None (pure circuits) | No | Intermediate |

**Utils:**

| Name | Path | Description | Witnesses | Tests | Complexity |
|---|---|---|---|---|---|
| Utils | `examples/modules/utils/Utils.compact` | Address comparison utilities and zero-value checks | `witnesses/UtilsWitnesses.ts` | Yes | Beginner |
| ShieldedUtils | `examples/modules/utils/ShieldedUtils.compact` | Either type handling, ZswapCoinPublicKey/ContractAddress conversions | None | No | Intermediate |

4. **Cross-references** to tokens.md for composed contracts that use these modules, and to applications.md for full apps

- [ ] **Step 2: Commit**

```bash
git add plugins/compact-examples/skills/code-examples/references/modules.md
git commit -m "feat(compact-examples): add modules reference file"
```

---

### Task 13: Write references/tokens.md

**Files:**
- Create: `plugins/compact-examples/skills/code-examples/references/tokens.md`

- [ ] **Step 1: Write tokens.md**

Structure:
1. **Overview**: Complete, deployable token contracts that compose modules
2. **Example index table**
3. **Cross-references** to modules.md for the building blocks these contracts use

| Name | Path | Description | Witnesses | Complexity |
|---|---|---|---|---|
| AccessControlledToken | `examples/tokens/AccessControlledToken.compact` | Fungible token with RBAC minting using AccessControl + FungibleToken modules | See witnesses/ | Intermediate |
| FungibleTokenMintablePausableOwnable | `examples/tokens/FungibleTokenMintablePausableOwnable.compact` | Full-featured token composing Ownable + Pausable + FungibleToken | See witnesses/ | Intermediate |
| SimpleNonFungibleToken | `examples/tokens/SimpleNonFungibleToken.compact` | Minimal NFT contract using NonFungibleToken module | See witnesses/ | Beginner |
| MultiTokenTwoTypes | `examples/tokens/MultiTokenTwoTypes.compact` | Multi-token collection managing two token types via MultiToken module | See witnesses/ | Intermediate |
| ShieldedFungibleToken | `examples/tokens/ShieldedFungibleToken.compact` | Shielded ERC20-like wrapper with minting and burning | See witnesses/ | Advanced |
| ShieldedERC20 | `examples/tokens/ShieldedERC20.compact` | Core shielded token module with nonce evolution (NOT production-ready) | See witnesses/ | Advanced |
| nft | `examples/tokens/nft.compact` | ERC-721 style NFT with admin minting/burning, approvals, transfers | `witnesses/nft-witnesses.ts` | Intermediate |
| nft-zk | `examples/tokens/nft-zk.compact` | Privacy-enhanced NFT hiding owner identities via hash keys | `witnesses/nft-zk-witnesses.ts` | Advanced |
| tbtc | `examples/tokens/tbtc.compact` | Simple test Bitcoin minting contract — fixed 1000 tBTC per mint | None | Beginner |

- [ ] **Step 2: Commit**

```bash
git add plugins/compact-examples/skills/code-examples/references/tokens.md
git commit -m "feat(compact-examples): add tokens reference file"
```

---

### Task 14: Write references/privacy-and-cryptography.md

**Files:**
- Create: `plugins/compact-examples/skills/code-examples/references/privacy-and-cryptography.md`

- [ ] **Step 1: Write privacy-and-cryptography.md**

This is a routing-only reference — no examples directory. It documents privacy patterns and cryptographic techniques with pointers to where the code lives in other directories.

Structure:
1. **Overview**: Privacy and cryptographic patterns demonstrated across the examples
2. **Pattern index** with: Pattern, Where to find it, What it demonstrates
3. **Cross-references** to the specific files

| Pattern | Location | Description |
|---|---|---|
| Schnorr signature verification | `examples/modules/crypto/schnorr.compact` | Jubjub curve Schnorr verification polyfill |
| EC cryptographic primitives | `examples/modules/crypto/crypto.compact` | Challenge computation, signing, deterministic nonces |
| Hash-based identity obfuscation | `examples/modules/token/NftZk.compact` | NFT ownership hidden via hash keys from local/shared secrets |
| Privacy-preserving ownership | `examples/modules/access/ZOwnablePK.compact` | Shielded ownership using commitment scheme |
| Passport/identity verification | `examples/modules/identity/passportidentity.compact` | MRZ document parsing and credential derivation |
| ZK credit scoring | `examples/applications/zkloan/zkloan-credit-scorer.compact` | Attested credit scores via Schnorr signatures, secret PIN |
| Merkle tree authorization | `examples/applications/midnight-rwa/midnight-rwa.compact` | Issuer/user authorization via historic Merkle trees |
| RWA identity + KYC | `examples/applications/midnight-rwa/midnight-rwa.compact` | Passport validation, identity signature verification, quiz onboarding |
| Shielded tokens | `examples/tokens/ShieldedFungibleToken.compact` | Shielded coin minting/burning with nonce evolution |

- [ ] **Step 2: Commit**

```bash
git add plugins/compact-examples/skills/code-examples/references/privacy-and-cryptography.md
git commit -m "feat(compact-examples): add privacy-and-cryptography reference file"
```

---

### Task 15: Write references/applications.md

**Files:**
- Create: `plugins/compact-examples/skills/code-examples/references/applications.md`

- [ ] **Step 1: Write applications.md**

Structure:
1. **Overview**: Full multi-module applications showing real-world architecture
2. **Application index** with: Name, Path, Description, Files, Witnesses, Complexity
3. **Cross-references** to modules.md for the standalone versions of modules used

| Name | Path | Description | Files | Witnesses | Complexity |
|---|---|---|---|---|---|
| CryptoKitties | `examples/applications/kitties/` | NFT breeding game — create, transfer, sell, breed kitties with combined DNA | `kitties.compact` | `witnesses.ts` — `createRandomNumber` for DNA generation | Advanced |
| ZK Lending | `examples/applications/zkloan/` | Zero-knowledge credit scoring with attested scores, Schnorr verification, loan lifecycle, PIN-based identity, blacklisting | `schnorr.compact`, `zkloan-credit-scorer.compact` | `witnesses.ts` — attested scoring witness, Schnorr reduction | Advanced |
| Real-World Assets | `examples/applications/midnight-rwa/` | RWA platform with identity verification, KYC/passport validation, Merkle tree authorization, tBTC/tHF token swaps | `midnight-rwa.compact`, `passportidentity.compact`, `crypto.compact` | `witnesses.ts` — Merkle path finders, secret key, challenge reduction | Advanced |
| tBTC Minter | `examples/applications/tbtc/` | Simple test Bitcoin minting — fixed 1000 tBTC per transaction with nonce evolution | `tbtc.compact` | None | Beginner |

- [ ] **Step 2: Commit**

```bash
git add plugins/compact-examples/skills/code-examples/references/applications.md
git commit -m "feat(compact-examples): add applications reference file"
```

---

### Task 16: Update plugin.json

**Files:**
- Modify: `plugins/compact-examples/.claude-plugin/plugin.json`

- [ ] **Step 1: Update plugin.json with new version, description, and keywords**

```json
{
  "name": "compact-examples",
  "version": "0.2.0",
  "description": "Compilable Compact smart contract examples — beginner contracts, reusable modules, token implementations, and full applications with witnesses and tests. All code at pragma language_version >= 0.22.",
  "author": {
    "name": "Aaron Bassett",
    "email": "aaron@devrel-ai.com"
  },
  "homepage": "https://github.com/devrelaicom/midnight-expert",
  "repository": "https://github.com/devrelaicom/midnight-expert.git",
  "license": "MIT",
  "keywords": [
    "midnight",
    "compact",
    "smart-contracts",
    "examples",
    "witnesses",
    "testing",
    "counter",
    "bulletin-board",
    "ownable",
    "access-control",
    "pausable",
    "initializable",
    "fungible-token",
    "non-fungible-token",
    "multi-token",
    "shielded-token",
    "nft",
    "math",
    "cryptography",
    "schnorr",
    "queue",
    "identity",
    "modules",
    "kitties",
    "zkloan",
    "rwa",
    "tbtc"
  ]
}
```

- [ ] **Step 2: Commit**

```bash
git add plugins/compact-examples/.claude-plugin/plugin.json
git commit -m "chore(compact-examples): bump version to 0.2.0, update description and keywords"
```

---

### Task 17: Update README.md

**Files:**
- Modify: `plugins/compact-examples/README.md`

- [ ] **Step 1: Rewrite README.md**

Update the README to reflect the new single-skill structure. Include:
- Plugin description
- Skill registration (just `code-examples`)
- Brief overview of the 5 example categories
- Note about compilation requirements (all examples compile with `pragma >= 0.22` and full proof generation)

- [ ] **Step 2: Commit**

```bash
git add plugins/compact-examples/README.md
git commit -m "docs(compact-examples): update README for reorganized plugin structure"
```

---

### Task 18: Final validation — compile spot-check

- [ ] **Step 1: Spot-check compilation of one contract per category**

Pick one contract from each category and re-run `compact build` to confirm they still compile:

```bash
# Getting started
cd plugins/compact-examples/skills/code-examples/examples/getting-started/counter
compact build counter.compact

# Modules (via mock)
cd ../../modules/access/test/mocks
compact build MockOwnable.compact

# Tokens
cd ../../../../tokens
compact build nft.compact

# Applications
cd ../applications/kitties
compact build kitties.compact
```

All must pass. If any fail, investigate and fix.

- [ ] **Step 2: Clean up all build artifacts**

```bash
find plugins/compact-examples/ -name "build" -type d -exec rm -rf {} + 2>/dev/null
```

- [ ] **Step 3: Verify no build artifacts are tracked**

```bash
git status plugins/compact-examples/
```

Expected: clean working tree (no untracked `build/` directories).

- [ ] **Step 4: Final commit if any cleanup was needed**

```bash
git add -A plugins/compact-examples/
git commit -m "chore(compact-examples): final cleanup after compilation validation"
```
