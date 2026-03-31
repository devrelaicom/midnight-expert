import { setNetworkId } from "@midnight-ntwrk/midnight-js-network-id";
import { indexerPublicDataProvider } from "@midnight-ntwrk/midnight-js-indexer-public-data-provider";
import { FetchZkConfigProvider } from "@midnight-ntwrk/midnight-js-fetch-zk-config-provider";
import { httpClientProofProvider } from "@midnight-ntwrk/midnight-js-http-client-proof-provider";
import type { ConnectedAPI } from "@midnight-ntwrk/dapp-connector-api";
import type {
  WalletProvider,
  MidnightProvider,
} from "@midnight-ntwrk/midnight-js-types";
import { combineLatest, map, retry, type Observable } from "rxjs";
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
    balanceTx: async (tx, newCoins, ttl) => {
      const result = await api.balanceUnsealedTransaction(tx, {
        newCoins,
        ttl,
      });
      return result.tx;
    },
  };

  const midnightProvider: MidnightProvider = {
    submitTx: async (tx) => {
      await api.submitTransaction(tx);
      return tx.txId;
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
//     const compiledContract = CompiledContract.make("myContract", MyContract.Contract).pipe(
//       CompiledContract.withWitnesses(witnesses),
//       CompiledContract.withFetchedFileAssets(window.location.origin),
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
  parseLedger: (data: Uint8Array) => ContractState,
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
