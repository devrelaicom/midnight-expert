import { readFile, writeFile } from "node:fs/promises";
import type { Claim, MergeOptions, MergeResult } from "../types/merge.js";

/**
 * Reads and parses a JSON file, returning the parsed content.
 * Throws descriptive errors for file read or parse failures.
 */
async function readJsonFile(filePath: string): Promise<unknown> {
	const content = await readFile(filePath, "utf-8");
	try {
		return JSON.parse(content) as unknown;
	} catch {
		throw new Error(`Invalid JSON in file: ${filePath}`);
	}
}

/**
 * Validates that a value is an array of claim objects (each with a string `id` field).
 */
function validateClaimArray(data: unknown, source: string): Claim[] {
	if (!Array.isArray(data)) {
		throw new Error(`Expected JSON array in ${source}, got ${typeof data}`);
	}

	for (let i = 0; i < data.length; i++) {
		const item: unknown = data[i];
		if (typeof item !== "object" || item === null || !("id" in item)) {
			throw new Error(`Item at index ${i.toString()} in ${source} is missing required "id" field`);
		}
		const record = item as Record<string, unknown>;
		if (typeof record.id !== "string") {
			throw new Error(`Item at index ${i.toString()} in ${source} has non-string "id" field`);
		}
	}

	return data as Claim[];
}

/**
 * Validates that a value is an array of JSON values (for concat mode).
 */
function validateJsonArray(data: unknown, source: string): unknown[] {
	if (!Array.isArray(data)) {
		throw new Error(`Expected JSON array in ${source}, got ${typeof data}`);
	}
	return data as unknown[];
}

/**
 * Deep merges two objects. Arrays are replaced, not concatenated.
 * Nested objects are recursively merged.
 */
export function deepMerge(
	base: Record<string, unknown>,
	overlay: Record<string, unknown>,
): Record<string, unknown> {
	const result: Record<string, unknown> = { ...base };

	for (const key of Object.keys(overlay)) {
		const baseVal: unknown = base[key];
		const overlayVal: unknown = overlay[key];

		if (
			typeof baseVal === "object" &&
			baseVal !== null &&
			!Array.isArray(baseVal) &&
			typeof overlayVal === "object" &&
			overlayVal !== null &&
			!Array.isArray(overlayVal)
		) {
			result[key] = deepMerge(
				baseVal as Record<string, unknown>,
				overlayVal as Record<string, unknown>,
			);
		} else {
			result[key] = overlayVal;
		}
	}

	return result;
}

/**
 * Concatenates multiple JSON arrays into a single array.
 */
export async function mergeConcat(inputPaths: readonly string[]): Promise<unknown[]> {
	const combined: unknown[] = [];

	for (const path of inputPaths) {
		const data = await readJsonFile(path);
		const items = validateJsonArray(data, path);
		combined.push(...items);
	}

	return combined;
}

/**
 * Merges claim updates into an original claim set by id.
 * Each update file's claims are deep-merged into the original by matching `id`.
 * Validates that the output contains the same number of claims as the original.
 */
export async function mergeUpdate(
	originalPath: string,
	inputPaths: readonly string[],
): Promise<Claim[]> {
	const originalData = await readJsonFile(originalPath);
	const originalClaims = validateClaimArray(originalData, originalPath);

	const claimMap = new Map<string, Record<string, unknown>>();
	for (const claim of originalClaims) {
		claimMap.set(claim.id, { ...claim });
	}

	const originalCount = claimMap.size;

	for (const path of inputPaths) {
		const data = await readJsonFile(path);
		const updates = validateClaimArray(data, path);

		for (const update of updates) {
			const existing = claimMap.get(update.id);
			if (!existing) {
				throw new Error(
					`Update file "${path}" contains unknown claim id "${update.id}" not present in original`,
				);
			}
			claimMap.set(update.id, deepMerge(existing, update as Record<string, unknown>));
		}
	}

	if (claimMap.size !== originalCount) {
		throw new Error(
			`Claim count mismatch: original has ${originalCount.toString()} claims but result has ${claimMap.size.toString()}`,
		);
	}

	const originalOrder = originalClaims.map((c) => c.id);
	return originalOrder.map((id) => claimMap.get(id) as Claim);
}

/**
 * Executes a merge operation based on the provided options.
 * Returns a result object indicating success or failure.
 */
export async function merge(options: MergeOptions): Promise<MergeResult> {
	try {
		let result: unknown[];

		if (options.mode === "concat") {
			result = await mergeConcat(options.inputs);
		} else {
			if (!options.original) {
				return {
					ok: false,
					error: "Update mode requires an --original file path",
				};
			}
			result = await mergeUpdate(options.original, options.inputs);
		}

		const json = JSON.stringify(result, null, 2);

		try {
			JSON.parse(json);
		} catch {
			return { ok: false, error: "Output is not valid JSON" };
		}

		await writeFile(options.output, `${json}\n`, "utf-8");

		return {
			ok: true,
			claimCount: result.length,
			outputPath: options.output,
		};
	} catch (err: unknown) {
		const message = err instanceof Error ? err.message : "Unknown error";
		return { ok: false, error: message };
	}
}
