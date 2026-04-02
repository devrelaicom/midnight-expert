import { Args } from "@oclif/core";
import * as Rx from "rxjs";
import { BaseCommand } from "../../base-command.js";
import { DUST_POLL_INTERVAL } from "../../lib/constants.js";
import { buildFacade, getWallet } from "../../lib/wallet.js";
import { withSpinner } from "../../lib/progress.js";

export default class DustStatus extends BaseCommand {
	static override description = "Check DUST balance and registration status";

	static override args = {
		name: Args.string({ description: "Wallet name", required: true }),
	};

	async run(): Promise<void> {
		const { args } = await this.parse(DustStatus);
		const wallet = getWallet(args.name);

		const ctx = await withSpinner("Syncing wallet...", () => buildFacade(wallet.seed));
		try {
			const state = await Rx.firstValueFrom(
				ctx.facade.state().pipe(
					Rx.throttleTime(DUST_POLL_INTERVAL),
					Rx.filter((s) => s.isSynced),
				),
			);

			const balance = state.dust.walletBalance(new Date());
			const available = state.dust.availableCoins.length;
			const registered = state.unshielded.availableCoins.filter(
				(c: { meta?: { registeredForDustGeneration?: boolean } }) =>
					c.meta?.registeredForDustGeneration === true,
			).length;

			const result = {
				balance: balance.toString(),
				available,
				registered,
			};

			if (!this.jsonEnabled) {
				this.log(`  DUST balance:    ${balance.toString()}`);
				this.log(`  Available coins: ${String(available)}`);
				this.log(`  Registered:      ${String(registered)}`);
			}

			this.outputResult(result);
		} finally {
			await ctx.facade.stop();
		}
	}
}
