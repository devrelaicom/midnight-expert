import { setNetworkId } from "@midnight-ntwrk/midnight-js-network-id";

export interface NetworkConfig {
	readonly indexer: string;
	readonly indexerWS: string;
	readonly node: string;
	readonly proofServer: string;
	readonly networkId: string;
}

export const DEVNET_CONFIG: NetworkConfig = {
	indexer: "http://127.0.0.1:8088/api/v3/graphql",
	indexerWS: "ws://127.0.0.1:8088/api/v3/graphql/ws",
	node: "http://127.0.0.1:9944",
	proofServer: "http://127.0.0.1:6300",
	networkId: "undeployed",
};

export function initializeNetwork(): void {
	setNetworkId(DEVNET_CONFIG.networkId);
}
