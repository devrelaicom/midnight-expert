import { Args, Flags } from "@oclif/core";
import { BaseCommand } from "../base-command.js";

export default class Query extends BaseCommand {
	static override description = "Query contract public state (read-only)";

	static override args = {
		field: Args.string({
			description: "Ledger field to query",
			required: true,
		}),
	};

	static override flags = {
		...BaseCommand.baseFlags,
		address: Flags.string({
			description: "Contract address (uses deployed address if omitted)",
		}),
	};

	async run(): Promise<void> {
		const { args } = await this.parse(Query);

		// TODO: Replace this stub with your contract's actual state queries.
		//
		// Example pattern (using the counter contract):
		//
		//   import { createProviders } from "../lib/providers.js";
		//   import { loadDeployedContracts } from "../lib/contract.js";
		//   import { DEVNET_CONFIG } from "../lib/config.js";
		//   import { indexerPublicDataProvider } from "@midnight-ntwrk/midnight-js-indexer-public-data-provider";
		//   import { Counter } from "@midnight-ntwrk/counter-contract";
		//
		//   const contracts = loadDeployedContracts();
		//   const address = flags.address ?? contracts["counter"].address;
		//   const publicDataProvider = indexerPublicDataProvider(DEVNET_CONFIG.indexer, DEVNET_CONFIG.indexerWS);
		//   const state = await publicDataProvider.queryContractState(address);
		//
		//   if (state) {
		//     const ledgerState = Counter.ledger(state.data);
		//     this.log(`Counter value: ${ledgerState.round}`);
		//   }

		this.log(`Field "${args.field}" query is not yet implemented.`);
		this.log("Edit src/commands/query.ts to add your contract's state queries.");
	}
}
