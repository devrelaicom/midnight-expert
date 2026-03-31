#!/usr/bin/env node

import { processTemplate } from "./engine.js";

interface StdinInput {
	template: string;
	output: string;
	context: Record<string, string>;
}

function readStdin(): Promise<string> {
	return new Promise((resolve, reject) => {
		const chunks: string[] = [];
		process.stdin.setEncoding("utf-8");
		process.stdin.on("data", (chunk: string) => chunks.push(chunk));
		process.stdin.on("end", () => resolve(chunks.join("")));
		process.stdin.on("error", reject);
	});
}

function isValidInput(value: unknown): value is StdinInput {
	if (typeof value !== "object" || value === null) return false;
	const obj = value as Record<string, unknown>;
	return (
		typeof obj.template === "string" &&
		typeof obj.output === "string" &&
		typeof obj.context === "object" &&
		obj.context !== null
	);
}

async function main(): Promise<void> {
	let raw: string;
	try {
		raw = await readStdin();
	} catch {
		process.stderr.write(`${JSON.stringify({ error: "Failed to read stdin" })}\n`);
		process.exit(1);
	}

	let input: StdinInput;
	try {
		const parsed: unknown = JSON.parse(raw);
		if (!isValidInput(parsed)) {
			throw new Error(
				'Invalid input. Expected {"template": string, "output": string, "context": {...}}',
			);
		}
		input = parsed;
	} catch (err) {
		const message = err instanceof Error ? err.message : "Invalid JSON input";
		process.stderr.write(`${JSON.stringify({ error: message })}\n`);
		process.exit(1);
	}

	try {
		const result = await processTemplate(input);
		process.stdout.write(`${JSON.stringify(result)}\n`);
	} catch (err) {
		const message = err instanceof Error ? err.message : "Template processing failed";
		process.stderr.write(`${JSON.stringify({ error: message })}\n`);
		process.exit(1);
	}
}

main();
