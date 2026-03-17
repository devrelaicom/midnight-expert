// ============================================================================
// counter-witnesses.ts -- TypeScript witness implementations for counter.compact
// ============================================================================
//
// ILLUSTRATIVE EXAMPLE: This file demonstrates the pattern for implementing
// Compact witness functions in TypeScript. The exact SDK integration API
// may differ. See the Midnight SDK documentation for current details.
//
// In Compact, witnesses are declaration-only:
//   witness local_secret_key(): Bytes<32>;
//
// The actual logic runs off-chain in TypeScript. Each witness declared in
// the Compact contract must have a corresponding TypeScript implementation
// that the Midnight SDK invokes during proof generation.
//
// Flow:
//   1. User initiates a transaction (e.g., calls incrementBy)
//   2. SDK invokes the Compact circuit logic off-chain
//   3. When the circuit calls a witness, SDK delegates to TypeScript
//   4. TypeScript returns the private value (e.g., secret key)
//   5. The value is used inside the ZK proof -- it NEVER appears on-chain
//   6. SDK generates the ZK proof and Impact bytecode
//   7. Transaction is submitted with proof (no private data included)
//
// ============================================================================

import { type WitnessContext } from '@midnight-ntwrk/compact-runtime';

// --------------------------------------------------------------------------
// Witness implementation for: witness local_secret_key(): Bytes<32>;
// --------------------------------------------------------------------------
//
// Returns the user's secret key from local secure storage.
// This value NEVER appears on-chain -- it is used only inside the ZK proof
// to derive the public key, which is then compared against the on-chain
// authority field.
//
export function local_secret_key(context: WitnessContext): Uint8Array {
  // In practice, retrieve from secure key storage (e.g., browser wallet, keychain).
  // NEVER hardcode secret keys in production.
  const secretKeyHex = context.localStorage.getItem('secret_key');
  if (!secretKeyHex) {
    throw new Error('Secret key not found in local storage');
  }
  return hexToBytes(secretKeyHex);
}

// --------------------------------------------------------------------------
// Helper: hex string to Uint8Array
// --------------------------------------------------------------------------

function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
  }
  return bytes;
}

// ============================================================================
// SDK Integration Pattern (Illustrative)
// ============================================================================
//
// The Midnight SDK's provider pattern connects witness implementations
// to the deployed contract. A typical integration looks like:
//
//   import { ContractProvider } from '@midnight-ntwrk/midnight-js-contracts';
//
//   const provider = new ContractProvider({
//     contract: counterContract,
//     witnesses: {
//       local_secret_key,  // function exported above
//     },
//   });
//
//   // Call an exported circuit
//   const tx = await provider.callCircuit('incrementBy', [42n]);
//
// The provider automatically:
//   - Invokes witness functions when the circuit needs private data
//   - Generates the ZK proof using the witness values
//   - Constructs the Impact bytecode for on-chain execution
//   - Submits the transaction to the Midnight network
//
// IMPORTANT: The exact API surface (ContractProvider, callCircuit, etc.)
// is subject to change. Consult the Midnight SDK documentation for the
// current integration pattern.
//
// ============================================================================
