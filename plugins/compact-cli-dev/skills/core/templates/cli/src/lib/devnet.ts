import fs from "node:fs";
import path from "node:path";
import { COMPOSE_SEARCH_PATHS, COMPOSE_FALLBACK } from "./constants.js";

export function findComposeFile(): string {
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
