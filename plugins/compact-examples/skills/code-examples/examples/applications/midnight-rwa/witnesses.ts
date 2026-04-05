import {Ledger, MerkleTreePath, ZswapCoinPublicKey} from "./managed/midnight-rwa/contract/index.cjs";
import {WitnessContext} from "@midnight-ntwrk/compact-runtime";
import {toHex} from "./test/utils.js";

export type RwaPrivateState = {
  readonly secretKey: Uint8Array;
};

export const witnesses = {
  findIssuerPath(context: WitnessContext<Ledger, RwaPrivateState>,
                   pk_0: Uint8Array): [RwaPrivateState, MerkleTreePath<Uint8Array>] {
    console.log('findIssuerPath called with pk_0=' + toHex(pk_0));
    const path = context.ledger.issuerAuthorizations.findPathForLeaf(pk_0);
    if (!path) {
      throw new Error(`Issuer not found in the ledger for pk=` + toHex(pk_0));
    }
    return [context.privateState, path!!];
  },
  findAuthorizationPath(context: WitnessContext<Ledger, RwaPrivateState>,
                   pk_0: ZswapCoinPublicKey): [RwaPrivateState, MerkleTreePath<ZswapCoinPublicKey>] {
    const path = context.ledger.authorizations.findPathForLeaf(pk_0);
    if (!path) {
      throw new Error(`Authorization not found in the ledger for pk=` + toHex(pk_0.bytes));
    }
    return [context.privateState, path!!];
  },
  localSecretKey(context: WitnessContext<Ledger, RwaPrivateState>): [RwaPrivateState, Uint8Array] {
    return [context.privateState, context.privateState.secretKey];
  },

  // Workarounds

  reduceChallenge(context: WitnessContext<Ledger, RwaPrivateState>, challenge: bigint): [RwaPrivateState, bigint] {

    const FIELD_MODULO = BigInt(
      "6554484396890773809930967563523245729705921265872317281365359162392183254199"
    );
    const reducedChallenge = challenge % FIELD_MODULO;

    return [context.privateState, reducedChallenge];
  },
};
