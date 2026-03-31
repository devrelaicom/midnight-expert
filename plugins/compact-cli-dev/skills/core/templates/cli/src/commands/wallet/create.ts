import { Args } from "@oclif/core";
import { BaseCommand } from "../../base-command.js";
import { newSeed, deriveKeys, saveWallet } from "../../lib/wallet.js";
import { createKeystore } from "@midnight-ntwrk/wallet-sdk-unshielded-wallet";
import { getNetworkId } from "@midnight-ntwrk/midnight-js-network-id";

export default class WalletCreate extends BaseCommand {
	static override description = "Generate a new wallet with a random seed";

	static override args = {
		name: Args.string({
			description: "Name for the wallet",
			default: "default",
		}),
	};

	async run(): Promise<void> {
		const { args } = await this.parse(WalletCreate);
		const name = args.name;

		const seed = newSeed();
		const keys = deriveKeys(seed);
		const keystore = createKeystore(keys.nightExternal, getNetworkId());
		const address = keystore.getBech32Address();

		const wallet = {
			seed,
			address,
			createdAt: new Date().toISOString(),
		};

		saveWallet(name, wallet);

		if (!this.jsonEnabled) {
			this.log(`Wallet "${name}" created.`);
			this.log(`  Address: ${address}`);
			this.log(`  Seed:    ${seed}`);
		}

		this.outputResult({ name, address, seed });
	}
}
