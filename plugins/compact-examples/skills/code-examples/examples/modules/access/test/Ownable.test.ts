// SPDX-License-Identifier: MIT
//
// SECURE PATTERN — witness-derived identity. Ownable module tests.
//
// These tests exercise the reworked Ownable: ownership is an AdminPublicKey
// pinned at deploy from the deployer's witness secret, and authorization derives
// the caller from the witness secret inside the ZK circuit. There is no
// `ownPublicKey()` caller injection: an actor cannot impersonate the owner by
// supplying the owner's key as an argument — only the secret holder can produce
// the owner's derived admin key.
//
// PORT NOTE: the previous version of this suite depended on the external
// `@openzeppelin-compact/contracts-simulator` package, an `artifacts/` build
// dir, a `#test-utils/address.js` import map, and the `.as(address)` caller
// model — all of which the secure rework removes. The contract-address-rejection
// and `_unsafe*` cases no longer exist (accounts are derived 32-byte keys, not
// routable addresses), so they have been dropped. The suite is now self-contained
// and runs against @midnight-ntwrk/compact-runtime.
//
// Build the mock first:
//   compact compile modules/access/test/mocks/MockOwnable.compact \
//     modules/access/test/managed/MockOwnable

import { beforeEach, describe, expect, it } from "vitest";
import { OwnableSimulator } from "./simulators/OwnableSimulator.js";
import { secretOf, toHex } from "../../test-utils/secure-identity-sim.js";

const OWNER = secretOf(1);
const NEW_OWNER = secretOf(2);
const UNAUTHORIZED = secretOf(9);

const isInit = true;
const isBadInit = false;

let ownable: OwnableSimulator;

describe("Ownable (secure, witness-derived identity)", () => {
  describe("before initialized", () => {
    it("should initialize and pin the deployer's derived admin key as owner", () => {
      ownable = new OwnableSimulator(OWNER, isInit);
      expect(toHex(ownable.owner().bytes)).toEqual(
        toHex(OwnableSimulator.adminKey(OWNER).bytes)
      );
    });

    type FailingCircuits = [method: keyof OwnableSimulator, args: unknown[]];
    const circuitsToFail: FailingCircuits[] = [
      ["owner", []],
      ["assertOnlyOwner", []],
      ["transferOwnership", [OwnableSimulator.adminKey(NEW_OWNER)]],
      ["renounceOwnership", []],
      ["_transferOwnership", [OwnableSimulator.adminKey(NEW_OWNER)]],
    ];
    it.each(circuitsToFail)(
      'should fail when calling circuit "%s" before initialization',
      (circuitName, args) => {
        ownable = new OwnableSimulator(OWNER, isBadInit);
        expect(() => {
          (ownable[circuitName] as (...a: unknown[]) => unknown)(...args);
        }).toThrow("Initializable: contract not initialized");
      }
    );
  });

  describe("when initialized", () => {
    beforeEach(() => {
      ownable = new OwnableSimulator(OWNER, isInit);
    });

    describe("owner", () => {
      it("should return the owner's derived admin key", () => {
        expect(toHex(ownable.owner().bytes)).toEqual(
          toHex(OwnableSimulator.adminKey(OWNER).bytes)
        );
      });

      it("should return the zero key when unowned", () => {
        ownable._transferOwnership({ bytes: new Uint8Array(32) });
        expect(toHex(ownable.owner().bytes)).toEqual(toHex(new Uint8Array(32)));
      });
    });

    describe("assertOnlyOwner", () => {
      it("should allow the owner (secret holder) to call", () => {
        expect(() => {
          ownable.as(OWNER).assertOnlyOwner();
        }).not.toThrow();
      });

      it("should fail when called by an unauthorized actor", () => {
        expect(() => {
          ownable.as(UNAUTHORIZED).assertOnlyOwner();
        }).toThrow("Ownable: caller is not the owner");
      });
    });

    describe("transferOwnership", () => {
      it("should transfer ownership to the new owner's derived key", () => {
        ownable.as(OWNER).transferOwnership(OwnableSimulator.adminKey(NEW_OWNER));
        expect(toHex(ownable.owner().bytes)).toEqual(
          toHex(OwnableSimulator.adminKey(NEW_OWNER).bytes)
        );

        // Old owner can no longer act.
        expect(() => ownable.as(OWNER).assertOnlyOwner()).toThrow(
          "Ownable: caller is not the owner"
        );
        // New owner (secret holder) can.
        expect(() => ownable.as(NEW_OWNER).assertOnlyOwner()).not.toThrow();
      });

      it("should fail when an unauthorized actor transfers ownership", () => {
        expect(() => {
          ownable
            .as(UNAUTHORIZED)
            .transferOwnership(OwnableSimulator.adminKey(NEW_OWNER));
        }).toThrow("Ownable: caller is not the owner");
      });

      it("IMPERSONATION: unauthorized actor naming the owner's key is still rejected", () => {
        // The old ownPublicKey() bypass relied on supplying the target identity.
        // Here authorization derives from the UNAUTHORIZED secret, so naming the
        // owner's key as newOwner does not help.
        expect(() => {
          ownable
            .as(UNAUTHORIZED)
            .transferOwnership(OwnableSimulator.adminKey(UNAUTHORIZED));
        }).toThrow("Ownable: caller is not the owner");
      });

      it("should fail when transferring to the zero key", () => {
        expect(() => {
          ownable.as(OWNER).transferOwnership({ bytes: new Uint8Array(32) });
        }).toThrow("Ownable: invalid new owner");
      });

      it("should transfer multiple times", () => {
        ownable.as(OWNER).transferOwnership(OwnableSimulator.adminKey(NEW_OWNER));
        ownable.as(NEW_OWNER).transferOwnership(OwnableSimulator.adminKey(OWNER));
        ownable.as(OWNER).transferOwnership(OwnableSimulator.adminKey(NEW_OWNER));
        expect(toHex(ownable.owner().bytes)).toEqual(
          toHex(OwnableSimulator.adminKey(NEW_OWNER).bytes)
        );
      });
    });

    describe("renounceOwnership", () => {
      it("should renounce ownership (owner becomes zero key)", () => {
        ownable.as(OWNER).renounceOwnership();
        expect(toHex(ownable.owner().bytes)).toEqual(toHex(new Uint8Array(32)));
        // No one can satisfy assertOnlyOwner against the zero key now.
        expect(() => ownable.as(OWNER).assertOnlyOwner()).toThrow(
          "Ownable: caller is not the owner"
        );
      });

      it("should fail when an unauthorized actor renounces", () => {
        expect(() => {
          ownable.as(UNAUTHORIZED).renounceOwnership();
        }).toThrow("Ownable: caller is not the owner");
      });
    });

    describe("_transferOwnership (internal, unchecked)", () => {
      it("should transfer ownership without a caller gate", () => {
        ownable._transferOwnership(OwnableSimulator.adminKey(NEW_OWNER));
        expect(toHex(ownable.owner().bytes)).toEqual(
          toHex(OwnableSimulator.adminKey(NEW_OWNER).bytes)
        );
        expect(() => ownable.as(NEW_OWNER).assertOnlyOwner()).not.toThrow();
      });
    });
  });
});
