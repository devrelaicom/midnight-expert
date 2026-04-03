# compact-examples

<p align="center">
  <img src="assets/mascot.png" alt="compact-examples mascot" width="200" />
</p>

Handpicked examples of Compact smart contracts -- curated library implementations, patterns, and usage guides for building on Midnight.

## Skills

### compact-examples:openzeppelin

Covers OpenZeppelin Contracts for Compact: the Module/Contract pattern, access control modules (Ownable, ZOwnablePK, AccessControl), security modules (Initializable, Pausable), token modules (FungibleToken, NonFungibleToken, MultiToken), and the Utils module. Includes installation, testing with createSimulator, and troubleshooting.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| [installation-and-setup](skills/openzeppelin/references/installation-and-setup.md) | Installation, importing, project setup, and compilation | When adding OpenZeppelin modules to a Compact project |
| [module-contract-pattern](skills/openzeppelin/references/module-contract-pattern.md) | Module/Contract pattern, module types (internal, public, external), and contract composition rules | When understanding how OpenZeppelin modules are structured and composed |
| [testing](skills/openzeppelin/references/testing.md) | Testing setup, simulators, mocks, test utilities, and writing tests | When testing contracts that use OpenZeppelin modules |
| [ownable](skills/openzeppelin/references/ownable.md) | Ownable module: usage, ownership transfers, and API reference | When implementing single-owner access control |
| [access-control](skills/openzeppelin/references/access-control.md) | AccessControl module: RBAC, roles, granting/revoking, and API reference | When implementing role-based access control |
| [initializable-pausable](skills/openzeppelin/references/initializable-pausable.md) | Initializable and Pausable modules: usage and API reference | When adding one-time initialization guards or emergency stop functionality |
| [fungible-token](skills/openzeppelin/references/fungible-token.md) | FungibleToken module: ERC-20, transfers, approvals, minting, and API reference | When building an ERC-20 style token |
| [non-fungible-token](skills/openzeppelin/references/non-fungible-token.md) | NonFungibleToken module: ERC-721, ownership, approvals, URI storage, and API reference | When building an ERC-721 style NFT |
| [multi-token](skills/openzeppelin/references/multi-token.md) | MultiToken module: ERC-1155, multi-type tokens, and API reference | When building an ERC-1155 style multi-token |
| [utils](skills/openzeppelin/references/utils.md) | Utils module: address comparison, zero checks, and API reference | When comparing addresses or checking for zero values |
| [contract-library](skills/openzeppelin/references/contract-library.md) | Library overview, all modules, file index, version info, and limitations | When getting a high-level view of available modules |

#### Examples

| Name | Description | When it is used |
|------|-------------|-----------------|
| [AccessControlledToken.compact](skills/openzeppelin/examples/AccessControlledToken.compact) | Token with role-based access control for minting | When combining AccessControl with FungibleToken |
| [FungibleTokenMintablePausableOwnable.compact](skills/openzeppelin/examples/FungibleTokenMintablePausableOwnable.compact) | Fungible token with minting, pausing, and ownership | When building a full-featured governed token |
| [MultiTokenTwoTypes.compact](skills/openzeppelin/examples/MultiTokenTwoTypes.compact) | Multi-token collection with two distinct token types | When building a contract that manages multiple token IDs |
| [SimpleNonFungibleToken.compact](skills/openzeppelin/examples/SimpleNonFungibleToken.compact) | Minimal non-fungible token contract | When building a straightforward NFT |
| [modules/](skills/openzeppelin/examples/modules/) | Complete source code for all OpenZeppelin modules (access, security, token, utils) with witnesses, tests, mocks, and simulators | When studying module internals, writing tests, or understanding witness implementations |
