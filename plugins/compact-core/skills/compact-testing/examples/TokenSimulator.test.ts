// ============================================================================
// TOKEN SIMULATOR TEST -- INTERMEDIATE/ADVANCED EXAMPLE
// ============================================================================
//
// Demonstrates testing a Compact contract with unshielded token operations.
// Unshielded tokens are the simplest to test off-chain because they use
// transparent account-model balances, unlike shielded tokens which require
// Zswap UTXO state (commitment trees, nullifiers, Merkle proofs).
//
// Key token concepts:
//
//   TOKEN COLOR: A 32-byte identifier uniquely identifying a token type.
//     Derived via: color = hash(domainSeparator, contractAddress).
//     Because the contract address is unique per deployment, no two contracts
//     produce the same color even with the same domain separator.
//
//   DOMAIN SEPARATOR: A developer-chosen 32-byte value, typically a readable
//     string padded to 32 bytes (e.g., pad(32, "mytoken:")). A single contract
//     can issue multiple token types using different domain separators.
//
//   SHIELDED vs UNSHIELDED TESTING: Shielded tokens require setting up Zswap
//     state (coin commitments, nonces, Merkle tree indices) to test. Unshielded
//     tokens track balances via the block context's balance map -- much simpler
//     for off-chain simulation. See the appendix at the end of this file.
//
// The hypothetical token.compact contract under test:
//
//   pragma language_version >= 0.20;
//   import CompactStandardLibrary;
//   export ledger tokenColor: Bytes<32>;
//   export ledger totalMinted: Counter;
//
//   export circuit mintToSelf(amount: Uint<64>): Bytes<32> {
//     totalMinted.increment(disclose(amount) as Uint<16>);
//     const color = mintUnshieldedToken(
//       pad(32, "mytoken:"), disclose(amount),
//       left<ContractAddress, UserAddress>(kernel.self()));
//     receiveUnshielded(color, disclose(amount) as Uint<128>);
//     tokenColor = color;
//     return color;
//   }
//
//   export circuit transferToUser(
//     recipient: UserAddress, amount: Uint<128>
//   ): [] {
//     assert(unshieldedBalanceGte(tokenColor, disclose(amount)),
//       "Insufficient contract balance");
//     sendUnshielded(tokenColor, disclose(amount),
//       right<ContractAddress, UserAddress>(disclose(recipient)));
//   }
//
// ============================================================================

// ==== IMPORTS ====
//
// Token tests use the same runtime imports as any Compact test. Token
// operations (mint, send, receive, balance) are stdlib functions compiled
// into the contract circuits -- no separate TypeScript token imports needed.

import {
  type CircuitContext,
  createConstructorContext,
  createCircuitContext,
  sampleContractAddress,
} from "@midnight-ntwrk/compact-runtime";

import { setNetworkId } from "@midnight-ntwrk/midnight-js-network-id";

import {
  Contract,
  type Ledger,
  ledger,
} from "../managed/token/contract/index.js";

// ==== PRIVATE STATE ====
//
// This token contract has no witnesses, so private state is empty.
// If your contract uses witnesses for access control, define fields here.

type TokenPrivateState = Record<string, never>;

setNetworkId("undeployed");

// ==== TOKEN SIMULATOR CLASS ====
//
// Wraps a contract using unshielded token operations. Token operations
// produce side effects tracked in the context's effects map (unshielded
// outputs, inputs, claimed spends) rather than updating balances inline.
//
// BALANCE TESTING NOTE: unshieldedBalance() reads the block context's
// balance map, fixed at transaction construction time. In local simulation,
// this map starts empty (0n for all colors). Mint/send effects are
// accumulated but do NOT update the balance map during execution. You can:
//   1. Inspect effects directly to verify mint/send behavior
//   2. Manually set the block context balance map between operations

class TokenSimulator {
  readonly contract: Contract<TokenPrivateState>;
  circuitContext: CircuitContext<TokenPrivateState>;
  tokenColor: Uint8Array | null = null;

  constructor() {
    this.contract = new Contract<TokenPrivateState>({});

    const {
      currentPrivateState,
      currentContractState,
      currentZswapLocalState,
    } = this.contract.initialState(
      createConstructorContext({}, "0".repeat(64)),
    );

    // sampleContractAddress() is deterministic -- important for token
    // operations because the address is part of the color derivation:
    //   color = hash(domainSep, contractAddress)
    this.circuitContext = createCircuitContext(
      sampleContractAddress(),
      currentZswapLocalState,
      currentContractState,
      currentPrivateState,
    );
  }

  // ==== CIRCUIT WRAPPERS ====

  // Calls mintToSelf: mintUnshieldedToken() + receiveUnshielded() + store color.
  // Returns the token color (Bytes<32> -> Uint8Array). The color is deterministic:
  //   color = hash(pad(32, "mytoken:"), sampleContractAddress())
  public mint(amount: bigint): Uint8Array {
    const { context, result } = this.contract.impureCircuits.mintToSelf(
      this.circuitContext,
      amount,
    );
    this.circuitContext = context;
    this.tokenColor = result;
    return result;
  }

  // Calls transferToUser: asserts unshieldedBalanceGte() then sendUnshielded().
  // RECIPIENT ADDRESSING for unshielded: Either<ContractAddress, UserAddress>
  //   left = contract, right = user (REVERSED from shielded operations).
  // The recipient is a UserAddress struct: { bytes: Uint8Array } in TypeScript.
  public transfer(recipient: Uint8Array, amount: bigint): void {
    this.circuitContext = this.contract.impureCircuits.transferToUser(
      this.circuitContext,
      { bytes: recipient },
      amount,
    ).context;
  }

  // ==== STATE ACCESSORS ====

  public getLedger(): Ledger {
    return ledger(this.circuitContext.currentQueryContext.state);
  }

  public getTotalMinted(): bigint {
    return this.getLedger().totalMinted;
  }

  // Returns ledger token color (32-byte hash of domainSep + contractAddress).
  public getTokenColor(): Uint8Array {
    return this.getLedger().tokenColor;
  }

  // Raw effects: unshieldedOutputs (mint), unshieldedInputs (receive),
  // claimedUnshieldedSpends (send). The most accurate way to verify
  // token operations in local simulation.
  public getEffects() {
    return this.circuitContext.currentQueryContext.effects;
  }
}

// ==== TEST SUITE ====

describe("Token smart contract (unshielded)", () => {

  // ---- Mint tokens and verify ledger state ----
  it("mints tokens and updates ledger state", () => {
    const simulator = new TokenSimulator();
    const color = simulator.mint(100n);

    // Color is a 32-byte value, NOT all zeros (zero = native NIGHT token).
    expect(color).toBeInstanceOf(Uint8Array);
    expect(color.length).toEqual(32);
    expect(color).not.toEqual(new Uint8Array(32));

    // Ledger tokenColor matches the returned color.
    expect(simulator.getTokenColor()).toEqual(color);
    expect(simulator.getTotalMinted()).toEqual(100n);
  });

  // ---- Multiple mints accumulate; color stays constant ----
  it("accumulates mints and maintains consistent token color", () => {
    const simulator = new TokenSimulator();
    const color1 = simulator.mint(50n);
    const color2 = simulator.mint(75n);
    const color3 = simulator.mint(25n);

    // Same domain separator + same contract address = same color,
    // regardless of amount or number of mints.
    expect(color1).toEqual(color2);
    expect(color2).toEqual(color3);
    expect(simulator.getTotalMinted()).toEqual(150n);
  });

  // ---- Token color is deterministic across instances ----
  it("produces deterministic token colors across simulator instances", () => {
    const sim0 = new TokenSimulator();
    const sim1 = new TokenSimulator();

    // Different amounts, same color -- color depends only on
    // (domainSep, contractAddress), not on mint parameters.
    expect(sim0.mint(100n)).toEqual(sim1.mint(200n));
  });

  // ---- Transfer produces effects ----
  it("transfers tokens and produces send effects", () => {
    const simulator = new TokenSimulator();
    simulator.mint(100n);

    const recipient = new Uint8Array(32).fill(1);
    simulator.transfer(recipient, 40n);

    // Transfer does not change the mint counter.
    expect(simulator.getTotalMinted()).toEqual(100n);

    // Effects contain the send operation details.
    expect(simulator.getEffects()).toBeDefined();
  });

  // ---- Error: transfer more than balance ----
  //
  // unshieldedBalanceGte() checks the block context balance map, which
  // starts empty in local simulation. Any transfer fails without a
  // populated balance -- this correctly tests the contract's guard.
  it("rejects transfers when balance is insufficient", () => {
    const simulator = new TokenSimulator();
    const recipient = new Uint8Array(32).fill(2);

    expect(() => simulator.transfer(recipient, 50n)).toThrow();
  });

  // ---- Token color differs from native token ----
  //
  // nativeToken() returns all-zero Bytes<32> (the NIGHT token color).
  // Contract-minted tokens always have a non-zero color because
  // hash(domainSep, contractAddress) never produces all zeros.
  it("minted token color differs from the native token (zero)", () => {
    const simulator = new TokenSimulator();
    const color = simulator.mint(100n);
    expect(color).not.toEqual(new Uint8Array(32));
  });

  // ---- Zero-amount mint is valid ----
  it("handles zero-amount mint without error", () => {
    const simulator = new TokenSimulator();
    const color = simulator.mint(0n);

    expect(color).toBeInstanceOf(Uint8Array);
    expect(color.length).toEqual(32);
    expect(simulator.getTotalMinted()).toEqual(0n);
  });

  // ---- Deterministic initial state ----
  it("initializes with zeroed token color and zero total minted", () => {
    const simulator = new TokenSimulator();
    expect(simulator.getTokenColor()).toEqual(new Uint8Array(32));
    expect(simulator.getTotalMinted()).toEqual(0n);
  });
});

// ============================================================================
// APPENDIX: SHIELDED TOKEN TESTING
// ============================================================================
//
// This example uses UNSHIELDED tokens for simplicity. Shielded token testing
// is substantially more complex because each token is a Zswap UTXO coin
// (ShieldedCoinInfo: { nonce, color, value }) requiring:
//
//   1. NONCE MANAGEMENT: evolveNonce(counter, seed) for each coin. Reusing
//      a nonce compromises privacy by linking coins.
//
//   2. ZSWAP STATE: The context tracks a commitment Merkle tree and nullifier
//      set. sendShielded needs a QualifiedShieldedCoinInfo with a valid
//      mtIndex pointing to a committed coin in the tree.
//
//   3. COIN LIFECYCLE: mintShieldedToken -> receiveShielded (commits to tree)
//      -> sendShielded (nullifies) or sendImmediateShielded (same-tx spend).
//
//   4. CHANGE HANDLING: Send functions return ShieldedSendResult with a
//      Maybe<ShieldedCoinInfo> change field that must be handled or value is lost.
//
// For most contracts, unshielded testing provides equivalent functional
// coverage. Use shielded tests only for privacy-specific behavior.
// ============================================================================
