import { setNetworkId } from "@midnight-ntwrk/midnight-js-network-id";
import { indexerPublicDataProvider } from "@midnight-ntwrk/midnight-js-indexer-public-data-provider";
import { FetchZkConfigProvider } from "@midnight-ntwrk/midnight-js-fetch-zk-config-provider";
import { httpClientProofProvider } from "@midnight-ntwrk/midnight-js-http-client-proof-provider";
import { toHex, fromHex } from "@midnight-ntwrk/midnight-js-utils";
import {
  Transaction,
  type FinalizedTransaction,
} from "@midnight-ntwrk/ledger-v8";
import type { ChargedState } from "@midnight-ntwrk/compact-runtime";
import type { ConnectedAPI } from "@midnight-ntwrk/dapp-connector-api";
import type {
  WalletProvider,
  MidnightProvider,
} from "@midnight-ntwrk/midnight-js-types";
import { combineLatest, map, retry, Observable } from "rxjs";
import { inMemoryPrivateStateProvider } from "./private-state.js";
import type {
  AppProviders,
  ContractState,
  DerivedState,
  ImpureCircuitKeys,
  PrivateState,
} from "./types.js";
import { PRIVATE_STATE_ID } from "./types.js";

export { inMemoryPrivateStateProvider } from "./private-state.js";
export type {
  AppProviders,
  ContractState,
  DerivedState,
  ImpureCircuitKeys,
  PrivateState,
} from "./types.js";
export { PRIVATE_STATE_ID } from "./types.js";

function deriveProofServerUri(substrateNodeUri: string): string {
  try {
    const url = new URL(substrateNodeUri);
    url.port = "6300";
    url.pathname = "";
    return url.toString().replace(/\/$/, "");
  } catch {
    return "http://localhost:6300";
  }
}

export async function createProviders(
  api: ConnectedAPI,
): Promise<AppProviders> {
  const config = await api.getConfiguration();
  setNetworkId(config.networkId);

  const publicDataProvider = indexerPublicDataProvider(
    config.indexerUri,
    config.indexerWsUri,
  );

  const privateStateProvider = inMemoryPrivateStateProvider<
    typeof PRIVATE_STATE_ID,
    PrivateState
  >();

  const zkConfigProvider = new FetchZkConfigProvider<ImpureCircuitKeys>(
    window.location.origin,
    fetch.bind(window),
  );

  const proofServerUri = deriveProofServerUri(config.substrateNodeUri);
  const proofProvider = httpClientProofProvider<ImpureCircuitKeys>(
    proofServerUri,
    zkConfigProvider,
  );

  const { shieldedCoinPublicKey, shieldedEncryptionPublicKey } =
    await api.getShieldedAddresses();

  const walletProvider: WalletProvider = {
    getCoinPublicKey: () => shieldedCoinPublicKey,
    getEncryptionPublicKey: () => shieldedEncryptionPublicKey,
    // WalletProvider.balanceTx is (tx: UnboundTransaction, ttl?: Date) =>
    // Promise<FinalizedTransaction>. The DApp Connector speaks serialized hex
    // strings, so we hex-encode the unbound tx, hand it to Lace (which selects
    // fee inputs/change and binds it), then deserialize the returned hex string
    // back into a FinalizedTransaction. The options object is `{ payFees?:
    // boolean }`; an empty `{}` uses the defaults (payFees: true). There is no
    // `sender`, `newCoins`, or `ttl` argument on this method.
    balanceTx: async (tx, _ttl) => {
      const { tx: balancedHex } = await api.balanceUnsealedTransaction(
        toHex(tx.serialize()),
        {},
      );
      // A balanced/finalized tx is Transaction<SignatureEnabled, Proof, Binding>.
      // deserialize takes the three instance markers for those type params.
      return Transaction.deserialize(
        "signature",
        "proof",
        "binding",
        fromHex(balancedHex),
      ) satisfies FinalizedTransaction;
    },
  };

  const midnightProvider: MidnightProvider = {
    submitTx: async (tx) => {
      // submitTransaction takes a serialized hex string and returns void; the
      // tx id is recovered from the transaction's own identifiers().
      await api.submitTransaction(toHex(tx.serialize()));
      return tx.identifiers()[0];
    },
  };

  return {
    privateStateProvider,
    publicDataProvider,
    zkConfigProvider,
    proofProvider,
    walletProvider,
    midnightProvider,
  };
}

// TODO: Import your compiled contract and implement deploy/join.
//
// Example deployment pattern:
//
//   import { deployContract } from "@midnight-ntwrk/midnight-js-contracts";
//   import { CompiledContract } from "@midnight-ntwrk/compact-js";
//   import { MyContract } from "{{CONTRACT_PACKAGE}}";
//   import { witnesses } from "{{CONTRACT_PACKAGE}}/witnesses";
//
//   export async function deploy(providers: AppProviders) {
//     // `withCompiledFileAssets(path)` is the only asset combinator in
//     // compact-js 2.5.1; its argument is a *path string* to the contract's
//     // compiled output (resolved relative to each consuming service's base
//     // path), not a URL. It must be called so the result is a fully
//     // configured `CompiledContract<C, never>`, which is what
//     // `deployContract` expects. In the browser, the ZK assets themselves are
//     // fetched over HTTP at proving time by the FetchZkConfigProvider above —
//     // this path just points the verifier-key reader at the managed output
//     // you serve as static assets (e.g. "public/managed/myContract").
//     const compiledContract = CompiledContract.make("myContract", MyContract.Contract).pipe(
//       CompiledContract.withWitnesses(witnesses),
//       CompiledContract.withCompiledFileAssets("managed/myContract"),
//     );
//     return deployContract(providers, {
//       compiledContract,
//       privateStateId: PRIVATE_STATE_ID,
//       initialPrivateState: { secretKey: crypto.getRandomValues(new Uint8Array(32)) },
//     });
//   }
//
// Example join pattern:
//
//   import { findDeployedContract } from "@midnight-ntwrk/midnight-js-contracts";
//
//   export async function join(providers: AppProviders, contractAddress: string) {
//     return findDeployedContract(providers, {
//       contractAddress,
//       compiledContract,
//       privateStateId: PRIVATE_STATE_ID,
//       initialPrivateState: { secretKey: crypto.getRandomValues(new Uint8Array(32)) },
//     });
//   }

export function createStateObservable(
  publicDataProvider: AppProviders["publicDataProvider"],
  privateStateProvider: AppProviders["privateStateProvider"],
  contractAddress: string,
  // `state.data` is now a ChargedState (not a Uint8Array). Your compiled
  // contract's generated `YourContract.ledger(state.data)` accepts this value.
  parseLedger: (data: ChargedState) => ContractState,
): Observable<DerivedState> {
  const public$ = publicDataProvider
    .contractStateObservable(contractAddress, { type: "latest" })
    .pipe(map((state) => parseLedger(state.data)));

  const private$ = new Observable<PrivateState | null>((subscriber) => {
    privateStateProvider
      .get(PRIVATE_STATE_ID)
      .then((s) => subscriber.next(s))
      .catch((err) => subscriber.error(err));
  });

  return combineLatest([public$, private$]).pipe(
    map(([contractState, privateState]) => ({ contractState, privateState })),
    retry({ delay: 500 }),
  );
}
