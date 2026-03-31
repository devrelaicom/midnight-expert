import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { processTemplate } from "./engine.js";

const FIXTURES = path.resolve(import.meta.dirname, "..", "test-fixtures", "sample-template");

describe("processTemplate", () => {
	let outputDir: string;

	beforeEach(() => {
		outputDir = fs.mkdtempSync(path.join(os.tmpdir(), "tmpl-test-"));
	});

	afterEach(() => {
		fs.rmSync(outputDir, { recursive: true, force: true });
	});

	it("copies all files from template to output", async () => {
		const result = await processTemplate({
			template: FIXTURES,
			output: path.join(outputDir, "out"),
			context: { NAME: "Alice", PROJECT: "my-app" },
		});

		expect(result.files).toBeGreaterThan(0);
		expect(fs.existsSync(path.join(result.output, "hello.txt"))).toBe(true);
		expect(fs.existsSync(path.join(result.output, "nested", "deep.ts"))).toBe(true);
	});

	it("substitutes {{KEY}} placeholders in text files", async () => {
		const result = await processTemplate({
			template: FIXTURES,
			output: path.join(outputDir, "out"),
			context: { NAME: "Alice", PROJECT: "my-app" },
		});

		const hello = fs.readFileSync(path.join(result.output, "hello.txt"), "utf-8");
		expect(hello).toBe("Hello, Alice! Welcome to my-app.\n");

		const deep = fs.readFileSync(path.join(result.output, "nested", "deep.ts"), "utf-8");
		expect(deep).toContain('export const app = "my-app"');
		expect(deep).toContain('export const greeting = "Hello Alice"');
	});

	it("strips .tmpl extension from files", async () => {
		const result = await processTemplate({
			template: FIXTURES,
			output: path.join(outputDir, "out"),
			context: { NAME: "Alice", PROJECT: "my-app" },
		});

		expect(fs.existsSync(path.join(result.output, "config.json"))).toBe(true);
		expect(fs.existsSync(path.join(result.output, "config.json.tmpl"))).toBe(false);

		const config = JSON.parse(fs.readFileSync(path.join(result.output, "config.json"), "utf-8"));
		expect(config.name).toBe("my-app");
	});

	it("copies binary files without substitution", async () => {
		const result = await processTemplate({
			template: FIXTURES,
			output: path.join(outputDir, "out"),
			context: { NAME: "Alice", PROJECT: "my-app" },
		});

		const original = fs.readFileSync(path.join(FIXTURES, "image.png"));
		const copied = fs.readFileSync(path.join(result.output, "image.png"));
		expect(copied).toEqual(original);
	});

	it("returns absolute output path and file count", async () => {
		const result = await processTemplate({
			template: FIXTURES,
			output: path.join(outputDir, "out"),
			context: { NAME: "Alice", PROJECT: "my-app" },
		});

		expect(path.isAbsolute(result.output)).toBe(true);
		expect(result.files).toBe(4); // hello.txt, config.json, nested/deep.ts, image.png
	});

	it("refuses to overwrite existing output directory", async () => {
		const outPath = path.join(outputDir, "out");
		fs.mkdirSync(outPath);

		await expect(
			processTemplate({
				template: FIXTURES,
				output: outPath,
				context: { NAME: "Alice", PROJECT: "my-app" },
			}),
		).rejects.toThrow("already exists");
	});

	it("throws when template directory does not exist", async () => {
		await expect(
			processTemplate({
				template: "/nonexistent/path",
				output: path.join(outputDir, "out"),
				context: { NAME: "Alice", PROJECT: "my-app" },
			}),
		).rejects.toThrow("does not exist");
	});
});
