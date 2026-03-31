import { Args, Flags } from "@oclif/core";
import { BaseCommand } from "../base-command.js";

export default class Call extends BaseCommand {
	static override description = "Call a contract circuit (transaction)";

	static override args = {
		circuit: Args.string({
			description: "Circuit name to call",
			required: true,
		}),
	};

	static override flags = {
		...BaseCommand.baseFlags,
		wallet: Flags.string({
			description: "Wallet name",
			default: "default",
		}),
	};

	async run(): Promise<void> {
		const { args } = await this.parse(Call);

		// TODO: Replace this stub with your contract's actual circuit calls.
		//
		// Example pattern (using the counter contract):
		//
		//   import { buildFacade, getWallet } from "../lib/wallet.js";
		//   import { createProviders } from "../lib/providers.js";
		//   import { join } from "../lib/contract.js";
		//   import { loadDeployedContracts } from "../lib/contract.js";
		//
		//   const walletData = getWallet(flags.wallet);
		//   const ctx = await buildFacade(walletData.seed);
		//   const providers = await createProviders(ctx.facade, ctx.shieldedSecretKeys, ctx.dustSecretKey, ctx.keystore, "counter-private-state");
		//   const contracts = loadDeployedContracts();
		//   const contract = await join(providers, contracts["counter"].address, { privateCounter: 0 });
		//
		//   const txData = await contract.callTx.increment();
		//   this.log(`Transaction: ${txData.public.txId}`);
		//   this.log(`Block: ${txData.public.blockHeight}`);

		this.log(`Circuit "${args.circuit}" is not yet implemented.`);
		this.log("Edit src/commands/call.ts to add your contract's circuit calls.");
	}
}
