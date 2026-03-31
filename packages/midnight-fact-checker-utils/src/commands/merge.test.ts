import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { deepMerge, merge, mergeConcat, mergeUpdate } from "./merge.js";

const TEST_DIR = join(tmpdir(), "fact-checker-merge-test");

function writeJson(filename: string, data: unknown): string {
	const fullPath = join(TEST_DIR, filename);
	writeFileSync(fullPath, JSON.stringify(data, null, 2));
	return fullPath;
}

function readJson(filename: string): unknown {
	return JSON.parse(readFileSync(join(TEST_DIR, filename), "utf-8")) as unknown;
}

describe("deepMerge", () => {
	it("should merge flat objects", () => {
		const base = { a: 1, b: 2 };
		const overlay = { b: 3, c: 4 };
		const result = deepMerge(base, overlay);
		expect(result).toEqual({ a: 1, b: 3, c: 4 });
	});

	it("should deep merge nested objects", () => {
		const base = {
			id: "1",
			metadata: { author: "Alice", tags: ["a"], nested: { deep: true, value: 1 } },
		};
		const overlay = {
			id: "1",
			metadata: { author: "Bob", nested: { value: 2 } },
		};
		const result = deepMerge(base, overlay);
		expect(result).toEqual({
			id: "1",
			metadata: {
				author: "Bob",
				tags: ["a"],
				nested: { deep: true, value: 2 },
			},
		});
	});

	it("should replace arrays instead of merging them", () => {
		const base = { tags: ["a", "b"] };
		const overlay = { tags: ["c"] };
		const result = deepMerge(base, overlay);
		expect(result).toEqual({ tags: ["c"] });
	});

	it("should handle null values in overlay", () => {
		const base = { a: 1, b: { nested: true } };
		const overlay = { b: null };
		const result = deepMerge(base, overlay);
		expect(result).toEqual({ a: 1, b: null });
	});

	it("should not mutate the base object", () => {
		const base = { a: 1, b: { nested: true } };
		const original = JSON.parse(JSON.stringify(base)) as typeof base;
		deepMerge(base, { a: 2 });
		expect(base).toEqual(original);
	});
});

describe("mergeConcat", () => {
	beforeEach(() => {
		rmSync(TEST_DIR, { recursive: true, force: true });
		mkdirSync(TEST_DIR, { recursive: true });
	});

	afterEach(() => {
		rmSync(TEST_DIR, { recursive: true, force: true });
	});

	it("should concatenate multiple JSON arrays", async () => {
		const file1 = writeJson("a.json", [{ id: "1", text: "one" }]);
		const file2 = writeJson("b.json", [{ id: "2", text: "two" }]);

		const result = await mergeConcat([file1, file2]);
		expect(result).toHaveLength(2);
		expect(result).toEqual([
			{ id: "1", text: "one" },
			{ id: "2", text: "two" },
		]);
	});

	it("should handle empty arrays", async () => {
		const file1 = writeJson("empty.json", []);
		const file2 = writeJson("data.json", [{ id: "1" }]);

		const result = await mergeConcat([file1, file2]);
		expect(result).toHaveLength(1);
	});

	it("should handle all empty arrays", async () => {
		const file1 = writeJson("empty1.json", []);
		const file2 = writeJson("empty2.json", []);

		const result = await mergeConcat([file1, file2]);
		expect(result).toHaveLength(0);
	});

	it("should throw on non-array JSON", async () => {
		const file = writeJson("obj.json", { not: "an array" });
		await expect(mergeConcat([file])).rejects.toThrow("Expected JSON array");
	});

	it("should throw on invalid JSON file", async () => {
		const fullPath = join(TEST_DIR, "bad.json");
		writeFileSync(fullPath, "not json at all");
		await expect(mergeConcat([fullPath])).rejects.toThrow("Invalid JSON");
	});
});

describe("mergeUpdate", () => {
	beforeEach(() => {
		rmSync(TEST_DIR, { recursive: true, force: true });
		mkdirSync(TEST_DIR, { recursive: true });
	});

	afterEach(() => {
		rmSync(TEST_DIR, { recursive: true, force: true });
	});

	it("should merge updates by id", async () => {
		const original = writeJson("original.json", [
			{ id: "1", text: "original one", status: "pending" },
			{ id: "2", text: "original two", status: "pending" },
		]);
		const update = writeJson("update.json", [
			{ id: "1", status: "verified" },
			{ id: "2", status: "rejected" },
		]);

		const result = await mergeUpdate(original, [update]);
		expect(result).toHaveLength(2);
		expect(result[0]).toEqual({ id: "1", text: "original one", status: "verified" });
		expect(result[1]).toEqual({ id: "2", text: "original two", status: "rejected" });
	});

	it("should deep merge nested objects in claims", async () => {
		const original = writeJson("original.json", [
			{
				id: "1",
				metadata: { author: "Alice", confidence: 0.5, sources: ["a"] },
			},
		]);
		const update = writeJson("update.json", [
			{
				id: "1",
				metadata: { confidence: 0.9, reviewed: true },
			},
		]);

		const result = await mergeUpdate(original, [update]);
		expect(result).toHaveLength(1);
		expect(result[0]).toEqual({
			id: "1",
			metadata: {
				author: "Alice",
				confidence: 0.9,
				sources: ["a"],
				reviewed: true,
			},
		});
	});

	it("should preserve original claim count", async () => {
		const original = writeJson("original.json", [
			{ id: "1", text: "one" },
			{ id: "2", text: "two" },
		]);
		// Only update one claim
		const update = writeJson("update.json", [{ id: "1", status: "done" }]);

		const result = await mergeUpdate(original, [update]);
		expect(result).toHaveLength(2);
	});

	it("should preserve original ordering", async () => {
		const original = writeJson("original.json", [
			{ id: "3", text: "three" },
			{ id: "1", text: "one" },
			{ id: "2", text: "two" },
		]);
		const update = writeJson("update.json", [{ id: "2", status: "done" }]);

		const result = await mergeUpdate(original, [update]);
		expect(result[0]?.id).toBe("3");
		expect(result[1]?.id).toBe("1");
		expect(result[2]?.id).toBe("2");
	});

	it("should reject updates with unknown ids", async () => {
		const original = writeJson("original.json", [{ id: "1", text: "one" }]);
		const update = writeJson("update.json", [{ id: "999", text: "unknown" }]);

		await expect(mergeUpdate(original, [update])).rejects.toThrow("unknown claim id");
	});

	it("should handle multiple update files applied sequentially", async () => {
		const original = writeJson("original.json", [{ id: "1", text: "one", status: "pending" }]);
		const update1 = writeJson("update1.json", [{ id: "1", status: "in-progress" }]);
		const update2 = writeJson("update2.json", [{ id: "1", status: "done" }]);

		const result = await mergeUpdate(original, [update1, update2]);
		expect(result[0]).toEqual({ id: "1", text: "one", status: "done" });
	});

	it("should throw if claim has no id field", async () => {
		const original = writeJson("original.json", [{ id: "1", text: "one" }]);
		const update = writeJson("update.json", [{ text: "no id" }]);

		await expect(mergeUpdate(original, [update])).rejects.toThrow('missing required "id" field');
	});
});

describe("merge (integration)", () => {
	beforeEach(() => {
		rmSync(TEST_DIR, { recursive: true, force: true });
		mkdirSync(TEST_DIR, { recursive: true });
	});

	afterEach(() => {
		rmSync(TEST_DIR, { recursive: true, force: true });
	});

	it("should write valid JSON output in concat mode", async () => {
		writeJson("a.json", [{ x: 1 }, { x: 2 }]);
		writeJson("b.json", [{ x: 3 }]);

		const result = await merge({
			mode: "concat",
			inputs: [join(TEST_DIR, "a.json"), join(TEST_DIR, "b.json")],
			output: join(TEST_DIR, "out.json"),
		});

		expect(result.ok).toBe(true);
		if (result.ok) {
			expect(result.claimCount).toBe(3);
		}

		const output = readJson("out.json");
		expect(Array.isArray(output)).toBe(true);
		expect(output).toHaveLength(3);
	});

	it("should write valid JSON output in update mode", async () => {
		writeJson("original.json", [
			{ id: "1", text: "one" },
			{ id: "2", text: "two" },
		]);
		writeJson("update.json", [{ id: "1", status: "done" }]);

		const result = await merge({
			mode: "update",
			original: join(TEST_DIR, "original.json"),
			inputs: [join(TEST_DIR, "update.json")],
			output: join(TEST_DIR, "out.json"),
		});

		expect(result.ok).toBe(true);
		if (result.ok) {
			expect(result.claimCount).toBe(2);
		}

		const output = readJson("out.json") as Array<Record<string, unknown>>;
		expect(output).toHaveLength(2);
		expect(output[0]).toEqual({ id: "1", text: "one", status: "done" });
	});

	it("should return failure for update mode without original", async () => {
		writeJson("update.json", [{ id: "1" }]);

		const result = await merge({
			mode: "update",
			inputs: [join(TEST_DIR, "update.json")],
			output: join(TEST_DIR, "out.json"),
		});

		expect(result.ok).toBe(false);
		if (!result.ok) {
			expect(result.error).toContain("--original");
		}
	});

	it("should return failure for invalid input files", async () => {
		writeFileSync(join(TEST_DIR, "bad.json"), "not json");

		const result = await merge({
			mode: "concat",
			inputs: [join(TEST_DIR, "bad.json")],
			output: join(TEST_DIR, "out.json"),
		});

		expect(result.ok).toBe(false);
		if (!result.ok) {
			expect(result.error).toContain("Invalid JSON");
		}
	});

	it("should return failure when update introduces unknown id", async () => {
		writeJson("original.json", [{ id: "1", text: "one" }]);
		writeJson("update.json", [{ id: "unknown", text: "bad" }]);

		const result = await merge({
			mode: "update",
			original: join(TEST_DIR, "original.json"),
			inputs: [join(TEST_DIR, "update.json")],
			output: join(TEST_DIR, "out.json"),
		});

		expect(result.ok).toBe(false);
		if (!result.ok) {
			expect(result.error).toContain("unknown claim id");
		}
	});
});
