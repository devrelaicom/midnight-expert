import { Args } from "@oclif/core";
import { unshieldedToken } from "@midnight-ntwrk/ledger-v8";
import * as Rx from "rxjs";
import { BaseCommand } from "../base-command.js";
import { DUST_POLL_INTERVAL } from "../lib/constants.js";
import { buildFacade, getWallet } from "../lib/wallet.js";
import { withSpinner } from "../lib/progress.js";

export default class Balance extends BaseCommand {
	static override description = "Check NIGHT and DUST balances for a wallet";

	static override args = {
		name: Args.string({ description: "Wallet name", required: true }),
	};

	async run(): Promise<void> {
		const { args } = await this.parse(Balance);
		const wallet = getWallet(args.name);

		const ctx = await withSpinner("Syncing wallet...", () => buildFacade(wallet.seed));
		try {
			const state = await Rx.firstValueFrom(
				ctx.facade.state().pipe(
					Rx.throttleTime(DUST_POLL_INTERVAL),
					Rx.filter((s) => s.isSynced),
				),
			);

			const night = state.unshielded.balances[unshieldedToken().raw] ?? 0n;
			const dust = state.dust.walletBalance(new Date());

			const result = {
				night: night.toString(),
				dust: dust.toString(),
			};

			if (!this.jsonEnabled) {
				this.log(`  NIGHT: ${night.toString()}`);
				this.log(`  DUST:  ${dust.toString()}`);
			}

			this.outputResult(result);
		} finally {
			await ctx.facade.stop();
		}
	}
}
