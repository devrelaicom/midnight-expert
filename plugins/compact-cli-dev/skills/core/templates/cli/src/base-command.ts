import fs from "node:fs";
import path from "node:path";
import { Command, Flags } from "@oclif/core";
import { classifyError, formatError } from "./lib/errors.js";
import { initializeNetwork } from "./lib/config.js";
import { setJsonMode } from "./lib/progress.js";
import { STATE_DIR, INIT_MARKER } from "./lib/constants.js";

const WELCOME_BANNER = `
  ┌─────────────────────────────────────────────────────────────┐
  │  WARNING: These wallets are for LOCAL DEVNET use only.      │
  │  Seeds are stored in plaintext. Never use these accounts    │
  │  on preprod, preview, or mainnet.                           │
  └─────────────────────────────────────────────────────────────┘
`;

export abstract class BaseCommand extends Command {
	static baseFlags = {
		json: Flags.boolean({
			description: "Output result as JSON",
			default: false,
		}),
	};

	protected jsonEnabled = false;

	async init(): Promise<void> {
		await super.init();
		const { flags } = await this.parse(this.constructor as typeof BaseCommand);
		this.jsonEnabled = flags.json;
		setJsonMode(this.jsonEnabled);
		initializeNetwork();
		this.showWelcomeBanner();
	}

	private showWelcomeBanner(): void {
		if (this.jsonEnabled) return;

		const markerPath = path.join(process.cwd(), STATE_DIR, INIT_MARKER);
		if (fs.existsSync(markerPath)) return;

		this.log(WELCOME_BANNER);

		const dir = path.join(process.cwd(), STATE_DIR);
		if (!fs.existsSync(dir)) {
			fs.mkdirSync(dir, { recursive: true });
		}
		fs.writeFileSync(markerPath, "");
	}

	protected outputResult(result: unknown): void {
		if (this.jsonEnabled) {
			this.log(JSON.stringify(result, null, "\t"));
		}
	}

	async catch(err: unknown): Promise<void> {
		const classified = classifyError(err);
		if (this.jsonEnabled) {
			this.log(
				JSON.stringify(
					{ error: classified.code, message: classified.message, action: classified.action },
					null,
					"\t",
				),
			);
		} else {
			this.error(formatError(classified));
		}
	}
}
