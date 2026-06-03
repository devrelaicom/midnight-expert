// SPDX-License-Identifier: MIT
//
// SECURE PATTERN — witness-derived identity. AccessControl module tests.
//
// Roles are keyed by a DERIVED UserPublicKey. Authorization derives the caller
// from the witness secret inside the ZK circuit — there is no `ownPublicKey()`
// caller injection. The deployer is granted DEFAULT_ADMIN_ROLE under their
// derived key at deploy, so only that secret holder can grant/revoke roles.
//
// PORT NOTE: the previous suite depended on the external
// `@openzeppelin-compact/contracts-simulator` package, an `artifacts/` build
// dir, a `#test-utils/address.js` import map, and the `.as(address)` caller
// model. Contract-address cases and `_unsafeGrantRole` no longer exist (accounts
// are derived 32-byte keys, not routable addresses) and have been dropped. The
// suite is now self-contained and runs against @midnight-ntwrk/compact-runtime.
//
// Build the mock first:
//   compact compile modules/access/test/mocks/MockAccessControl.compact \
//     modules/access/test/managed/MockAccessControl

import { convertFieldToBytes } from "@midnight-ntwrk/compact-runtime";
import { beforeEach, describe, expect, it } from "vitest";
import { AccessControlSimulator } from "./simulators/AccessControlSimulator.js";
import { secretOf } from "../../test-utils/secure-identity-sim.js";

// Actors (each a distinct 32-byte secret => distinct derived user key).
const ADMIN = secretOf(1); // deployer => DEFAULT_ADMIN_ROLE
const OPERATOR_1 = secretOf(2);
const OPERATOR_2 = secretOf(3);
const CUSTOM_ADMIN = secretOf(4);
const UNAUTHORIZED = secretOf(9);

const userKey = AccessControlSimulator.userKey;

// Roles
const DEFAULT_ADMIN_ROLE = new Uint8Array(32); // all-zero
const OPERATOR_ROLE_1 = convertFieldToBytes(32, 1n, "");
const OPERATOR_ROLE_2 = convertFieldToBytes(32, 2n, "");
const CUSTOM_ADMIN_ROLE = convertFieldToBytes(32, 4n, "");
const UNINITIALIZED_ROLE = convertFieldToBytes(32, 5n, "");

let accessControl: AccessControlSimulator;

describe("AccessControl (secure, witness-derived identity)", () => {
  beforeEach(() => {
    accessControl = new AccessControlSimulator(ADMIN);
  });

  describe("constructor", () => {
    it("grants the deployer DEFAULT_ADMIN_ROLE under their derived key", () => {
      expect(
        accessControl.hasRole(DEFAULT_ADMIN_ROLE, userKey(ADMIN))
      ).toBe(true);
    });
  });

  describe("hasRole", () => {
    beforeEach(() => {
      accessControl._grantRole(OPERATOR_ROLE_1, userKey(OPERATOR_1));
    });

    it("should return true when an operator has a role", () => {
      expect(accessControl.hasRole(OPERATOR_ROLE_1, userKey(OPERATOR_1))).toBe(
        true
      );
    });

    it("should return false for an actor without the role", () => {
      expect(
        accessControl.hasRole(OPERATOR_ROLE_1, userKey(UNAUTHORIZED))
      ).toBe(false);
    });

    it("should return false when the role does not exist", () => {
      expect(
        accessControl.hasRole(UNINITIALIZED_ROLE, userKey(OPERATOR_1))
      ).toBe(false);
    });
  });

  describe("assertOnlyRole", () => {
    beforeEach(() => {
      accessControl._grantRole(OPERATOR_ROLE_1, userKey(OPERATOR_1));
    });

    it("should allow an actor holding the role to call", () => {
      expect(() =>
        accessControl.as(OPERATOR_1).assertOnlyRole(OPERATOR_ROLE_1)
      ).not.toThrow();
    });

    it("should fail for an actor without the role", () => {
      expect(() =>
        accessControl.as(UNAUTHORIZED).assertOnlyRole(OPERATOR_ROLE_1)
      ).toThrow("AccessControl: unauthorized account");
    });

    it("IMPERSONATION: holding no role, naming an operator's key does not help", () => {
      // The caller is derived from UNAUTHORIZED's secret regardless of any
      // argument, so there is no key to "supply" to pass the gate.
      expect(() =>
        accessControl.as(UNAUTHORIZED).assertOnlyRole(OPERATOR_ROLE_1)
      ).toThrow("AccessControl: unauthorized account");
    });
  });

  describe("grantRole", () => {
    it("admin (DEFAULT_ADMIN_ROLE holder) can grant a role", () => {
      accessControl.as(ADMIN).grantRole(OPERATOR_ROLE_1, userKey(OPERATOR_1));
      expect(accessControl.hasRole(OPERATOR_ROLE_1, userKey(OPERATOR_1))).toBe(
        true
      );
    });

    it("a non-admin actor cannot grant a role", () => {
      expect(() =>
        accessControl
          .as(UNAUTHORIZED)
          .grantRole(OPERATOR_ROLE_1, userKey(OPERATOR_1))
      ).toThrow("AccessControl: unauthorized account");
    });

    it("a role member without admin rights cannot grant", () => {
      accessControl.as(ADMIN).grantRole(OPERATOR_ROLE_1, userKey(OPERATOR_1));
      // OPERATOR_1 has OPERATOR_ROLE_1 but not its admin (DEFAULT_ADMIN_ROLE).
      expect(() =>
        accessControl
          .as(OPERATOR_1)
          .grantRole(OPERATOR_ROLE_2, userKey(OPERATOR_2))
      ).toThrow("AccessControl: unauthorized account");
    });
  });

  describe("revokeRole", () => {
    beforeEach(() => {
      accessControl.as(ADMIN).grantRole(OPERATOR_ROLE_1, userKey(OPERATOR_1));
    });

    it("admin can revoke a role", () => {
      accessControl.as(ADMIN).revokeRole(OPERATOR_ROLE_1, userKey(OPERATOR_1));
      expect(accessControl.hasRole(OPERATOR_ROLE_1, userKey(OPERATOR_1))).toBe(
        false
      );
    });

    it("a non-admin actor cannot revoke a role", () => {
      expect(() =>
        accessControl
          .as(UNAUTHORIZED)
          .revokeRole(OPERATOR_ROLE_1, userKey(OPERATOR_1))
      ).toThrow("AccessControl: unauthorized account");
    });
  });

  describe("renounceRole", () => {
    beforeEach(() => {
      accessControl.as(ADMIN).grantRole(OPERATOR_ROLE_1, userKey(OPERATOR_1));
    });

    it("an actor can renounce their own role (caller is the witness secret)", () => {
      accessControl.as(OPERATOR_1).renounceRole(OPERATOR_ROLE_1);
      expect(accessControl.hasRole(OPERATOR_ROLE_1, userKey(OPERATOR_1))).toBe(
        false
      );
    });

    it("renouncing does not affect another actor's role", () => {
      accessControl.as(OPERATOR_1).renounceRole(OPERATOR_ROLE_2);
      expect(accessControl.hasRole(OPERATOR_ROLE_1, userKey(OPERATOR_1))).toBe(
        true
      );
    });
  });

  describe("custom role admin (_setRoleAdmin)", () => {
    it("a custom-admin-role holder can grant the controlled role", () => {
      // Make CUSTOM_ADMIN_ROLE the admin of OPERATOR_ROLE_1.
      accessControl.as(ADMIN)._setRoleAdmin(OPERATOR_ROLE_1, CUSTOM_ADMIN_ROLE);
      // Give CUSTOM_ADMIN the custom admin role.
      accessControl.as(ADMIN).grantRole(CUSTOM_ADMIN_ROLE, userKey(CUSTOM_ADMIN));
      // Now CUSTOM_ADMIN (not the default admin) can grant OPERATOR_ROLE_1.
      accessControl
        .as(CUSTOM_ADMIN)
        .grantRole(OPERATOR_ROLE_1, userKey(OPERATOR_1));
      expect(accessControl.hasRole(OPERATOR_ROLE_1, userKey(OPERATOR_1))).toBe(
        true
      );
      // The original default admin no longer controls OPERATOR_ROLE_1.
      expect(() =>
        accessControl
          .as(ADMIN)
          .grantRole(OPERATOR_ROLE_1, userKey(OPERATOR_2))
      ).toThrow("AccessControl: unauthorized account");
    });
  });
});
