// ============================================================================
// BBOARD SIMULATOR TEST -- INTERMEDIATE EXAMPLE
// ============================================================================
//
// This file demonstrates testing a Compact contract with witnesses, private
// state, and multi-user interactions. The bulletin board (bboard) contract
// lets users post messages and take them down, enforcing ownership so only
// the poster can remove their own message.
//
// What you will learn:
//   - How to implement a witness function (localSecretKey pattern)
//   - How to build a Simulator with secret key private state
//   - How to test Maybe<T> fields, enum transitions, and error cases
//   - How to test multi-user scenarios by swapping private state
//
// Key Compact concepts used in the bboard contract:
//
//   - `witness localSecretKey(): Bytes<32>` -- declares a function whose
//     implementation lives in TypeScript. The runtime calls it during circuit
//     execution to retrieve the user's secret key from off-chain private state.
//
//   - `disclose()` -- marks a value as public output in the ZK proof. In
//     post(), both the owner public key and the message are disclosed so they
//     appear on the ledger. The secret key itself is never disclosed.
//
//   - `publicKey(sk, sequence)` -- a pure circuit that derives a public key
//     by hashing the secret key with the current sequence number. Only the
//     secret key holder can produce a matching result.
//
// ============================================================================

// ==== IMPORTS ====

import {
  type CircuitContext,
  createConstructorContext,
  createCircuitContext,
  sampleContractAddress,
  convertFieldToBytes,
  type WitnessContext,
} from "@midnight-ntwrk/compact-runtime";

import { setNetworkId } from "@midnight-ntwrk/midnight-js-network-id";

import {
  Contract,
  type Ledger,
  ledger,
  State,                         // Enum: State.VACANT (0), State.OCCUPIED (1)
} from "../managed/bboard/contract/index.js";

// ==== PRIVATE STATE TYPE ====
//
// The bboard contract has one witness: localSecretKey(). It needs the user's
// secret key, so our private state holds it. When we switch users, we swap
// in a different secretKey while keeping the same type shape.

type BBoardPrivateState = {
  readonly secretKey: Uint8Array;
};

// ==== WITNESS IMPLEMENTATION ====
//
// The `witnesses` object maps each Compact `witness` name to its TypeScript
// implementation. The signature is always:
//   (WitnessContext<Ledger, PrivateState>) => [PrivateState, ReturnValue]
//
// For localSecretKey, we return the private state unchanged and provide
// the secret key as the value. The runtime calls this automatically whenever
// the Compact circuit invokes localSecretKey().

const witnesses = {
  localSecretKey: ({
    privateState,
  }: WitnessContext<Ledger, BBoardPrivateState>): [
    BBoardPrivateState,
    Uint8Array,
  ] => [privateState, privateState.secretKey],
};

// ==== HELPER ====

const randomBytes = (length: number): Uint8Array => {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return bytes;
};

// ==== NETWORK CONFIGURATION ====

setNetworkId("undeployed");

// ==== SIMULATOR CLASS ====
//
// Compared to the beginner CounterSimulator, BBoardSimulator adds:
//   - A constructor that takes a secret key (representing a user)
//   - switchUser() for multi-user testing
//   - publicKey() that calls the contract's pure circuit
//   - Circuit wrappers for post() and takeDown()

class BBoardSimulator {
  readonly contract: Contract<BBoardPrivateState>;
  circuitContext: CircuitContext<BBoardPrivateState>;

  constructor(secretKey: Uint8Array) {
    this.contract = new Contract<BBoardPrivateState>(witnesses);

    const {
      currentPrivateState,
      currentContractState,
      currentZswapLocalState,
    } = this.contract.initialState(
      createConstructorContext({ secretKey }, "0".repeat(64)),
    );

    this.circuitContext = createCircuitContext(
      sampleContractAddress(),
      currentZswapLocalState,
      currentContractState,
      currentPrivateState,
    );
  }

  // ==== MULTI-USER SUPPORT ====
  //
  // switchUser() replaces the private state with a new secret key. After
  // calling this, all circuit calls use the new key via the witness. The
  // ledger state (on-chain) is shared, but private state is per-user --
  // this mirrors how Midnight works in production.

  public switchUser(secretKey: Uint8Array): void {
    this.circuitContext.currentPrivateState = { secretKey };
  }

  // ==== STATE ACCESSORS ====

  public getLedger(): Ledger {
    return ledger(this.circuitContext.currentQueryContext.state);
  }

  public getPrivateState(): BBoardPrivateState {
    return this.circuitContext.currentPrivateState;
  }

  // ==== CIRCUIT WRAPPERS ====

  public post(message: string): Ledger {
    // post() internally calls localSecretKey() via the witness to derive
    // the owner public key, then stores both key and message on the ledger
    // using disclose().
    this.circuitContext = this.contract.impureCircuits.post(
      this.circuitContext,
      message,
    ).context;
    return ledger(this.circuitContext.currentQueryContext.state);
  }

  public takeDown(): Ledger {
    // takeDown() calls localSecretKey() to verify the caller is the poster
    // by comparing derived public keys. Returns the former message.
    this.circuitContext = this.contract.impureCircuits.takeDown(
      this.circuitContext,
    ).context;
    return ledger(this.circuitContext.currentQueryContext.state);
  }

  // ==== PUBLIC KEY DERIVATION ====
  //
  // Calls the contract's publicKey circuit to derive the current user's
  // public key. The sequence (bigint) must be converted to Bytes<32> first.

  public publicKey(): Uint8Array {
    const sequence = convertFieldToBytes(
      32,
      this.getLedger().sequence,
      "BBoardSimulator",
    );
    return this.contract.circuits.publicKey(
      this.circuitContext,
      this.getPrivateState().secretKey,
      sequence,
    ).result;
  }
}

// ==== TEST SUITE ====

describe("BBoard smart contract", () => {
  // ---- Initial state after construction ----
  it("properly initializes ledger state and private state", () => {
    const key = randomBytes(32);
    const simulator = new BBoardSimulator(key);

    const state = simulator.getLedger();
    expect(state.state).toEqual(State.VACANT);
    expect(state.sequence).toEqual(1n);
    // Maybe<Opaque<"string">> starts as none: is_some is false, value is "".
    expect(state.message.is_some).toEqual(false);
    expect(state.message.value).toEqual("");
    // Owner is 32 zero bytes before anyone posts.
    expect(state.owner).toEqual(new Uint8Array(32));

    expect(simulator.getPrivateState()).toEqual({ secretKey: key });
  });

  // ---- Post a message and verify ledger ----
  //
  // After posting, the board transitions to OCCUPIED, the message field
  // becomes some(message), and the owner is set to the poster's public key.
  // The sequence does not change on post (only on takeDown).
  it("lets you post a message and verifies ledger state", () => {
    const simulator = new BBoardSimulator(randomBytes(32));
    const initialPrivateState = simulator.getPrivateState();
    const message = "The most important step a man can take is the next one.";

    simulator.post(message);

    // Private state should not change -- localSecretKey only reads it.
    expect(simulator.getPrivateState()).toEqual(initialPrivateState);

    const state = simulator.getLedger();
    expect(state.state).toEqual(State.OCCUPIED);
    expect(state.sequence).toEqual(1n);
    expect(state.message.is_some).toEqual(true);
    expect(state.message.value).toEqual(message);
    expect(state.owner).toEqual(simulator.publicKey());
  });

  // ---- Take down a message and verify state reset ----
  //
  // After takeDown, the board returns to VACANT, the message becomes none,
  // and the sequence increments. Note: the contract does NOT clear the owner
  // field on takeDown -- it retains the previous poster's public key.
  it("lets you take down a message and verifies state reset", () => {
    const simulator = new BBoardSimulator(randomBytes(32));
    const initialPrivateState = simulator.getPrivateState();
    const initialPublicKey = simulator.publicKey();

    simulator.post("This message will be taken down.");
    simulator.takeDown();

    expect(simulator.getPrivateState()).toEqual(initialPrivateState);

    const state = simulator.getLedger();
    expect(state.state).toEqual(State.VACANT);
    expect(state.sequence).toEqual(2n);
    expect(state.message.is_some).toEqual(false);
    expect(state.message.value).toEqual("");
    // Owner is not cleared on takeDown -- this is safe because state is VACANT.
    expect(state.owner).toEqual(initialPublicKey);
  });

  // ---- Multi-user: User A posts, User B cannot take down ----
  //
  // switchUser() changes which secret key the witness returns. Since
  // takeDown verifies ownership by deriving a public key from the caller's
  // secret key, a different user's key produces a non-matching key.
  it("does not let users take down someone else's post", () => {
    const simulator = new BBoardSimulator(randomBytes(32));
    simulator.post("I am the one who posted this.");

    // Switch to User B (different secret key).
    simulator.switchUser(randomBytes(32));

    expect(() => simulator.takeDown()).toThrow(
      "failed assert: Attempted to take down post, but not the current owner",
    );
  });

  // ---- Error: posting to an occupied board (same user) ----
  it("does not let the same user post twice", () => {
    const simulator = new BBoardSimulator(randomBytes(32));
    simulator.post("First post.");

    expect(() =>
      simulator.post("Second post attempt."),
    ).toThrow("failed assert: Attempted to post to an occupied board");
  });

  // ---- Error: posting to an occupied board (different user) ----
  it("does not let different users post to an occupied board", () => {
    const simulator = new BBoardSimulator(randomBytes(32));
    simulator.post("Board is now occupied.");

    simulator.switchUser(randomBytes(32));

    expect(() =>
      simulator.post("I want to post too."),
    ).toThrow("failed assert: Attempted to post to an occupied board");
  });

  // ---- Post-takeDown-rePost cycle ----
  //
  // Full lifecycle: post, take down, post again. The sequence counter
  // increments on takeDown, the message updates, and the owner reflects
  // the current poster's public key.
  it("lets you post again after taking down the first message", () => {
    const simulator = new BBoardSimulator(randomBytes(32));
    const initialPrivateState = simulator.getPrivateState();

    simulator.post("First message.");
    simulator.takeDown();

    const secondMessage = "Second message after takedown.";
    simulator.post(secondMessage);

    // Private state unchanged through the entire cycle.
    expect(simulator.getPrivateState()).toEqual(initialPrivateState);

    const state = simulator.getLedger();
    expect(state.state).toEqual(State.OCCUPIED);
    expect(state.sequence).toEqual(2n);
    expect(state.message.is_some).toEqual(true);
    expect(state.message.value).toEqual(secondMessage);
    expect(state.owner).toEqual(simulator.publicKey());
  });

  // ---- Multi-user handoff: User A takes down, User B posts ----
  //
  // After User A takes down their post, the board is VACANT and any user
  // can post. User B's public key becomes the new owner.
  it("lets a different user post after the first user takes down", () => {
    const simulator = new BBoardSimulator(randomBytes(32));
    simulator.post("User A's message.");
    simulator.takeDown();

    simulator.switchUser(randomBytes(32));
    const message = "User B's message after A took down.";
    simulator.post(message);

    const state = simulator.getLedger();
    expect(state.state).toEqual(State.OCCUPIED);
    expect(state.sequence).toEqual(2n);
    expect(state.message.is_some).toEqual(true);
    expect(state.message.value).toEqual(message);
    expect(state.owner).toEqual(simulator.publicKey());
  });

  // ---- Deterministic initialization ----
  it("generates initial ledger state deterministically", () => {
    const key = randomBytes(32);
    const simulator0 = new BBoardSimulator(key);
    const simulator1 = new BBoardSimulator(key);
    expect(simulator0.getLedger()).toEqual(simulator1.getLedger());
  });
});
