// ============================================================================
// COUNTER SIMULATOR TEST -- BEGINNER EXAMPLE
// ============================================================================
//
// This file demonstrates how to test a simple Compact smart contract using the
// Simulator pattern. The counter contract is the simplest Midnight example: it
// has a single ledger field (`round`) and a single circuit (`increment`).
//
// What you will learn:
//   - How to import runtime helpers and generated contract code
//   - How to build a Simulator class that wraps a Compact contract
//   - How to write tests that verify ledger state and private state
//   - How the context lifecycle works (create, call, reassign)
//
// Prerequisites:
//   - A compiled counter.compact contract (run `npx compactc` first)
//   - The generated code lives in managed/counter/contract/index.cjs
//   - vitest configured with deps.interopDefault: true (see vitest.config.ts)
//
// The counter.compact contract under test:
//
//   pragma language_version >= 0.20;
//   import CompactStandardLibrary;
//   export ledger round: Counter;
//   export circuit increment(): [] {
//     round.increment(1);
//   }
//
// ============================================================================

// ==== IMPORTS ====
//
// There are three categories of imports for a Compact contract test:
//
//   1. Runtime helpers -- from @midnight-ntwrk/compact-runtime
//      These provide the machinery to simulate contract execution locally.
//
//   2. Network ID setter -- from @midnight-ntwrk/midnight-js-network-id
//      Required to configure the runtime for local (undeployed) testing.
//
//   3. Generated contract code -- from the compiler output directory
//      The Compact compiler produces Contract, Ledger, and ledger() from
//      your .compact source file.
//
//   4. Witness definitions -- your TypeScript witness implementations
//      For the counter contract, there are no witnesses, but we still
//      define a private state type.

import {
  type CircuitContext,           // Type representing the current execution state
  createConstructorContext,      // Creates the initial context for contract deployment
  createCircuitContext,          // Creates a reusable context for calling circuits
  sampleContractAddress,         // Returns a deterministic address for testing
} from "@midnight-ntwrk/compact-runtime";

import { setNetworkId } from "@midnight-ntwrk/midnight-js-network-id";

import {
  Contract,                      // The contract wrapper class (generic over private state)
  type Ledger,                   // Type describing the on-chain ledger fields
  ledger,                        // Helper function to parse raw state into typed Ledger
} from "../managed/counter/contract/index.js";

// Import the private state type and witnesses from your project's witnesses file.
// The counter contract has no witness declarations, so witnesses is an empty object.
import { type CounterPrivateState, witnesses } from "../witnesses.js";

// ==== PRIVATE STATE TYPE ====
//
// Every Simulator needs a private state type. For the counter contract there
// are no witnesses, but the example-counter repo still defines a minimal
// private state with a `privateCounter` field. This shows that private state
// exists even when the contract does not use witnesses -- it is the off-chain
// data that travels with the user.
//
// In witnesses.ts this looks like:
//
//   export type CounterPrivateState = {
//     privateCounter: number;
//   };
//
//   export const witnesses = {};

// ==== NETWORK CONFIGURATION ====
//
// setNetworkId("undeployed") tells the Midnight runtime that we are running
// locally without a real blockchain. This MUST be called before creating any
// Contract instance. Calling it at module level (outside describe/it blocks)
// ensures it runs once before all tests.
//
// Without this call, the runtime will throw a network configuration error
// when you try to instantiate a Contract.

setNetworkId("undeployed");

// ==== SIMULATOR CLASS ====
//
// The Simulator wraps the Contract instance and its CircuitContext, providing
// simple methods that hide the context-passing mechanics. Each circuit becomes
// a method call, and ledger/private state become getter methods.
//
// Why use a Simulator?
//   - Tests read like plain function calls: simulator.increment()
//   - No need to manually pass and reassign contexts in every test
//   - State access is typed and consistent
//   - Easy to extend with new circuits or helper methods

class CounterSimulator {
  // The Contract instance holds the compiled circuit logic and witness
  // implementations. It is generic over CounterPrivateState.
  readonly contract: Contract<CounterPrivateState>;

  // The CircuitContext tracks all runtime state: ledger values, private state,
  // and internal ZK state. It is reassigned after every circuit call because
  // the runtime returns a NEW context rather than mutating the existing one.
  circuitContext: CircuitContext<CounterPrivateState>;

  constructor() {
    // Step 1: Create the Contract instance with witness implementations.
    // For the counter, witnesses is an empty object {} because the contract
    // has no witness declarations.
    this.contract = new Contract<CounterPrivateState>(witnesses);

    // Step 2: Run the contract constructor to produce initial state.
    //
    // createConstructorContext takes two arguments:
    //   - The initial private state: { privateCounter: 0 }
    //   - A 64-character hex seed for deterministic ZK key derivation.
    //     In tests, "0".repeat(64) is standard because it makes results
    //     reproducible across runs.
    //
    // contract.initialState() executes the Compact constructor block and
    // returns three state components that together describe the full
    // post-construction state of the contract.
    const {
      currentPrivateState,       // Off-chain private state after construction
      currentContractState,      // On-chain ledger state (round = 0)
      currentZswapLocalState,    // Internal ZK bookkeeping state
    } = this.contract.initialState(
      createConstructorContext({ privateCounter: 0 }, "0".repeat(64)),
    );

    // Step 3: Build the circuit context for subsequent circuit calls.
    //
    // createCircuitContext bundles everything a circuit needs to execute:
    //   - A contract address (sampleContractAddress() returns a deterministic
    //     test address that is the same every time)
    //   - The ZK local state from the constructor
    //   - The contract (ledger) state from the constructor
    //   - The private state from the constructor
    //
    // The argument order matters: address, zswap, contract, private.
    this.circuitContext = createCircuitContext(
      sampleContractAddress(),
      currentZswapLocalState,
      currentContractState,
      currentPrivateState,
    );
  }

  // ==== CIRCUIT WRAPPERS ====
  //
  // Each exported circuit in the Compact contract gets a wrapper method.
  // The pattern is always the same:
  //   1. Call the circuit via contract.impureCircuits.<name>(this.circuitContext)
  //   2. Reassign this.circuitContext to the returned context
  //   3. Optionally return the ledger state or circuit result
  //
  // Reassignment is MANDATORY. The runtime does not mutate the context -- it
  // returns a new one. If you forget to reassign, subsequent calls will use
  // stale state and produce incorrect results.

  public increment(): Ledger {
    // Call the increment circuit. It takes no arguments beyond the context.
    // The return value is { context, result } where result is [] (void)
    // because the Compact circuit returns [].
    this.circuitContext = this.contract.impureCircuits.increment(
      this.circuitContext,
    ).context;

    // Return the updated ledger state for convenience in assertions.
    return ledger(this.circuitContext.currentQueryContext.state);
  }

  // ==== STATE ACCESSORS ====
  //
  // These methods let tests inspect the current ledger and private state
  // without reaching into the context internals.

  public getLedger(): Ledger {
    // ledger() is a generated function that parses the raw contract state
    // into a typed Ledger object. For the counter contract, Ledger has a
    // single field: round (bigint).
    return ledger(this.circuitContext.currentQueryContext.state);
  }

  public getPrivateState(): CounterPrivateState {
    // The private state is stored directly on the circuit context.
    // For the counter, this is { privateCounter: number }.
    return this.circuitContext.currentPrivateState;
  }
}

// ==== TEST SUITE ====
//
// Each test creates a fresh CounterSimulator so tests are independent.
// The counter contract is simple enough that we can verify every aspect
// of its behavior in a few focused tests.

describe("Counter smart contract", () => {
  // ---- Test 1: Deterministic initialization ----
  //
  // Two simulators created with the same inputs should produce identical
  // initial ledger state. This verifies that the constructor is pure and
  // the seed-based key derivation is deterministic.
  it("generates initial ledger state deterministically", () => {
    const simulator0 = new CounterSimulator();
    const simulator1 = new CounterSimulator();

    // Both simulators should have exactly the same ledger after construction.
    expect(simulator0.getLedger()).toEqual(simulator1.getLedger());
  });

  // ---- Test 2: Initial state values ----
  //
  // After construction (before any circuit calls), the ledger field `round`
  // should be 0n and the private state should match what we passed to
  // createConstructorContext.
  it("properly initializes ledger state and private state", () => {
    const simulator = new CounterSimulator();

    // The counter.compact contract declares: export ledger round: Counter;
    // Counter starts at 0. In TypeScript, Counter values are bigint.
    const initialLedgerState = simulator.getLedger();
    expect(initialLedgerState.round).toEqual(0n);

    // Private state should be exactly what we passed during construction.
    const initialPrivateState = simulator.getPrivateState();
    expect(initialPrivateState).toEqual({ privateCounter: 0 });
  });

  // ---- Test 3: Single increment ----
  //
  // Calling increment() once should advance round from 0n to 1n.
  // The private state should remain unchanged because the counter contract
  // has no witnesses that modify private state.
  it("increments the counter correctly", () => {
    const simulator = new CounterSimulator();

    // Call the increment circuit once.
    const nextLedgerState = simulator.increment();

    // The Compact circuit calls round.increment(1), which adds 1 to the
    // Counter. Counter values are bigint, so we compare with 1n.
    expect(nextLedgerState.round).toEqual(1n);

    // Private state is unchanged -- no witnesses modify it.
    const nextPrivateState = simulator.getPrivateState();
    expect(nextPrivateState).toEqual({ privateCounter: 0 });
  });

  // ---- Test 4: Multiple increments accumulate ----
  //
  // Each increment call adds 1 to the round counter. Calling it three
  // times should produce round === 3n. This confirms that context
  // reassignment is working correctly in the Simulator -- if the context
  // were not reassigned, every call would start from 0n.
  it("accumulates increments across multiple calls", () => {
    const simulator = new CounterSimulator();

    // Increment three times in sequence.
    simulator.increment();
    simulator.increment();
    const finalLedger = simulator.increment();

    // round should be 3n (0 + 1 + 1 + 1).
    expect(finalLedger.round).toEqual(3n);

    // Verify via the getLedger() accessor as well (same result).
    expect(simulator.getLedger().round).toEqual(3n);
  });

  // ---- Test 5: Private state remains stable ----
  //
  // The counter contract does not have witness functions, so private state
  // should never change regardless of how many circuits are called. This
  // test explicitly verifies that invariant after multiple operations.
  it("does not modify private state across circuit calls", () => {
    const simulator = new CounterSimulator();

    // Record initial private state.
    const initialPrivateState = simulator.getPrivateState();

    // Run several increments.
    simulator.increment();
    simulator.increment();
    simulator.increment();

    // Private state should be identical to what it was at construction.
    expect(simulator.getPrivateState()).toEqual(initialPrivateState);
    expect(simulator.getPrivateState()).toEqual({ privateCounter: 0 });
  });
});
