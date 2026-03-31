#!/usr/bin/env node

import { Command } from "commander";
import { discover } from "./commands/discover.js";
import { extractUrls } from "./commands/extract-url.js";
import { merge } from "./commands/merge.js";
import type { MergeMode } from "./types/merge.js";

const program = new Command();

program
	.name("midnight-fact-checker-utils")
	.description("CLI utilities for midnight fact-checking workflows")
	.version("0.1.0");

program
	.command("discover")
	.description("Discover files matching a glob pattern, grouped by directory")
	.argument("<pattern>", "Glob pattern to match files")
	.option("--cwd <dir>", "Base directory to search from", process.cwd())
	.option("--no-gitignore", "Disable .gitignore filtering")
	.action(async (pattern: string, opts: { cwd: string; gitignore: boolean }) => {
		const result = await discover({
			pattern,
			cwd: opts.cwd,
			gitignore: opts.gitignore,
		});
		process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
	});

program
	.command("extract-url")
	.description("Extract readable content from URLs and convert to Markdown")
	.argument("<urls...>", "One or more URLs to extract content from")
	.action(async (urls: string[]) => {
		const result = await extractUrls(urls);

		for (const success of result.successes) {
			process.stdout.write(`# ${success.title}\n\n`);
			process.stdout.write(`> Source: ${success.url}\n\n`);
			process.stdout.write(`${success.markdown}\n\n`);
		}

		for (const failure of result.failures) {
			process.stderr.write(`Error extracting ${failure.url}: ${failure.error}\n`);
		}

		if (result.failures.length > 0 && result.successes.length === 0) {
			process.exit(1);
		}
	});

program
	.command("merge")
	.description("Merge JSON claim files with validation")
	.option("--mode <mode>", "Merge mode: concat or update", "update")
	.option("--original <file>", "Original JSON file (required for update mode)")
	.option("-o, --output <file>", "Output file path")
	.argument("<files...>", "Input JSON files to merge")
	.action(async (files: string[], opts: { mode: string; original?: string; output?: string }) => {
		if (!opts.output) {
			process.stderr.write("Error: --output (-o) is required\n");
			process.exit(1);
		}

		const mode = opts.mode as MergeMode;
		if (mode !== "concat" && mode !== "update") {
			process.stderr.write(`Error: --mode must be "concat" or "update", got "${mode}"\n`);
			process.exit(1);
		}

		const result = await merge({
			mode,
			original: opts.original,
			inputs: files,
			output: opts.output,
		});

		if (result.ok) {
			process.stdout.write(
				`Merged ${result.claimCount.toString()} items to ${result.outputPath}\n`,
			);
		} else {
			process.stderr.write(`Merge failed: ${result.error}\n`);
			process.exit(1);
		}
	});

program.parse();
