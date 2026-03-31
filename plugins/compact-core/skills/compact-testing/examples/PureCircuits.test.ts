// ============================================================================
// PURE CIRCUITS TEST -- TESTING STATELESS CIRCUIT LOGIC
// ============================================================================
//
// This file demonstrates how to test pure circuits in a Compact smart
// contract. Pure circuits are exported functions that perform computation
// without reading or writing ledger state, and without calling witnesses.
//
// What you will learn:
//   - The difference between pureCircuits, impureCircuits, and circuits
//   - How to call pure circuits directly (no simulator needed)
//   - Testing hash determinism with persistentHash patterns
//   - Testing public key derivation from a secret key
//   - Testing data transformations and type conversions
//   - Edge-case testing for zero and boundary values
//
// Prerequisites:
//   - A compiled Compact contract that contains at least one pure circuit
//   - The generated code lives in managed/<name>/contract/index.cjs
//   - vitest configured with deps.interopDefault: true (see vitest.config.ts)
//
// ============================================================================

// ==== UNDERSTANDING THE THREE CIRCUIT CATEGORIES ====
//
// When the Compact compiler outputs a contract, it generates three separate
// circuit groupings. Understanding when to use each is critical:
//
//   1. pureCircuits (module-level export)
//      - Circuits that do NOT touch ledger state and do NOT call witnesses
//      - Called directly with only their declared parameters -- no context
//      - No ZK proof generation (no .zkir/.prover/.verifier files)
//      - Example: pureCircuits.public_key(sk, instance)
//      - Use for: hash helpers, key derivation, type conversions, validation
//
//   2. impureCircuits (Contract instance property)
//      - Circuits that read/write ledger state or call witnesses
//      - Called with a CircuitContext as the first parameter
//      - ZK proof generation artifacts ARE produced for these circuits
//      - Example: contract.impureCircuits.post(context, message)
//      - Use for: state-changing operations (the main contract logic)
//
//   3. circuits (Contract instance property)
//      - Union of ALL circuits (pure + impure) with context as first param
//      - Every circuit appears here, even pure ones, but all require context
//      - Example: contract.circuits.public_key(context, sk, instance)
//      - Use for: when you need to call a pure circuit within a stateful flow
//
// For TESTING, prefer pureCircuits when testing helper logic in isolation.
// They are faster (no context setup), simpler (no state management), and
// make tests focused on the computation rather than the contract lifecycle.
//
// ============================================================================

// ==== EXAMPLE CONTRACT ====
//
// The tests below assume a contract similar to a bboard or ballot contract
// that defines pure helper circuits alongside its impure state-changing ones.
// A typical Compact source might look like:
//
//   pragma language_version >= 0.22;
//   import CompactStandardLibrary;
//
//   export ledger poster: Bytes<32>;
//   export ledger instance: Counter;
//
//   witness local_secret_key(): Bytes<32>;
//
//   // This circuit does NOT touch ledger state and does NOT call witnesses.
//   // The compiler classifies it as a pure circuit.
//   circuit public_key(sk: Bytes<32>, instance: Bytes<32>): Bytes<32> {
//     return disclose(persistentHash<Vector<2, Bytes<32>>>([
//       pad(32, "myapp:pk:"), sk
//     ]));
//   }
//
//   // This circuit DOES touch ledger state, so it is impure.
//   export circuit post(message: Opaque<"string">): [] {
//     poster = disclose(public_key(local_secret_key(), instance as Field as Bytes<32>));
//     // ...
//   }
//
// After compilation, the generated types will include:
//
//   export type PureCircuits = {
//     public_key(sk: Uint8Array, instance: Uint8Array): Uint8Array;
//   }
//
//   export type ImpureCircuits<T> = {
//     post(context: CircuitContext<T>, message: string): CircuitResults<T, void>;
//   }
//
//   export type Circuits<T> = {
//     post(context: CircuitContext<T>, message: string): CircuitResults<T, void>;
//     public_key(context: CircuitContext<T>, sk: Uint8Array, instance: Uint8Array):
//       CircuitResults<T, Uint8Array>;
//   }
//
//   export declare const pureCircuits: PureCircuits;
//
// ============================================================================

// ==== IMPORTS ====
//
// For pure circuit testing, we need fewer imports than a full simulator test.
// No CircuitContext, no createConstructorContext, no sampleContractAddress.
// We only need the module-level pureCircuits export.

// NOTE: setNetworkId is still required even for pure circuits, because the
// module initialization code in the compiled contract references the runtime.
import { setNetworkId } from "@midnight-ntwrk/midnight-js-network-id";

// The pureCircuits export is a module-level constant (not on the Contract
// class). Import it directly alongside any types you need.
//
// Adapt this import path to match your project structure:
import {
  pureCircuits,
  // You may also import the PureCircuits type if you want type safety:
  // type PureCircuits,
} from "../managed/bboard/contract/index.js";

// ==== NETWORK CONFIGURATION ====
//
// Even for pure circuit tests, the compiled contract module requires a
// network ID to be set. This is because the module-level initialization
// code in the generated JavaScript references the compact runtime, which
// checks for a configured network.

setNetworkId("undeployed");

// ==== HELPER FUNCTIONS ====
//
// Utility functions for creating test data. Pure circuits typically work
// with Uint8Array (Bytes<N> in Compact) and bigint (Uint<N> / Field).

/**
 * Create a Uint8Array of the specified length, filled with the given byte.
 * Useful for constructing deterministic test inputs.
 */
function filledBytes(length: number, fillByte: number): Uint8Array {
  return new Uint8Array(length).fill(fillByte);
}

/**
 * Create a zero-filled Uint8Array of the specified length.
 * Represents the Compact `default<Bytes<N>>` value.
 */
function zeroBytes(length: number): Uint8Array {
  return new Uint8Array(length);
}

/**
 * Pad a UTF-8 string to a fixed-length Uint8Array.
 * Mirrors the Compact `pad(N, "string")` built-in.
 */
function pad(length: number, str: string): Uint8Array {
  const encoder = new TextEncoder();
  const encoded = encoder.encode(str);
  const result = new Uint8Array(length);
  result.set(encoded);
  return result;
}

// ==== TEST SUITE ====
//
// Pure circuit tests are simpler than simulator-based tests because there
// is no state to manage. Each test calls a pure circuit function directly
// and asserts on the return value.

describe("Pure circuits", () => {

  // ==== PUBLIC KEY DERIVATION ====
  //
  // The public_key pure circuit derives a public key from a secret key
  // using persistentHash. This is used in bboard-style contracts to
  // identify the poster without revealing their secret key.

  describe("public_key derivation", () => {

    // ---- Test 1: Deterministic output ----
    //
    // The same inputs must always produce the same output. This is
    // fundamental for hash-based key derivation: if public_key were
    // non-deterministic, the contract could never verify ownership.
    it("produces deterministic output for the same inputs", () => {
      const secretKey = filledBytes(32, 0xAB);
      const instance = filledBytes(32, 0x01);

      const pk1 = pureCircuits.public_key(secretKey, instance);
      const pk2 = pureCircuits.public_key(secretKey, instance);

      // Same inputs must yield identical outputs.
      expect(pk1).toEqual(pk2);
      // The result is a 32-byte hash (Bytes<32>).
      expect(pk1).toBeInstanceOf(Uint8Array);
      expect(pk1.length).toBe(32);
    });

    // ---- Test 2: Different secrets produce different keys ----
    //
    // Two different secret keys should produce different public keys.
    // This is essential for the security of the derivation scheme.
    it("produces different public keys for different secret keys", () => {
      const sk1 = filledBytes(32, 0x01);
      const sk2 = filledBytes(32, 0x02);
      const instance = filledBytes(32, 0x00);

      const pk1 = pureCircuits.public_key(sk1, instance);
      const pk2 = pureCircuits.public_key(sk2, instance);

      // Different secrets must produce different public keys.
      expect(pk1).not.toEqual(pk2);
    });

    // ---- Test 3: Different instances produce different keys ----
    //
    // In bboard, the instance field is incremented on each post cycle.
    // Different instance values should produce different public keys
    // even for the same secret key, preventing cross-instance linkability.
    it("produces different public keys for different instance values", () => {
      const secretKey = filledBytes(32, 0xAB);
      const instance1 = filledBytes(32, 0x01);
      const instance2 = filledBytes(32, 0x02);

      const pk1 = pureCircuits.public_key(secretKey, instance1);
      const pk2 = pureCircuits.public_key(secretKey, instance2);

      expect(pk1).not.toEqual(pk2);
    });

    // ---- Test 4: Zero secret key is a valid input ----
    //
    // Edge case: a zero-filled secret key is technically valid.
    // The pure circuit should still produce a valid 32-byte hash
    // without throwing. In practice, zero keys should never be used,
    // but the circuit logic must handle them gracefully.
    it("handles zero secret key without error", () => {
      const zeroKey = zeroBytes(32);
      const instance = zeroBytes(32);

      const pk = pureCircuits.public_key(zeroKey, instance);

      expect(pk).toBeInstanceOf(Uint8Array);
      expect(pk.length).toBe(32);
      // A zero input should still produce a non-zero hash output
      // because persistentHash is a cryptographic function.
      const allZero = new Uint8Array(32);
      expect(pk).not.toEqual(allZero);
    });

    // ---- Test 5: Output is distinct from input ----
    //
    // The public key must not be the same as the secret key. This
    // confirms the hash function is actually transforming the input.
    it("produces output distinct from the secret key input", () => {
      const secretKey = filledBytes(32, 0xFF);
      const instance = zeroBytes(32);

      const pk = pureCircuits.public_key(secretKey, instance);

      expect(pk).not.toEqual(secretKey);
    });
  });

  // ==== PURE CIRCUITS VS CIRCUITS ====
  //
  // The following tests illustrate the conceptual difference between
  // calling a circuit via pureCircuits vs via contract.circuits.
  //
  // With pureCircuits (preferred for isolated testing):
  //   const result = pureCircuits.public_key(sk, instance);
  //   // Returns: Uint8Array directly
  //
  // With contract.circuits (requires full contract setup):
  //   const { result, context } = contract.circuits.public_key(ctx, sk, instance);
  //   // Returns: { result: Uint8Array, context: CircuitContext }
  //
  // Both call the same underlying circuit logic. The pureCircuits version
  // is strictly simpler because it does not require a CircuitContext.

  // ==== WHEN TO USE EACH APPROACH ====
  //
  // Use pureCircuits when:
  //   - Testing hash computations (persistentHash, transientHash)
  //   - Testing key derivation (public_key from secret_key)
  //   - Testing data transformations (type casts, vector operations)
  //   - Testing validation logic that does not depend on state
  //   - You want fast, focused unit tests with minimal setup
  //
  // Use impureCircuits (via Simulator) when:
  //   - Testing state transitions (ledger reads/writes)
  //   - Testing access control (assert checks against ledger values)
  //   - Testing witness interactions (reading from private state)
  //   - Testing the full circuit lifecycle (constructor -> circuits -> state)
  //
  // Use contract.circuits when:
  //   - You need a pure circuit's result within a stateful test flow
  //   - You want to verify that context passes through a pure circuit unchanged
});
