import { Args } from "@oclif/core";
import { BaseCommand } from "../../base-command.js";
import { buildFacade, getWallet } from "../../lib/wallet.js";
import { registerDust, waitForDust, waitForFunds } from "../../lib/funding.js";
import { withSpinner } from "../../lib/progress.js";

export default class DustRegister extends BaseCommand {
	static override description = "Register NIGHT UTXOs for DUST generation";

	static override args = {
		name: Args.string({ description: "Wallet name", required: true }),
	};

	async run(): Promise<void> {
		const { args } = await this.parse(DustRegister);
		const wallet = getWallet(args.name);

		const ctx = await withSpinner("Building wallet...", () => buildFacade(wallet.seed));
		try {
			await withSpinner("Syncing...", () => waitForFunds(ctx.facade));
			const txId = await registerDust(ctx.facade, ctx.keystore);

			if (txId) {
				await withSpinner("Waiting for DUST...", () => waitForDust(ctx.facade));
				if (!this.jsonEnabled) {
					this.log(`  DUST registered. tx: ${txId}`);
				}
				this.outputResult({ txId, registered: true });
			} else {
				if (!this.jsonEnabled) {
					this.log("  DUST already available.");
				}
				this.outputResult({ txId: null, registered: false });
			}
		} finally {
			await ctx.facade.stop();
		}
	}
}
