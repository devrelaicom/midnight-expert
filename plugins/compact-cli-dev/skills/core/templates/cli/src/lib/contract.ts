import fs from "node:fs";
import path from "node:path";
import { deployContract, findDeployedContract } from "@midnight-ntwrk/midnight-js-contracts";
import { CompiledContract } from "@midnight-ntwrk/compact-js";
import type { Providers } from "./providers.js";
import {
	CONTRACT_NAME,
	CONTRACTS_FILE,
	FILE_MODE_PUBLIC,
	STATE_DIR,
	ZK_CONFIG_PATH,
} from "./constants.js";
import { withSpinner } from "./progress.js";

// NOTE: The contract module is imported dynamically at runtime because
// the import path depends on the compiled contract output.
// The agent should update this import to match the actual contract package.
export async function loadCompiledContract() {
	const ContractModule = await import("{{CONTRACT_PACKAGE}}");
	return CompiledContract.make(CONTRACT_NAME, ContractModule.Contract).pipe(
		CompiledContract.withVacantWitnesses,
		CompiledContract.withCompiledFileAssets(ZK_CONFIG_PATH),
	);
}

// --- Deploy / Join ---

export interface DeployResult {
	contractAddress: string;
	txId: string;
	blockHeight: bigint;
}

export async function deploy(
	providers: Providers,
	initialPrivateState: Record<string, unknown>,
): Promise<DeployResult> {
	return withSpinner("Deploying contract (this may take 30-60 seconds)...", async () => {
		const compiledContract = await loadCompiledContract();

		const deployed = await deployContract(providers, {
			compiledContract,
			privateStateId: `${CONTRACT_NAME}PrivateState`,
			initialPrivateState,
		});

		const result: DeployResult = {
			contractAddress: deployed.deployTxData.public.contractAddress,
			txId: deployed.deployTxData.public.txId,
			blockHeight: deployed.deployTxData.public.blockHeight,
		};

		saveDeployedContract(CONTRACT_NAME, result);
		return result;
	});
}

export async function join(
	providers: Providers,
	contractAddress: string,
	initialPrivateState: Record<string, unknown>,
) {
	return withSpinner("Joining contract...", async () => {
		const compiledContract = await loadCompiledContract();

		return findDeployedContract(providers, {
			contractAddress,
			compiledContract,
			privateStateId: `${CONTRACT_NAME}PrivateState`,
			initialPrivateState,
		});
	});
}

// --- Persistence ---

interface DeployedContractStore {
	[name: string]: {
		address: string;
		deployedAt: string;
		txId: string;
	};
}

function contractsPath(): string {
	return path.join(process.cwd(), STATE_DIR, CONTRACTS_FILE);
}

export function loadDeployedContracts(): DeployedContractStore {
	const filePath = contractsPath();
	if (!fs.existsSync(filePath)) {
		return {};
	}
	return JSON.parse(fs.readFileSync(filePath, "utf-8")) as DeployedContractStore;
}

function saveDeployedContract(name: string, result: DeployResult): void {
	const store = loadDeployedContracts();
	store[name] = {
		address: result.contractAddress,
		deployedAt: new Date().toISOString(),
		txId: result.txId,
	};
	const dir = path.join(process.cwd(), STATE_DIR);
	if (!fs.existsSync(dir)) {
		fs.mkdirSync(dir, { recursive: true });
	}
	fs.writeFileSync(contractsPath(), JSON.stringify(store, null, "\t") + "\n", {
		mode: FILE_MODE_PUBLIC,
	});
}
