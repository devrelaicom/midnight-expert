// SPDX-License-Identifier: MIT
//
// SECURE PATTERN — witness-derived identity. FungibleToken module tests.
//
// Accounts are keyed by a DERIVED UserPublicKey. For transfer/approve/
// transferFrom the caller (owner/spender) is derived from the witness secret
// inside the ZK circuit — there is no `ownPublicKey()` caller injection, so an
// actor cannot spend another account's balance by naming it.
//
// PORT NOTE: the previous suite depended on the external
// `@openzeppelin-compact/contracts-simulator` package, an `artifacts/` build
// dir, a `#test-utils/address.js` import map, and the `.as(address)` caller
// model. Contract-address cases and `_unsafe*` variants no longer exist
// (accounts are derived 32-byte keys, not routable addresses) and have been
// dropped. The suite is now self-contained and runs against
// @midnight-ntwrk/compact-runtime.
//
// Build the mock first:
//   compact compile modules/token/test/mocks/MockFungibleToken.compact \
//     modules/token/test/managed/MockFungibleToken

import { beforeEach, describe, expect, it } from "vitest";
import { FungibleTokenSimulator } from "./simulators/FungibleTokenSimulator.js";
import { secretOf } from "../../test-utils/secure-identity-sim.js";

const HOLDER = secretOf(1); // deployer / first holder
const SPENDER = secretOf(2);
const RECIPIENT = secretOf(3);
const OTHER = secretOf(9);

const userKey = FungibleTokenSimulator.userKey;
const ZERO_KEY = { bytes: new Uint8Array(32) };

const NAME = "TestToken";
const SYMBOL = "TT";
const DECIMALS = 6n;

let token: FungibleTokenSimulator;

const newInitialized = () =>
  new FungibleTokenSimulator(HOLDER, NAME, SYMBOL, DECIMALS, true);

describe("FungibleToken (secure, witness-derived identity)", () => {
  describe("before initialized", () => {
    it("guards views until initialized", () => {
      token = new FungibleTokenSimulator(HOLDER, NAME, SYMBOL, DECIMALS, false);
      expect(() => token.name()).toThrow(
        "Initializable: contract not initialized"
      );
      expect(() => token.totalSupply()).toThrow(
        "Initializable: contract not initialized"
      );
    });
  });

  describe("when initialized", () => {
    beforeEach(() => {
      token = newInitialized();
    });

    describe("metadata", () => {
      it("returns name, symbol, decimals", () => {
        expect(token.name()).toEqual(NAME);
        expect(token.symbol()).toEqual(SYMBOL);
        expect(token.decimals()).toEqual(DECIMALS);
      });
    });

    describe("_mint / balanceOf / totalSupply", () => {
      it("mints to an account and tracks supply", () => {
        token._mint(userKey(HOLDER), 1000n);
        expect(token.balanceOf(userKey(HOLDER))).toEqual(1000n);
        expect(token.totalSupply()).toEqual(1000n);
      });

      it("returns 0 balance for an unknown account", () => {
        expect(token.balanceOf(userKey(OTHER))).toEqual(0n);
      });

      it("rejects minting to the zero key", () => {
        expect(() => token._mint(ZERO_KEY, 1n)).toThrow(
          "FungibleToken: invalid receiver"
        );
      });
    });

    describe("transfer", () => {
      beforeEach(() => {
        token._mint(userKey(HOLDER), 1000n);
      });

      it("transfers from the witness-derived caller to the recipient", () => {
        token.as(HOLDER).transfer(userKey(RECIPIENT), 400n);
        expect(token.balanceOf(userKey(HOLDER))).toEqual(600n);
        expect(token.balanceOf(userKey(RECIPIENT))).toEqual(400n);
      });

      it("fails when the caller has insufficient balance", () => {
        // OTHER has no balance; the caller is derived from OTHER's secret.
        expect(() => token.as(OTHER).transfer(userKey(RECIPIENT), 1n)).toThrow(
          "FungibleToken: insufficient balance"
        );
      });

      it("IMPERSONATION: an actor cannot spend HOLDER's balance by naming it", () => {
        // `transfer` only takes a recipient; the `from` is the caller derived
        // from OTHER's secret, which has no balance — so this fails on balance,
        // never touching HOLDER's funds.
        expect(() =>
          token.as(OTHER).transfer(userKey(RECIPIENT), 100n)
        ).toThrow("FungibleToken: insufficient balance");
        expect(token.balanceOf(userKey(HOLDER))).toEqual(1000n);
      });

      it("rejects transfer to the zero key", () => {
        expect(() => token.as(HOLDER).transfer(ZERO_KEY, 1n)).toThrow(
          "FungibleToken: invalid receiver"
        );
      });
    });

    describe("approve / allowance / transferFrom", () => {
      beforeEach(() => {
        token._mint(userKey(HOLDER), 1000n);
      });

      it("approve sets the caller's allowance for a spender", () => {
        token.as(HOLDER).approve(userKey(SPENDER), 250n);
        expect(token.allowance(userKey(HOLDER), userKey(SPENDER))).toEqual(250n);
      });

      it("transferFrom spends the caller's allowance over from-account", () => {
        token.as(HOLDER).approve(userKey(SPENDER), 250n);
        token.as(SPENDER).transferFrom(userKey(HOLDER), userKey(RECIPIENT), 200n);
        expect(token.balanceOf(userKey(HOLDER))).toEqual(800n);
        expect(token.balanceOf(userKey(RECIPIENT))).toEqual(200n);
        expect(token.allowance(userKey(HOLDER), userKey(SPENDER))).toEqual(50n);
      });

      it("fails transferFrom without sufficient allowance", () => {
        token.as(HOLDER).approve(userKey(SPENDER), 100n);
        expect(() =>
          token
            .as(SPENDER)
            .transferFrom(userKey(HOLDER), userKey(RECIPIENT), 200n)
        ).toThrow("FungibleToken: insufficient allowance");
      });

      it("IMPERSONATION: an actor with no allowance cannot transferFrom", () => {
        // OTHER was never approved. The spender is derived from OTHER's secret,
        // so naming HOLDER as the from-account does not grant an allowance.
        expect(() =>
          token
            .as(OTHER)
            .transferFrom(userKey(HOLDER), userKey(RECIPIENT), 100n)
        ).toThrow("FungibleToken: insufficient allowance");
        expect(token.balanceOf(userKey(HOLDER))).toEqual(1000n);
      });
    });

    describe("_burn", () => {
      beforeEach(() => {
        token._mint(userKey(HOLDER), 1000n);
      });

      it("burns from an account and lowers supply", () => {
        token._burn(userKey(HOLDER), 400n);
        expect(token.balanceOf(userKey(HOLDER))).toEqual(600n);
        expect(token.totalSupply()).toEqual(600n);
      });

      it("rejects burning more than the balance", () => {
        expect(() => token._burn(userKey(HOLDER), 2000n)).toThrow(
          "FungibleToken: insufficient balance"
        );
      });
    });
  });
});
