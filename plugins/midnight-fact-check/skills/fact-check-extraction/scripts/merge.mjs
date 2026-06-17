#!/usr/bin/env node
// Vendored JSON claim merger for /midnight-fact-check:check and :fast-check.
//
// Self-contained, zero runtime dependencies (Node's stdlib only) so a fresh
// user never has to install anything. Ported from the `merge` command of the
// former @aaronbassett/midnight-fact-checker-utils package
// (packages/midnight-fact-checker-utils).
//
// Usage:
//   node merge.mjs --mode concat -o <output> <file...>
//   node merge.mjs --mode update --original <orig> -o <output> <file...>
//
//   concat: concatenate JSON arrays into a single array (Stage 1 extraction).
//   update: deep-merge each update file's claims into the original by `id`,
//           preserving original order and count (Stage 2 classification).
//
// On success prints "Merged N items to <path>" to stdout (exit 0).
// On failure prints "Merge failed: <error>" to stderr and exits 1.

import { readFile, writeFile } from "node:fs/promises";

async function readJsonFile(filePath) {
	const content = await readFile(filePath, "utf-8");
	try {
		return JSON.parse(content);
	} catch {
		throw new Error(`Invalid JSON in file: ${filePath}`);
	}
}

function validateClaimArray(data, source) {
	if (!Array.isArray(data)) {
		throw new Error(`Expected JSON array in ${source}, got ${typeof data}`);
	}
	for (let i = 0; i < data.length; i++) {
		const item = data[i];
		if (typeof item !== "object" || item === null || !("id" in item)) {
			throw new Error(`Item at index ${i} in ${source} is missing required "id" field`);
		}
		if (typeof item.id !== "string") {
			throw new Error(`Item at index ${i} in ${source} has non-string "id" field`);
		}
	}
	return data;
}

function validateJsonArray(data, source) {
	if (!Array.isArray(data)) {
		throw new Error(`Expected JSON array in ${source}, got ${typeof data}`);
	}
	return data;
}

// Deep merges two objects. Arrays are replaced, not concatenated.
// Nested plain objects are recursively merged.
function deepMerge(base, overlay) {
	const result = { ...base };
	for (const key of Object.keys(overlay)) {
		const baseVal = base[key];
		const overlayVal = overlay[key];
		if (
			typeof baseVal === "object" &&
			baseVal !== null &&
			!Array.isArray(baseVal) &&
			typeof overlayVal === "object" &&
			overlayVal !== null &&
			!Array.isArray(overlayVal)
		) {
			result[key] = deepMerge(baseVal, overlayVal);
		} else {
			result[key] = overlayVal;
		}
	}
	return result;
}

async function mergeConcat(inputPaths) {
	const combined = [];
	for (const p of inputPaths) {
		const data = await readJsonFile(p);
		const items = validateJsonArray(data, p);
		combined.push(...items);
	}
	return combined;
}

async function mergeUpdate(originalPath, inputPaths) {
	const originalData = await readJsonFile(originalPath);
	const originalClaims = validateClaimArray(originalData, originalPath);

	const claimMap = new Map();
	for (const claim of originalClaims) {
		claimMap.set(claim.id, { ...claim });
	}

	const originalCount = claimMap.size;

	for (const p of inputPaths) {
		const data = await readJsonFile(p);
		const updates = validateClaimArray(data, p);
		for (const update of updates) {
			const existing = claimMap.get(update.id);
			if (!existing) {
				throw new Error(
					`Update file "${p}" contains unknown claim id "${update.id}" not present in original`,
				);
			}
			claimMap.set(update.id, deepMerge(existing, update));
		}
	}

	if (claimMap.size !== originalCount) {
		throw new Error(
			`Claim count mismatch: original has ${originalCount} claims but result has ${claimMap.size}`,
		);
	}

	return originalClaims.map((c) => c.id).map((id) => claimMap.get(id));
}

function parseArgs(argv) {
	const opts = { mode: "update", original: undefined, output: undefined, inputs: [] };
	for (let i = 0; i < argv.length; i++) {
		const arg = argv[i];
		if (arg === "--mode") {
			opts.mode = argv[++i];
		} else if (arg === "--original") {
			opts.original = argv[++i];
		} else if (arg === "-o" || arg === "--output") {
			opts.output = argv[++i];
		} else {
			opts.inputs.push(arg);
		}
	}
	return opts;
}

async function main() {
	const opts = parseArgs(process.argv.slice(2));

	if (!opts.output) {
		process.stderr.write("Error: --output (-o) is required\n");
		process.exit(1);
	}

	if (opts.mode !== "concat" && opts.mode !== "update") {
		process.stderr.write(`Error: --mode must be "concat" or "update", got "${opts.mode}"\n`);
		process.exit(1);
	}

	try {
		let result;
		if (opts.mode === "concat") {
			result = await mergeConcat(opts.inputs);
		} else {
			if (!opts.original) {
				throw new Error("Update mode requires an --original file path");
			}
			result = await mergeUpdate(opts.original, opts.inputs);
		}

		const json = JSON.stringify(result, null, 2);
		await writeFile(opts.output, `${json}\n`, "utf-8");
		process.stdout.write(`Merged ${result.length} items to ${opts.output}\n`);
	} catch (err) {
		const message = err instanceof Error ? err.message : "Unknown error";
		process.stderr.write(`Merge failed: ${message}\n`);
		process.exit(1);
	}
}

main();
