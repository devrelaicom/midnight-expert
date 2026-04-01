# Ledger Structure

## Overview

Midnight's ledger has two main components:
1. **Zswap State** - Token/coin management
2. **Contract Map** - Smart contract states

## Zswap State

The Zswap state tracks all coin activity on the ledger.

### Commitment Tree

- Merkle tree of all coin commitments ever created
- Depth determines maximum coins the network can hold
- Each leaf is a cryptographic commitment that hides the coin's value, type, and owner
- Note: Pedersen commitments are used separately for balance proofs, not as Merkle tree leaves

### First Free Index

- Points to the next available tree position
- Increments with each new coin
- Never decreases (append-only)

### Nullifiers

- A set containing all spent-coin nullifiers
- Checked before accepting new spends
- Prevents double-spending

### Commitment Tree History

- Recent Merkle roots kept for a time window so proofs can reference slightly older tree states
- Allows proofs against recent tree states
- Entries expire based on the time window (not kept indefinitely)

## Contract Map

The contract map associates each contract address with its state. A contract state consists of an Impact state value plus a map of entry point names to operations (SNARK verifier keys). The verifier keys allow the network to verify ZK proofs for each circuit entry point.

### Contract Address

The address is derived by hashing the initial contract state with a nonce, not from the full deployment transaction data.

### State Visibility

Contract state fields are stored directly and are public. Merkle trees store their full tree structure on-chain, but leaf preimages are hidden -- the tree shape is visible but not what was inserted. Sets store a membership structure with contents remaining private. These are Compact contract state types used within the Impact VM, corresponding to on-chain data structures managed by the Midnight ledger.

## State Transitions

### Adding a Coin

1. Compute the coin commitment from the coin data and the owner's public key
2. Insert the commitment at the next free leaf position
3. Increment the first-free index
4. Recompute the Merkle root
5. Add the new root to the historic roots

### Spending a Coin

1. Verify the nullifier is not already in the nullifier set
2. Verify a Merkle proof against a valid root in the historic roots
3. Verify a ZK proof of ownership
4. Add the nullifier to the nullifier set

### Updating Contract State

1. Look up the contract by address
2. Verify the ZK proof matches the circuit (using stored verifier keys)
3. Execute the Impact program
4. Verify resulting effects match those declared
5. Store the new state

## Token Types

### Native Token

The native token type identifier is the 256-bit zero value. This identifies the token type, not the token's value or balance.

### Custom Tokens

Custom token types are derived by hashing a domain separator with the issuing contract's address. The domain separator allows one contract to issue multiple token types.

## Value Accounting

### Zswap Balance Equation

For each token type, the sum of inputs minus the sum of outputs plus any minted value must be non-negative. Fees are accounted for in the native token dimension.

This is enforced via multi-base Pedersen commitment homomorphism for balance proofs, with independent balance proofs per token type and fee verification on the native token dimension.

### Multi-Asset Support

Each token type has independent balance accounting. The native token dimension also covers transaction fees.
