// SPDX-License-Identifier: MIT
// OpenZeppelin Compact Contracts (token/test/MultiToken.test.ts)
//
// SECURE PATTERN — witness-derived identity.
//
// This suite was ported from the upstream `@openzeppelin-compact/contracts-simulator`
// harness (which is not vendored into this examples tree) to a self-contained
// Vitest suite that drives the COMPILED MockMultiToken directly via
// `@midnight-ntwrk/compact-runtime`. It requires no extra packages.
//
// What changed vs. the original suite:
//   * Accounts are `UserPublicKey` ({ bytes }) derived from a 32-byte secret,
//     not `Either<ZswapCoinPublicKey, ContractAddress>`. There is therefore no
//     contract-vs-pubkey recipient distinction and no "unsafe transfer to a
//     contract" semantics; those cases were removed.
//   * Caller identity is witness-derived. "Acting as" a caller (`as(secret)`)
//     swaps the private-state identity secret — the SOLE source of caller
//     identity. The old `ownPublicKey()`-spoofing attack is now a DENY case.
//   * Authorized transfers go through `transferFromAuthorized`; the caller's
//     own transfers go through `transfer`.
//
// Build path: set MULTITOKEN_BUILD to the directory produced by
//   `compact compile modules/token/test/mocks/MockMultiToken.compact <dir>`
// (the dir that contains `contract/index.js`). The matching
// `@midnight-ntwrk/compact-runtime` version is pinned by the compiled
// contract's `checkRuntimeVersion(...)` call.

import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { pathToFileURL } from 'node:url';
import { join } from 'node:path';
import {
  createConstructorContext,
  createCircuitContext,
  sampleContractAddress,
} from '@midnight-ntwrk/compact-runtime';

const BUILD_DIR =
  process.env.MULTITOKEN_BUILD ?? '/tmp/multitoken-verify/mock-managed';
const contractModuleUrl = pathToFileURL(
  join(BUILD_DIR, 'contract', 'index.js'),
).href;

// Loaded lazily so the import path can be configured via env.
// biome-ignore lint/suspicious/noExplicitAny: generated module is untyped here
let Contract: any;
// biome-ignore lint/suspicious/noExplicitAny: generated module is untyped here
let pureCircuits: any;
// biome-ignore lint/suspicious/noExplicitAny: generated module is untyped here
let readLedger: any;

// ---- identities -------------------------------------------------------------

const secret = (label: string): Uint8Array => {
  const b = new Uint8Array(32);
  b.set(new TextEncoder().encode(label).subarray(0, 32));
  return b;
};

const ADMIN_SK = secret('admin-deployer');
const OWNER_SK = secret('owner-account');
const SPENDER_SK = secret('spender-account');
const RECIPIENT_SK = secret('recipient-account');
const UNAUTHORIZED_SK = secret('attacker-wrong-secret');

const COIN_PK = '00'.repeat(32); // arbitrary; ownPublicKey() is irrelevant to auth
const ADDR = sampleContractAddress();

// ---- amounts / ids ----------------------------------------------------------

const URI = 'https://uri.com/mock_v1';
const NEW_URI = 'https://uri.com/mock_v2';
const AMOUNT = 250n;
const TOKEN_ID = 1n;
const NONEXISTENT_ID = 987654321n;
const MAX_UINT128 = (1n << 128n) - 1n;

// ---- minimal simulator over the compiled contract ---------------------------

type PS = { userSecretKey: Uint8Array };

class MultiTokenSim {
  // biome-ignore lint/suspicious/noExplicitAny: generated contract is untyped
  private contract: any;
  // biome-ignore lint/suspicious/noExplicitAny: ChargedState | ContractState
  private state: any;
  private caller: Uint8Array = ADMIN_SK;

  constructor(uri: string | null) {
    const witnesses = {
      getUserSecret: ({ privateState }: { privateState: PS }) => [
        privateState,
        { bytes: privateState.userSecretKey },
      ],
    };
    this.contract = new Contract(witnesses);
    const isSome = uri !== null;
    const ctorArg = { is_some: isSome, value: uri ?? '' };
    const cctx = createConstructorContext(
      { userSecretKey: ADMIN_SK } as PS,
      COIN_PK,
    );
    const res = this.contract.initialState(cctx, ctorArg);
    this.state = res.currentContractState;
  }

  /** Switch the simulated caller (sets the private-state identity secret). */
  as(secretKey: Uint8Array): this {
    this.caller = secretKey;
    return this;
  }

  // biome-ignore lint/suspicious/noExplicitAny: variadic circuit args
  private invoke(name: string, ...args: any[]): unknown {
    const ctx = createCircuitContext(ADDR, COIN_PK, this.state, {
      userSecretKey: this.caller,
    } as PS);
    const r = this.contract.impureCircuits[name](ctx, ...args);
    this.state = r.context.currentQueryContext.state;
    // reset to admin between calls unless the test re-specifies via .as()
    return r.result;
  }

  get adminPin(): string {
    const lg = readLedger(this.state.data ?? this.state);
    return Buffer.from(lg.contractAdmin.bytes).toString('hex');
  }

  initialize(uri: string) {
    this.invoke('initialize', uri);
  }
  uri(id: bigint): string {
    return this.invoke('uri', id) as string;
  }
  balanceOf(account: { bytes: Uint8Array }, id: bigint): bigint {
    return this.invoke('balanceOf', account, id) as bigint;
  }
  isApprovedForAll(
    account: { bytes: Uint8Array },
    operator: { bytes: Uint8Array },
  ): boolean {
    return this.invoke('isApprovedForAll', account, operator) as boolean;
  }
  setApprovalForAll(operator: { bytes: Uint8Array }, approved: boolean) {
    this.invoke('setApprovalForAll', operator, approved);
  }
  transfer(to: { bytes: Uint8Array }, id: bigint, value: bigint) {
    this.invoke('transfer', to, id, value);
  }
  transferFromAuthorized(
    fromAddress: { bytes: Uint8Array },
    to: { bytes: Uint8Array },
    id: bigint,
    value: bigint,
  ) {
    this.invoke('transferFromAuthorized', fromAddress, to, id, value);
  }
  _mint(to: { bytes: Uint8Array }, id: bigint, value: bigint) {
    this.invoke('_mint', to, id, value);
  }
  _burn(fromAddress: { bytes: Uint8Array }, id: bigint, value: bigint) {
    this.invoke('_burn', fromAddress, id, value);
  }
  _transfer(
    fromAddress: { bytes: Uint8Array },
    to: { bytes: Uint8Array },
    id: bigint,
    value: bigint,
  ) {
    this.invoke('_transfer', fromAddress, to, id, value);
  }
  _setURI(uri: string) {
    this.invoke('_setURI', uri);
  }
  _setApprovalForAll(
    owner: { bytes: Uint8Array },
    operator: { bytes: Uint8Array },
    approved: boolean,
  ) {
    this.invoke('_setApprovalForAll', owner, operator, approved);
  }
}

// Derived public keys (computed off-chain exactly as the circuit derives them).
let OWNER: { bytes: Uint8Array };
let SPENDER: { bytes: Uint8Array };
let RECIPIENT: { bytes: Uint8Array };
let UNAUTHORIZED: { bytes: Uint8Array };

let token: MultiTokenSim;

beforeEach(async () => {
  const mod = await import(contractModuleUrl);
  Contract = mod.Contract;
  pureCircuits = mod.pureCircuits;
  readLedger = mod.ledger;
  OWNER = pureCircuits.MultiToken_deriveUserPublicKey({ bytes: OWNER_SK });
  SPENDER = pureCircuits.MultiToken_deriveUserPublicKey({ bytes: SPENDER_SK });
  RECIPIENT = pureCircuits.MultiToken_deriveUserPublicKey({ bytes: RECIPIENT_SK });
  UNAUTHORIZED = pureCircuits.MultiToken_deriveUserPublicKey({
    bytes: UNAUTHORIZED_SK,
  });
});

describe('MultiToken (witness-derived identity)', () => {
  describe('deploy / metadata', () => {
    it('initializes metadata and pins the admin to the deployer', () => {
      token = new MultiTokenSim(URI);
      expect(token.uri(TOKEN_ID)).toEqual(URI);

      const expectedAdmin = Buffer.from(
        pureCircuits.MultiToken_deriveAdminPublicKey({ bytes: ADMIN_SK }).bytes,
      ).toString('hex');
      expect(token.adminPin).toEqual(expectedAdmin);
    });

    it('cannot be re-initialized', () => {
      token = new MultiTokenSim(URI);
      expect(() => token.initialize(URI)).toThrow(
        'Initializable: contract already initialized',
      );
    });

    it('rejects circuits before initialization', () => {
      token = new MultiTokenSim(null);
      expect(() => token.balanceOf(OWNER, TOKEN_ID)).toThrow(
        'Initializable: contract not initialized',
      );
    });
  });

  describe('balanceOf', () => {
    beforeEach(() => {
      token = new MultiTokenSim(URI);
    });

    it('returns zero for an account with no balance', () => {
      expect(token.balanceOf(OWNER, TOKEN_ID)).toEqual(0n);
    });

    it('returns the balance after minting', () => {
      token._mint(OWNER, TOKEN_ID, AMOUNT);
      expect(token.balanceOf(OWNER, TOKEN_ID)).toEqual(AMOUNT);
    });

    it('handles MAX_UINT128 amounts', () => {
      token._mint(OWNER, TOKEN_ID, MAX_UINT128);
      expect(token.balanceOf(OWNER, TOKEN_ID)).toEqual(MAX_UINT128);
    });
  });

  describe('setApprovalForAll / isApprovedForAll', () => {
    beforeEach(() => {
      token = new MultiTokenSim(URI);
    });

    it('is false by default', () => {
      expect(token.isApprovedForAll(OWNER, SPENDER)).toBe(false);
    });

    it('approves and revokes an operator (caller-derived owner)', () => {
      token.as(OWNER_SK).setApprovalForAll(SPENDER, true);
      expect(token.isApprovedForAll(OWNER, SPENDER)).toBe(true);

      token.as(OWNER_SK).setApprovalForAll(SPENDER, false);
      expect(token.isApprovedForAll(OWNER, SPENDER)).toBe(false);
    });

    it('rejects the zero operator', () => {
      const ZERO = { bytes: new Uint8Array(32) };
      expect(() => token.as(OWNER_SK).setApprovalForAll(ZERO, true)).toThrow(
        'MultiToken: invalid operator',
      );
    });
  });

  describe('transfer (caller is the owner)', () => {
    beforeEach(() => {
      token = new MultiTokenSim(URI);
      token._mint(OWNER, TOKEN_ID, AMOUNT);
    });

    it('transfers the whole balance', () => {
      token.as(OWNER_SK).transfer(RECIPIENT, TOKEN_ID, AMOUNT);
      expect(token.balanceOf(OWNER, TOKEN_ID)).toEqual(0n);
      expect(token.balanceOf(RECIPIENT, TOKEN_ID)).toEqual(AMOUNT);
    });

    it('transfers a partial balance', () => {
      token.as(OWNER_SK).transfer(RECIPIENT, TOKEN_ID, AMOUNT - 1n);
      expect(token.balanceOf(OWNER, TOKEN_ID)).toEqual(1n);
      expect(token.balanceOf(RECIPIENT, TOKEN_ID)).toEqual(AMOUNT - 1n);
    });

    it('fails with insufficient balance', () => {
      expect(() =>
        token.as(OWNER_SK).transfer(RECIPIENT, TOKEN_ID, AMOUNT + 1n),
      ).toThrow('MultiToken: insufficient balance');
    });
  });

  describe('transferFromAuthorized (approved operator)', () => {
    beforeEach(() => {
      token = new MultiTokenSim(URI);
      token._mint(OWNER, TOKEN_ID, AMOUNT);
      token.as(OWNER_SK).setApprovalForAll(SPENDER, true);
    });

    it('lets an approved operator move the owner tokens', () => {
      token
        .as(SPENDER_SK)
        .transferFromAuthorized(OWNER, RECIPIENT, TOKEN_ID, AMOUNT);
      expect(token.balanceOf(OWNER, TOKEN_ID)).toEqual(0n);
      expect(token.balanceOf(RECIPIENT, TOKEN_ID)).toEqual(AMOUNT);
    });

    it('stops working after the operator is revoked', () => {
      token.as(OWNER_SK).setApprovalForAll(SPENDER, false);
      expect(() =>
        token
          .as(SPENDER_SK)
          .transferFromAuthorized(OWNER, RECIPIENT, TOKEN_ID, 1n),
      ).toThrow('MultiToken: unauthorized operator');
    });
  });

  // The core of the security rework: a caller holding the WRONG secret can no
  // longer impersonate the owner/operator. Under the old ownPublicKey() design
  // they could supply the owner's coin pk; here identity is derived in-circuit.
  describe('DENY: ownPublicKey() impersonation is closed', () => {
    beforeEach(() => {
      token = new MultiTokenSim(URI);
      token._mint(OWNER, TOKEN_ID, AMOUNT);
    });

    it('rejects an unauthorized caller moving the owner tokens', () => {
      expect(() =>
        token
          .as(UNAUTHORIZED_SK)
          .transferFromAuthorized(OWNER, UNAUTHORIZED, TOKEN_ID, AMOUNT),
      ).toThrow('MultiToken: unauthorized operator');
    });

    it('rejects an unauthorized caller even for a zero-value transfer', () => {
      expect(() =>
        token
          .as(UNAUTHORIZED_SK)
          .transferFromAuthorized(OWNER, UNAUTHORIZED, TOKEN_ID, 0n),
      ).toThrow('MultiToken: unauthorized operator');
    });

    it('an approval set by the attacker does not authorize them over the owner', () => {
      // The attacker can only approve operators for THEIR OWN account; doing so
      // grants no power over the owner's balance.
      token.as(UNAUTHORIZED_SK).setApprovalForAll(UNAUTHORIZED, true);
      expect(() =>
        token
          .as(UNAUTHORIZED_SK)
          .transferFromAuthorized(OWNER, UNAUTHORIZED, TOKEN_ID, AMOUNT),
      ).toThrow('MultiToken: unauthorized operator');
    });
  });

  describe('_mint / _burn (unauthenticated building blocks)', () => {
    beforeEach(() => {
      token = new MultiTokenSim(URI);
    });

    it('mints and burns', () => {
      token._mint(OWNER, TOKEN_ID, AMOUNT);
      expect(token.balanceOf(OWNER, TOKEN_ID)).toEqual(AMOUNT);
      token._burn(OWNER, TOKEN_ID, AMOUNT);
      expect(token.balanceOf(OWNER, TOKEN_ID)).toEqual(0n);
    });

    it('rejects minting to the zero account', () => {
      const ZERO = { bytes: new Uint8Array(32) };
      expect(() => token._mint(ZERO, TOKEN_ID, AMOUNT)).toThrow(
        'MultiToken: invalid receiver',
      );
    });

    it('rejects overflow on mint', () => {
      token._mint(OWNER, TOKEN_ID, MAX_UINT128);
      expect(() => token._mint(OWNER, TOKEN_ID, 1n)).toThrow(
        'MultiToken: arithmetic overflow',
      );
    });

    it('rejects burning more than the balance', () => {
      token._mint(OWNER, TOKEN_ID, AMOUNT);
      expect(() => token._burn(OWNER, TOKEN_ID, AMOUNT + 1n)).toThrow(
        'MultiToken: insufficient balance',
      );
    });

    it('rejects burning a nonexistent id', () => {
      token._mint(OWNER, TOKEN_ID, AMOUNT);
      expect(() => token._burn(OWNER, NONEXISTENT_ID, AMOUNT)).toThrow(
        'MultiToken: insufficient balance',
      );
    });
  });

  describe('_setURI', () => {
    beforeEach(() => {
      token = new MultiTokenSim(URI);
    });

    it('updates the URI', () => {
      token._setURI(NEW_URI);
      expect(token.uri(TOKEN_ID)).toEqual(NEW_URI);
    });
  });
});

afterEach(() => {
  // nothing to tear down; each test builds a fresh in-memory contract
});
