import { execSync } from "node:child_process";
import { BaseCommand } from "../../base-command.js";
import { findComposeFile } from "../../lib/devnet.js";

export default class DevnetStart extends BaseCommand {
	static override description = "Start the local devnet via Docker Compose";

	async run(): Promise<void> {
		const composeFile = findComposeFile();

		if (!this.jsonEnabled) {
			this.log(`  Using: ${composeFile}`);
		}

		execSync(`docker compose -f "${composeFile}" up -d`, {
			stdio: this.jsonEnabled ? "pipe" : "inherit",
		});

		const result = { composePath: composeFile, started: true };
		if (!this.jsonEnabled) {
			this.log("  Devnet started.");
		}
		this.outputResult(result);
	}
}
