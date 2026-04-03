# core-concepts

Conceptual foundations for understanding the Midnight Network: architecture, data models, privacy patterns, protocols, tokenomics, and zero-knowledge proofs.

## Skills

### core-concepts:architecture

Covers Midnight network architecture, transaction structure, guaranteed vs fallible sections, Zswap/Kachina integration, ledger and state management, cryptographic binding, balance verification, nullifiers, address derivation, and the privacy model separating private and public domains.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| cryptographic-binding.md | How cryptographic binding ensures transaction integrity and atomic execution | When explaining how transaction components are linked and protected against tampering |
| state-management.md | Global ledger state structure covering Zswap state and the contract map | When explaining how on-chain state is organized and managed |
| transaction-deep-dive.md | Complete transaction anatomy including Zswap offers, contract calls, and binding randomness | When a deep understanding of transaction internals is needed |

### core-concepts:data-models

Covers UTXO vs account models, ledger tokens, shielded/unshielded tokens, nullifiers, coin commitments, the Zswap commitment tree, double-spend prevention, token balances, parallel transaction processing, and the ledger structure.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| ledger-structure.md | Overview of the two main ledger components: Zswap state and the contract map | When explaining how the ledger is organized at a structural level |
| utxo-mechanics.md | UTXO lifecycle from creation through consumption and reuse prevention | When explaining UTXO creation, spending, and double-spend prevention in detail |

### core-concepts:privacy-patterns

Covers privacy-preserving design patterns including commitment schemes, nullifier patterns, Merkle tree membership proofs, anonymous authentication, commit-reveal protocols, selective disclosure, and domain separation.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| commitment-schemes.md | Detailed reference for Compact's hash-based commitment primitives and their correct usage | When explaining how commitments work in Compact vs Zswap's Pedersen commitments |
| merkle-tree-usage.md | Reference for MerkleTree, HistoricMerkleTree, membership proofs, and MerkleTreePath | When explaining Merkle tree types, membership proofs, and proof invalidation behavior |

### core-concepts:protocols

Covers the Kachina smart contract protocol, Zswap token transfers, atomic swaps, shielded transfers, the two-state model (public/private state), and how ZK proofs enable privacy in Midnight protocol transactions.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| kachina-deep-dive.md | Formal definition of Kachina, its security model, and confidential computation design | When explaining the Kachina protocol's theoretical foundations and guarantees |
| zswap-internals.md | Zswap's extension of Zerocash with native multi-asset support and atomic swaps | When explaining how Zswap works internally and integrates with Kachina |

### core-concepts:tokenomics

Covers the NIGHT token, DUST resource, token distribution, Glacier Drop, Scavenger Mine, block rewards, STAR denomination, the dual-token model, MEV resistance, and transaction fee mechanics.

### core-concepts:zero-knowledge

Covers zero-knowledge proofs, ZK SNARKs, witness data, prover/verifier roles, constraint systems, proof generation, proof verification, privacy boundaries, and how Midnight uses ZK cryptography for transaction privacy.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| circuit-construction.md | The compilation pipeline from Compact source code to ZK circuits | When explaining how Compact contracts are compiled into provable circuits |
| snark-internals.md | PLONK proving system internals including gate-based arithmetization and polynomial commitments | When explaining the underlying cryptographic proving system used by Midnight |

## Agents

### concept-explainer

Synthesizes complex technical concepts across multiple Midnight domains when a question spans architecture, protocols, data models, privacy patterns, tokenomics, or zero-knowledge proofs.

#### When to use

Use when the user asks complex questions that span multiple concept domains or needs a synthesized explanation connecting different parts of the Midnight architecture -- for example, understanding how a private transaction works end-to-end, how Kachina/Zswap/Impact fit together, or why Midnight uses the commitment/nullifier pattern.
