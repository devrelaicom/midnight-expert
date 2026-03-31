import ora, { type Ora } from "ora";

let jsonMode = false;

export function setJsonMode(enabled: boolean): void {
	jsonMode = enabled;
}

export function createSpinner(text: string): Ora {
	if (jsonMode) {
		// In JSON mode, return a no-op spinner
		return ora({ text, isSilent: true });
	}
	return ora({ text, spinner: "dots" });
}

export async function withSpinner<T>(text: string, fn: () => Promise<T>): Promise<T> {
	const spinner = createSpinner(text);
	spinner.start();
	try {
		const result = await fn();
		spinner.succeed();
		return result;
	} catch (err) {
		spinner.fail();
		throw err;
	}
}
