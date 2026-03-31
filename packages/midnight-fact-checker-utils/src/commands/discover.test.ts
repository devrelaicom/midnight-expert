import { mkdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { discover } from "./discover.js";

const TEST_DIR = join(tmpdir(), "fact-checker-discover-test");

function createFile(relativePath: string, content = ""): void {
	const fullPath = join(TEST_DIR, relativePath);
	const dir = fullPath.substring(0, fullPath.lastIndexOf("/"));
	mkdirSync(dir, { recursive: true });
	writeFileSync(fullPath, content);
}

describe("discover", () => {
	beforeEach(() => {
		rmSync(TEST_DIR, { recursive: true, force: true });
		mkdirSync(TEST_DIR, { recursive: true });
	});

	afterEach(() => {
		rmSync(TEST_DIR, { recursive: true, force: true });
	});

	it("should match files by glob pattern", async () => {
		createFile("src/index.ts", "export {};");
		createFile("src/utils.ts", "export {};");
		createFile("src/readme.md", "# Hello");

		const result = await discover({
			pattern: "**/*.ts",
			cwd: TEST_DIR,
			gitignore: false,
		});

		const srcDir = result.directories.find((d) => d.directory === "src");
		expect(srcDir).toBeDefined();
		expect(srcDir?.matched).toContain("src/index.ts");
		expect(srcDir?.matched).toContain("src/utils.ts");
	});

	it("should classify unmatched files as GLOB_MISS when gitignore is disabled", async () => {
		createFile("src/index.ts", "export {};");
		createFile("src/readme.md", "# Hello");

		const result = await discover({
			pattern: "**/*.ts",
			cwd: TEST_DIR,
			gitignore: false,
		});

		const srcDir = result.directories.find((d) => d.directory === "src");
		expect(srcDir).toBeDefined();
		const unmatchedMd = srcDir?.unmatched.find((u) => u.path === "src/readme.md");
		expect(unmatchedMd).toBeDefined();
		expect(unmatchedMd?.reason).toBe("GLOB_MISS");
	});

	it("should classify gitignored files as GIT_IGNORED", async () => {
		// Create a minimal git repo for .gitignore detection
		mkdirSync(join(TEST_DIR, ".git"), { recursive: true });
		writeFileSync(join(TEST_DIR, ".gitignore"), "*.log\n");
		createFile("src/index.ts", "export {};");
		createFile("src/debug.log", "log content");

		const result = await discover({
			pattern: "**/*.ts",
			cwd: TEST_DIR,
			gitignore: true,
		});

		const srcDir = result.directories.find((d) => d.directory === "src");
		expect(srcDir).toBeDefined();

		const logFile = srcDir?.unmatched.find((u) => u.path === "src/debug.log");
		expect(logFile).toBeDefined();
		expect(logFile?.reason).toBe("GIT_IGNORED");
	});

	it("should respect --no-gitignore flag by treating all unmatched as GLOB_MISS", async () => {
		mkdirSync(join(TEST_DIR, ".git"), { recursive: true });
		writeFileSync(join(TEST_DIR, ".gitignore"), "*.log\n");
		createFile("src/index.ts", "export {};");
		createFile("src/debug.log", "log content");

		const result = await discover({
			pattern: "**/*.ts",
			cwd: TEST_DIR,
			gitignore: false,
		});

		const srcDir = result.directories.find((d) => d.directory === "src");
		const logFile = srcDir?.unmatched.find((u) => u.path === "src/debug.log");
		expect(logFile).toBeDefined();
		expect(logFile?.reason).toBe("GLOB_MISS");
	});

	it("should group results by directory", async () => {
		createFile("src/index.ts", "export {};");
		createFile("lib/helper.ts", "export {};");
		createFile("lib/utils.ts", "export {};");

		const result = await discover({
			pattern: "**/*.ts",
			cwd: TEST_DIR,
			gitignore: false,
		});

		const dirs = result.directories.map((d) => d.directory).sort();
		expect(dirs).toContain("lib");
		expect(dirs).toContain("src");

		const libDir = result.directories.find((d) => d.directory === "lib");
		expect(libDir?.matched).toHaveLength(2);
	});

	it("should handle nested directories", async () => {
		createFile("src/deep/nested/file.ts", "export {};");
		createFile("src/deep/nested/other.json", "{}");

		const result = await discover({
			pattern: "**/*.ts",
			cwd: TEST_DIR,
			gitignore: false,
		});

		const nestedDir = result.directories.find((d) => d.directory === "src/deep/nested");
		expect(nestedDir).toBeDefined();
		expect(nestedDir?.matched).toContain("src/deep/nested/file.ts");
		expect(nestedDir?.unmatched.find((u) => u.path === "src/deep/nested/other.json")).toBeDefined();
	});

	it("should return empty results for empty directories", async () => {
		// No files created, just the empty test dir

		const result = await discover({
			pattern: "**/*.ts",
			cwd: TEST_DIR,
			gitignore: false,
		});

		expect(result.directories).toHaveLength(0);
	});

	it("should handle patterns matching no files", async () => {
		createFile("src/index.js", "module.exports = {};");

		const result = await discover({
			pattern: "**/*.py",
			cwd: TEST_DIR,
			gitignore: false,
		});

		// No matched files, but unmatched should still be present
		const srcDir = result.directories.find((d) => d.directory === "src");
		expect(srcDir).toBeDefined();
		expect(srcDir?.matched).toHaveLength(0);
		expect(srcDir?.unmatched).toHaveLength(1);
	});
});
