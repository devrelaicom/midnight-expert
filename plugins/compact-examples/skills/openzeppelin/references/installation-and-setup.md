# Installation & Setup

## Prerequisites

- nvm and yarn installed
- Compact Developer Tools installed (compact compiler in PATH)
- Verify with: `compact compile --version`

## Installation

1. Create project directory:

```bash
mkdir my-project && cd my-project
```

2. Initialize git and add as submodule:

```bash
git init && git submodule add https://github.com/OpenZeppelin/compact-contracts.git
```

3. Install dependencies and prepare environment:

```bash
cd compact-contracts
nvm install && yarn && SKIP_ZK=true yarn compact
cd ..
```

## Importing Modules

Import modules through `node_modules` rather than directly to avoid state conflicts between shared dependencies:

```compact
pragma language_version >= 0.22.0;

import CompactStandardLibrary;
import "./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/access/Ownable"
  prefix Ownable_;
```

Always use a prefix when importing to avoid circuit signature clashes. Recommended prefixes:

- Ownable → `Ownable_`
- ZOwnablePK → `ZOwnablePK_`
- AccessControl → `AccessControl_`
- Initializable → `Initializable_`
- Pausable → `Pausable_`
- FungibleToken → `FungibleToken_`
- NonFungibleToken → `NonFungibleToken_`
- MultiToken → `MultiToken_`
- Utils → `Utils_`

Note: Installing the library will be easier once it's available as an NPM package.

## Module Import Paths

| Module | Full Import Path |
|--------|-----------------|
| Ownable | `./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/access/Ownable` |
| ZOwnablePK | `./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/access/ZOwnablePK` |
| AccessControl | `./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/access/AccessControl` |
| Initializable | `./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/security/Initializable` |
| Pausable | `./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/security/Pausable` |
| FungibleToken | `./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/token/FungibleToken` |
| NonFungibleToken | `./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/token/NonFungibleToken` |
| MultiToken | `./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/token/MultiToken` |
| Utils | `./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/utils/Utils` |

## Compiling Contracts

Compile using Compact's dev tools from the project root:

```bash
compact compile MyContract.compact artifacts/MyContract
```

Output shows circuit complexity:

```
Compiling 3 circuits:
  circuit "pause" (k=10, rows=125)
  circuit "transfer" (k=11, rows=1180)
  circuit "unpause" (k=10, rows=121)
Overall progress [====================] 3/3
```

### Development Tips

- Use `SKIP_ZK=true` during development to skip ZK prover/verifier key generation (which is slow)
- For the OpenZeppelin repo itself, use `turbo` for targeted compilation: `turbo compact:token`, `turbo compact:access`, etc.
- Circuit size (k) is a power of 2 domain size; fewer rows = faster proof generation
- Keep circuits small for better performance on Midnight
