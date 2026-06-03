// SPDX-License-Identifier: MIT
//
// Self-contained test harness for the SECURE PATTERN (witness-derived identity)
// modules. Drives a compiled Mock contract through @midnight-ntwrk/compact-runtime
// — no external simulator framework required. Each "actor" is a 32-byte secret;
// `as(secret)` selects which secret the witness `getUserSecret()` returns for the
// next call, so a call is authorized as whoever holds that secret.
//
// This replaces the old `ownPublicKey()`-injection model (`.as(address)`): in the
// secure design a caller cannot impersonate another identity by supplying its
// address — identity is the witness secret, derived inside the ZK circuit.

import {
  createConstructorContext,
  createCircuitContext,
  dummyContractAddress,
} from "@midnight-ntwrk/compact-runtime";

const ADDR = dummyContractAddress();
const COIN_PK = "0".repeat(64);

/** A 32-byte secret built from a single fill byte (deterministic per actor). */
export const secretOf = (fillByte: number): Uint8Array =>
  new Uint8Array(32).fill(fillByte);

/** Hex helper for assertions on derived keys / role ids. */
export const toHex = (u8: Uint8Array): string =>
  Buffer.from(u8).toString("hex");

type Witnesses = {
  getUserSecret: (ctx: { privateState: { userSecretKey: Uint8Array } }) => [
    { userSecretKey: Uint8Array },
    { bytes: Uint8Array },
  ];
};

const witnesses: Witnesses = {
  getUserSecret: ({ privateState }) => [
    privateState,
    { bytes: privateState.userSecretKey },
  ],
};

const ps = (secret: Uint8Array) => ({ userSecretKey: secret });

/**
 * A thin simulator over a compiled Mock contract. Construct with the contract's
 * `Contract` class, `ledger` reader, the deployer secret, and constructor args.
 * Use `as(secret).<circuit>(...)` to call as a given actor; reads can be done
 * via `read.<circuit>(...)`.
 */
export class SecureSim<C extends { circuits: Record<string, any> }, L> {
  private state: any;
  private active: Uint8Array;
  readonly contract: C;
  readonly ledgerReader: (data: any) => L;

  constructor(
    ContractClass: new (w: Witnesses) => C,
    ledgerReader: (data: any) => L,
    deployerSecret: Uint8Array,
    ...ctorArgs: unknown[]
  ) {
    this.contract = new ContractClass(witnesses);
    this.ledgerReader = ledgerReader;
    this.active = deployerSecret;
    const deploy = (this.contract as any).initialState(
      createConstructorContext(ps(deployerSecret), COIN_PK),
      ...ctorArgs
    );
    this.state = deploy.currentContractState;
  }

  /** Select the secret used for the NEXT call, then return this for chaining. */
  as(secret: Uint8Array): this {
    this.active = secret;
    return this;
  }

  /** Current ledger view. */
  ledger(): L {
    return this.ledgerReader(this.state.data);
  }

  /** Call a state-mutating circuit; commits the evolved state on success. */
  call(name: string, ...args: unknown[]): any {
    const ctx = createCircuitContext(ADDR, COIN_PK, this.state, ps(this.active));
    const res = (this.contract as any).circuits[name](ctx, ...args);
    this.state = res.context.currentQueryContext.state;
    return res.result;
  }

  /** Call a read-only circuit WITHOUT committing state (safe for views). */
  read(name: string, ...args: unknown[]): any {
    const ctx = createCircuitContext(ADDR, COIN_PK, this.state, ps(this.active));
    const res = (this.contract as any).circuits[name](ctx, ...args);
    return res.result;
  }
}
