import fs from "node:fs";
import path from "node:path";
import * as ledger from "@midnight-ntwrk/ledger-v8";
import { getNetworkId } from "@midnight-ntwrk/midnight-js-network-id";
import { WalletFacade } from "@midnight-ntwrk/wallet-sdk-facade";
import { DustWallet } from "@midnight-ntwrk/wallet-sdk-dust-wallet";
import { HDWallet, Roles, generateRandomSeed } from "@midnight-ntwrk/wallet-sdk-hd";
import { ShieldedWallet } from "@midnight-ntwrk/wallet-sdk-shielded";
import {
	createKeystore,
	InMemoryTransactionHistoryStorage,
	PublicKey,
	UnshieldedWallet,
	type UnshieldedKeystore,
} from "@midnight-ntwrk/wallet-sdk-unshielded-wallet";
import { WebSocket } from "ws";
import {
	ADDITIONAL_FEE_OVERHEAD,
	FEE_BLOCKS_MARGIN,
	FILE_MODE_PRIVATE,
	DIR_MODE,
	SEED_LENGTH,
	STATE_DIR,
	WALLETS_FILE,
} from "./constants.js";

// Required for GraphQL subscriptions in Node.js
// @ts-expect-error WebSocket polyfill for apollo client
globalThis.WebSocket = WebSocket;

// --- Types ---

export interface StoredWallet {
	seed: string;
	address: string;
	createdAt: string;
}

export interface WalletStore {
	[name: string]: StoredWallet;
}

export interface WalletContext {
	facade: WalletFacade;
	shieldedSecretKeys: ledger.ZswapSecretKeys;
	dustSecretKey: ledger.DustSecretKey;
	keystore: UnshieldedKeystore;
}

// --- Seed & Key Derivation ---

export function newSeed(): string {
	return Buffer.from(generateRandomSeed()).toString("hex");
}

export function deriveKeys(seed: string): {
	zswap: Uint8Array;
	nightExternal: Uint8Array;
	dust: Uint8Array;
} {
	if (seed.length !== SEED_LENGTH) {
		throw new Error(`Invalid seed length: expected ${String(SEED_LENGTH)} hex chars, got ${String(seed.length)}`);
	}
	const hdWallet = HDWallet.fromSeed(Buffer.from(seed, "hex"));
	if (hdWallet.type !== "seedOk") {
		throw new Error("Invalid seed: HD wallet derivation failed");
	}
	const result = hdWallet.hdWallet
		.selectAccount(0)
		.selectRoles([Roles.Zswap, Roles.NightExternal, Roles.Dust])
		.deriveKeysAt(0);
	if (result.type !== "keysDerived") {
		throw new Error("Key derivation failed");
	}
	hdWallet.hdWallet.clear();
	return {
		zswap: result.keys[Roles.Zswap],
		nightExternal: result.keys[Roles.NightExternal],
		dust: result.keys[Roles.Dust],
	};
}

// --- WalletFacade Building ---

export async function buildFacade(seed: string): Promise<WalletContext> {
	const keys = deriveKeys(seed);
	const networkId = getNetworkId();

	const shieldedSecretKeys = ledger.ZswapSecretKeys.fromSeed(keys.zswap);
	const dustSecretKey = ledger.DustSecretKey.fromSeed(keys.dust);
	const keystore = createKeystore(keys.nightExternal, networkId);

	const walletConfig = {
		networkId,
		indexerClientConnection: {
			indexerHttpUrl: "http://127.0.0.1:8088/api/v3/graphql",
			indexerWsUrl: "ws://127.0.0.1:8088/api/v3/graphql/ws",
		},
		costParameters: {
			additionalFeeOverhead: ADDITIONAL_FEE_OVERHEAD,
			feeBlocksMargin: FEE_BLOCKS_MARGIN,
		},
		txHistoryStorage: new InMemoryTransactionHistoryStorage(),
	};

	const facade = await WalletFacade.init({
		configuration: walletConfig,
		shielded: (cfg) => ShieldedWallet(cfg).startWithSecretKeys(shieldedSecretKeys),
		unshielded: (cfg) =>
			UnshieldedWallet({
				...cfg,
				txHistoryStorage: new InMemoryTransactionHistoryStorage(),
			}).startWithPublicKey(PublicKey.fromKeyStore(keystore)),
		dust: (cfg) =>
			DustWallet(cfg).startWithSecretKey(
				dustSecretKey,
				ledger.LedgerParameters.initialParameters().dust,
			),
	});

	return { facade, shieldedSecretKeys, dustSecretKey, keystore };
}

// --- Persistence ---

function walletsPath(): string {
	return path.join(process.cwd(), STATE_DIR, WALLETS_FILE);
}

function ensureStateDir(): void {
	const dir = path.join(process.cwd(), STATE_DIR);
	if (!fs.existsSync(dir)) {
		fs.mkdirSync(dir, { mode: DIR_MODE, recursive: true });
	}
}

export function loadWallets(): WalletStore {
	const filePath = walletsPath();
	if (!fs.existsSync(filePath)) {
		return {};
	}
	const raw = fs.readFileSync(filePath, "utf-8");
	return JSON.parse(raw) as WalletStore;
}

export function saveWallets(store: WalletStore): void {
	ensureStateDir();
	const filePath = walletsPath();
	fs.writeFileSync(filePath, JSON.stringify(store, null, "\t") + "\n", {
		mode: FILE_MODE_PRIVATE,
	});
}

export function getWallet(name: string): StoredWallet {
	const store = loadWallets();
	const wallet = store[name];
	if (!wallet) {
		throw new Error(
			`Wallet "${name}" not found. Run \`wallet:create ${name}\` to create it.`,
		);
	}
	return wallet;
}

export function saveWallet(name: string, wallet: StoredWallet): void {
	const store = loadWallets();
	store[name] = wallet;
	saveWallets(store);
}
