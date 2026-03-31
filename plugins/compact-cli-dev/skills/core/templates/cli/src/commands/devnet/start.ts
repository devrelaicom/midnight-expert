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
