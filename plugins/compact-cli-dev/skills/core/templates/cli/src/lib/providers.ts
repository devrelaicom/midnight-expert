import { httpClientProofProvider } from "@midnight-ntwrk/midnight-js-http-client-proof-provider";
import { indexerPublicDataProvider } from "@midnight-ntwrk/midnight-js-indexer-public-data-provider";
import { levelPrivateStateProvider } from "@midnight-ntwrk/midnight-js-level-private-state-provider";
import { NodeZkConfigProvider } from "@midnight-ntwrk/midnight-js-node-zk-config-provider";
import type { MidnightProvider, WalletProvider } from "@midnight-ntwrk/midnight-js-types";
import type { WalletFacade } from "@midnight-ntwrk/wallet-sdk-facade";
import type * as ledger from "@midnight-ntwrk/ledger-v8";
import * as Rx from "rxjs";
import { DEVNET_CONFIG } from "./config.js";
import { ZK_CONFIG_PATH } from "./constants.js";
import type { UnshieldedKeystore } from "@midnight-ntwrk/wallet-sdk-unshielded-wallet";

export interface Providers {
	privateStateProvider: ReturnType<typeof levelPrivateStateProvider>;
	publicDataProvider: ReturnType<typeof indexerPublicDataProvider>;
	zkConfigProvider: NodeZkConfigProvider<string>;
	proofProvider: ReturnType<typeof httpClientProofProvider>;
	walletProvider: WalletProvider & MidnightProvider;
	midnightProvider: WalletProvider & MidnightProvider;
}

export async function createWalletProvider(
	facade: WalletFacade,
	shieldedSecretKeys: ledger.ZswapSecretKeys,
	dustSecretKey: ledger.DustSecretKey,
	keystore: UnshieldedKeystore,
): Promise<WalletProvider & MidnightProvider> {
	const state = await Rx.firstValueFrom(facade.state().pipe(Rx.filter((s) => s.isSynced)));

	return {
		getCoinPublicKey: () => state.shielded.coinPublicKey.toHexString(),
		getEncryptionPublicKey: () => state.shielded.encryptionPublicKey.toHexString(),
		async balanceTx(tx, ttl) {
			const recipe = await facade.balanceUnboundTransaction(
				tx,
				{ shieldedSecretKeys, dustSecretKey },
				{ ttl: ttl ?? new Date(Date.now() + 30 * 60 * 1000) },
			);
			const finalized = await facade.finalizeRecipe(recipe);
			return finalized;
		},
		submitTx: (tx) => facade.submitTransaction(tx),
	} as WalletProvider & MidnightProvider;
}

export async function createProviders(
	facade: WalletFacade,
	shieldedSecretKeys: ledger.ZswapSecretKeys,
	dustSecretKey: ledger.DustSecretKey,
	keystore: UnshieldedKeystore,
	privateStateStoreName: string,
): Promise<Providers> {
	const walletProvider = await createWalletProvider(
		facade,
		shieldedSecretKeys,
		dustSecretKey,
		keystore,
	);

	const zkConfigProvider = new NodeZkConfigProvider(ZK_CONFIG_PATH);

	return {
		privateStateProvider: levelPrivateStateProvider({
			privateStateStoreName,
		}),
		publicDataProvider: indexerPublicDataProvider(
			DEVNET_CONFIG.indexer,
			DEVNET_CONFIG.indexerWS,
		),
		zkConfigProvider,
		proofProvider: httpClientProofProvider(DEVNET_CONFIG.proofServer, zkConfigProvider),
		walletProvider,
		midnightProvider: walletProvider,
	};
}
