import { execSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { BaseCommand } from "../../base-command.js";
import { COMPOSE_SEARCH_PATHS, COMPOSE_FALLBACK } from "../../lib/constants.js";

function findComposeFile(): string {
	for (const relative of COMPOSE_SEARCH_PATHS) {
		const abs = path.resolve(relative);
		if (fs.existsSync(abs)) return abs;
	}
	if (fs.existsSync(COMPOSE_FALLBACK)) return COMPOSE_FALLBACK;
	throw new Error(
		"No devnet.yml found. Generate one with the midnight-tooling:devnet skill.\n" +
			"Search paths: " + [...COMPOSE_SEARCH_PATHS, COMPOSE_FALLBACK].join(", "),
	);
}

export default class DevnetStop extends BaseCommand {
	static override description = "Stop the local devnet";

	async run(): Promise<void> {
		const composeFile = findComposeFile();

		execSync(`docker compose -f "${composeFile}" down`, {
			stdio: this.jsonEnabled ? "pipe" : "inherit",
		});

		if (!this.jsonEnabled) {
			this.log("  Devnet stopped.");
		}
		this.outputResult({ stopped: true });
	}
}
