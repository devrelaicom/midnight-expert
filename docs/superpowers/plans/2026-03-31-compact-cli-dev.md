# compact-cli-dev Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code plugin that scaffolds production-quality Oclif CLIs for Midnight Compact smart contracts, backed by a reusable template engine package.

**Architecture:** Three deliverables built in order: (1) a generic `@aaronbassett/template-engine` npm package that copies directories with `{{PLACEHOLDER}}` substitution via JSON-over-stdin, (2) a complete Oclif CLI template with 12 built-in commands for wallet/contract/devnet management, and (3) a `compact-cli-dev` Claude Code plugin with a skill, agent, and init command that wires it all together.

**Tech Stack:** TypeScript (ESM, strict mode), Oclif 4, Vitest, Biome, Node.js builtins only for template engine, Midnight wallet-sdk-facade/HD/shielded/unshielded/dust, midnight-js-contracts, RxJS, ora, cli-progress.

**Spec:** `docs/superpowers/specs/2026-03-31-compact-cli-dev-design.md`

---

## Phase 1: Template Engine Package

### Task 1: Template engine — package scaffold and binary detection

**Files:**
- Create: `packages/template-engine/package.json`
- Create: `packages/template-engine/tsconfig.json`
- Create: `packages/template-engine/biome.json`
- Create: `packages/template-engine/src/detect-binary.ts`
- Create: `packages/template-engine/src/detect-binary.test.ts`

- [ ] **Step 1: Create `package.json`**

```json
{
	"name": "@aaronbassett/template-engine",
	"version": "0.1.0",
	"description": "Generic template directory copier with placeholder substitution. Reads JSON from stdin, copies a template directory, replaces {{KEY}} placeholders, writes result to stdout.",
	"type": "module",
	"license": "MIT",
	"author": {
		"name": "Aaron Bassett",
		"email": "aaron@devrel-ai.com"
	},
	"repository": {
		"type": "git",
		"url": "https://github.com/devrelaicom/midnight-expert.git",
		"directory": "packages/template-engine"
	},
	"publishConfig": {
		"access": "public"
	},
	"engines": {
		"node": ">=20"
	},
	"bin": {
		"template-engine": "./dist/index.js"
	},
	"main": "./dist/index.js",
	"types": "./dist/index.d.ts",
	"exports": {
		".": {
			"types": "./dist/index.d.ts",
			"import": "./dist/index.js"
		},
		"./engine": {
			"types": "./dist/engine.d.ts",
			"import": "./dist/engine.js"
		}
	},
	"files": ["dist"],
	"scripts": {
		"build": "tsc",
		"check": "tsc --noEmit",
		"test": "vitest run",
		"test:watch": "vitest",
		"lint": "biome check .",
		"format:check": "biome format ."
	},
	"devDependencies": {
		"@biomejs/biome": "^1.9.4",
		"@types/node": "^20.17.0",
		"typescript": "^5.7.0",
		"vitest": "^3.0.0"
	}
}
```

- [ ] **Step 2: Create `tsconfig.json`**

```json
{
	"compilerOptions": {
		"strict": true,
		"noImplicitAny": true,
		"noImplicitReturns": true,
		"noUncheckedIndexedAccess": true,
		"strictNullChecks": true,
		"strictPropertyInitialization": true,
		"useUnknownInCatchVariables": true,
		"exactOptionalPropertyTypes": true,
		"noImplicitOverride": true,
		"module": "NodeNext",
		"moduleResolution": "NodeNext",
		"resolveJsonModule": true,
		"esModuleInterop": true,
		"forceConsistentCasingInFileNames": true,
		"target": "ES2022",
		"lib": ["ES2022"],
		"outDir": "./dist",
		"declaration": true,
		"declarationMap": true,
		"sourceMap": true,
		"isolatedModules": true,
		"allowSyntheticDefaultImports": true,
		"skipLibCheck": true,
		"incremental": true
	},
	"include": ["src/**/*"],
	"exclude": ["node_modules", "dist", "**/*.test.ts"]
}
```

- [ ] **Step 3: Create `biome.json`**

```json
{
	"$schema": "https://biomejs.dev/schemas/1.9.4/schema.json",
	"files": {
		"include": ["src/**/*.ts", "*.json"],
		"ignore": ["**/node_modules/**", "**/dist/**", "**/coverage/**"]
	},
	"organizeImports": {
		"enabled": true
	},
	"linter": {
		"enabled": true,
		"rules": {
			"recommended": true,
			"correctness": {
				"noUnusedImports": "error",
				"noUnusedVariables": "error"
			},
			"suspicious": {
				"noExplicitAny": "error"
			},
			"style": {
				"noNonNullAssertion": "warn",
				"useConst": "error"
			}
		}
	},
	"formatter": {
		"enabled": true,
		"indentStyle": "tab",
		"lineWidth": 100
	},
	"javascript": {
		"formatter": {
			"quoteStyle": "double",
			"semicolons": "always"
		}
	},
	"json": {
		"formatter": {
			"indentStyle": "tab"
		}
	}
}
```

- [ ] **Step 4: Write failing test for binary detection**

Create `packages/template-engine/src/detect-binary.test.ts`:

```typescript
import { describe, expect, it } from "vitest";
import { isBinaryPath } from "./detect-binary.js";

describe("isBinaryPath", () => {
	it("returns true for image files", () => {
		expect(isBinaryPath("photo.png")).toBe(true);
		expect(isBinaryPath("icon.jpg")).toBe(true);
		expect(isBinaryPath("icon.jpeg")).toBe(true);
		expect(isBinaryPath("logo.gif")).toBe(true);
		expect(isBinaryPath("img.webp")).toBe(true);
		expect(isBinaryPath("icon.ico")).toBe(true);
		expect(isBinaryPath("icon.svg")).toBe(false); // SVG is text
	});

	it("returns true for font files", () => {
		expect(isBinaryPath("font.woff")).toBe(true);
		expect(isBinaryPath("font.woff2")).toBe(true);
		expect(isBinaryPath("font.ttf")).toBe(true);
		expect(isBinaryPath("font.eot")).toBe(true);
		expect(isBinaryPath("font.otf")).toBe(true);
	});

	it("returns true for archive and compiled files", () => {
		expect(isBinaryPath("archive.zip")).toBe(true);
		expect(isBinaryPath("archive.tar.gz")).toBe(true);
		expect(isBinaryPath("lib.wasm")).toBe(true);
		expect(isBinaryPath("app.exe")).toBe(true);
	});

	it("returns false for text files", () => {
		expect(isBinaryPath("file.ts")).toBe(false);
		expect(isBinaryPath("file.js")).toBe(false);
		expect(isBinaryPath("file.json")).toBe(false);
		expect(isBinaryPath("file.md")).toBe(false);
		expect(isBinaryPath("file.yml")).toBe(false);
		expect(isBinaryPath("file.yaml")).toBe(false);
		expect(isBinaryPath("file.html")).toBe(false);
		expect(isBinaryPath("file.css")).toBe(false);
		expect(isBinaryPath("file.sh")).toBe(false);
		expect(isBinaryPath("file.txt")).toBe(false);
		expect(isBinaryPath("Dockerfile")).toBe(false);
	});

	it("returns false for dotfiles", () => {
		expect(isBinaryPath(".gitignore")).toBe(false);
		expect(isBinaryPath(".eslintrc")).toBe(false);
	});

	it("returns false for extensionless files", () => {
		expect(isBinaryPath("Makefile")).toBe(false);
		expect(isBinaryPath("LICENSE")).toBe(false);
	});
});
```

- [ ] **Step 5: Run test to verify it fails**

Run: `cd packages/template-engine && npm install && npx vitest run src/detect-binary.test.ts`
Expected: FAIL — module not found

- [ ] **Step 6: Implement binary detection**

Create `packages/template-engine/src/detect-binary.ts`:

```typescript
import path from "node:path";

const BINARY_EXTENSIONS = new Set([
	// Images
	".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".ico", ".tiff", ".tif",
	// Fonts
	".woff", ".woff2", ".ttf", ".eot", ".otf",
	// Archives
	".zip", ".tar", ".gz", ".bz2", ".7z", ".rar",
	// Compiled / binary
	".wasm", ".exe", ".dll", ".so", ".dylib", ".o", ".a",
	// Media
	".mp3", ".mp4", ".avi", ".mov", ".flv", ".ogg", ".wav",
	// Documents
	".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx",
	// Database
	".sqlite", ".db",
]);

export function isBinaryPath(filePath: string): boolean {
	const ext = path.extname(filePath).toLowerCase();
	return BINARY_EXTENSIONS.has(ext);
}
```

- [ ] **Step 7: Run test to verify it passes**

Run: `cd packages/template-engine && npx vitest run src/detect-binary.test.ts`
Expected: PASS — all assertions green

- [ ] **Step 8: Commit**

```bash
git add packages/template-engine/package.json packages/template-engine/tsconfig.json packages/template-engine/biome.json packages/template-engine/src/detect-binary.ts packages/template-engine/src/detect-binary.test.ts
git commit -m "feat(template-engine): scaffold package with binary detection"
```

---

### Task 2: Template engine — core engine (copy, substitute, rename)

**Files:**
- Create: `packages/template-engine/src/engine.ts`
- Create: `packages/template-engine/src/engine.test.ts`
- Create: `packages/template-engine/test-fixtures/sample-template/hello.txt`
- Create: `packages/template-engine/test-fixtures/sample-template/config.json.tmpl`
- Create: `packages/template-engine/test-fixtures/sample-template/nested/deep.ts`
- Create: `packages/template-engine/test-fixtures/sample-template/image.png`

- [ ] **Step 1: Create test fixtures**

Create `packages/template-engine/test-fixtures/sample-template/hello.txt`:
```
Hello, {{NAME}}! Welcome to {{PROJECT}}.
```

Create `packages/template-engine/test-fixtures/sample-template/config.json.tmpl`:
```json
{
	"name": "{{PROJECT}}",
	"version": "1.0.0"
}
```

Create `packages/template-engine/test-fixtures/sample-template/nested/deep.ts`:
```typescript
export const app = "{{PROJECT}}";
export const greeting = "Hello {{NAME}}";
```

Create `packages/template-engine/test-fixtures/sample-template/image.png` — a 1-byte file (any binary content):
```bash
printf '\x89PNG' > packages/template-engine/test-fixtures/sample-template/image.png
```

- [ ] **Step 2: Write failing tests for the engine**

Create `packages/template-engine/src/engine.test.ts`:

```typescript
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

		const config = JSON.parse(
			fs.readFileSync(path.join(result.output, "config.json"), "utf-8"),
		);
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
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd packages/template-engine && npx vitest run src/engine.test.ts`
Expected: FAIL — `processTemplate` not found

- [ ] **Step 4: Implement the engine**

Create `packages/template-engine/src/engine.ts`:

```typescript
import fs from "node:fs";
import path from "node:path";
import { isBinaryPath } from "./detect-binary.js";

export interface TemplateInput {
	template: string;
	output: string;
	context: Record<string, string>;
}

export interface TemplateResult {
	output: string;
	files: number;
}

function substitute(content: string, context: Record<string, string>): string {
	let result = content;
	for (const [key, value] of Object.entries(context)) {
		const pattern = new RegExp(`\\{\\{${key}\\}\\}`, "g");
		result = result.replace(pattern, value);
	}
	return result;
}

function copyRecursive(
	src: string,
	dest: string,
	context: Record<string, string>,
): number {
	let fileCount = 0;
	const entries = fs.readdirSync(src, { withFileTypes: true });

	for (const entry of entries) {
		const srcPath = path.join(src, entry.name);

		// Determine output filename — strip .tmpl extension
		const outputName = entry.name.endsWith(".tmpl")
			? entry.name.slice(0, -5)
			: entry.name;
		const destPath = path.join(dest, outputName);

		if (entry.isDirectory()) {
			fs.mkdirSync(destPath, { recursive: true });
			fileCount += copyRecursive(srcPath, destPath, context);
		} else {
			if (isBinaryPath(srcPath)) {
				fs.copyFileSync(srcPath, destPath);
			} else {
				const content = fs.readFileSync(srcPath, "utf-8");
				fs.writeFileSync(destPath, substitute(content, context));
			}
			fileCount++;
		}
	}

	return fileCount;
}

export async function processTemplate(input: TemplateInput): Promise<TemplateResult> {
	const templateDir = path.resolve(input.template);
	const outputDir = path.resolve(input.output);

	if (!fs.existsSync(templateDir)) {
		throw new Error(`Template directory does not exist: ${templateDir}`);
	}

	if (fs.existsSync(outputDir)) {
		throw new Error(`Output directory already exists: ${outputDir}`);
	}

	fs.mkdirSync(outputDir, { recursive: true });
	const fileCount = copyRecursive(templateDir, outputDir, input.context);

	return {
		output: outputDir,
		files: fileCount,
	};
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd packages/template-engine && npx vitest run src/engine.test.ts`
Expected: PASS — all 7 tests green

- [ ] **Step 6: Commit**

```bash
git add packages/template-engine/src/engine.ts packages/template-engine/src/engine.test.ts packages/template-engine/test-fixtures/
git commit -m "feat(template-engine): implement core copy/substitute/rename engine"
```

---

### Task 3: Template engine — stdin/stdout CLI entry point

**Files:**
- Create: `packages/template-engine/src/index.ts`
- Create: `packages/template-engine/src/index.test.ts`

- [ ] **Step 1: Write failing test for the CLI entry point**

Create `packages/template-engine/src/index.test.ts`:

```typescript
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

const FIXTURES = path.resolve(import.meta.dirname, "..", "test-fixtures", "sample-template");
const CLI_PATH = path.resolve(import.meta.dirname, "index.ts");

function runCli(input: string): { stdout: string; stderr: string; exitCode: number } {
	try {
		const stdout = execFileSync("npx", ["tsx", CLI_PATH], {
			input,
			encoding: "utf-8",
			cwd: path.resolve(import.meta.dirname, ".."),
			timeout: 10_000,
		});
		return { stdout, stderr: "", exitCode: 0 };
	} catch (error: unknown) {
		const e = error as { stdout?: string; stderr?: string; status?: number };
		return {
			stdout: e.stdout ?? "",
			stderr: e.stderr ?? "",
			exitCode: e.status ?? 1,
		};
	}
}

describe("template-engine CLI", () => {
	let tmpDir: string;

	beforeEach(() => {
		tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "tmpl-cli-test-"));
	});

	afterEach(() => {
		fs.rmSync(tmpDir, { recursive: true, force: true });
	});

	it("processes template from stdin JSON and writes result to stdout", () => {
		const outDir = path.join(tmpDir, "out");
		const input = JSON.stringify({
			template: FIXTURES,
			output: outDir,
			context: { NAME: "Bob", PROJECT: "test-proj" },
		});

		const { stdout, exitCode } = runCli(input);
		expect(exitCode).toBe(0);

		const result = JSON.parse(stdout) as { output: string; files: number };
		expect(result.files).toBe(4);
		expect(fs.existsSync(path.join(outDir, "hello.txt"))).toBe(true);

		const hello = fs.readFileSync(path.join(outDir, "hello.txt"), "utf-8");
		expect(hello).toContain("Bob");
	});

	it("exits with code 1 and writes error JSON to stderr on invalid input", () => {
		const { stderr, exitCode } = runCli("not json");
		expect(exitCode).toBe(1);
		const errResult = JSON.parse(stderr) as { error: string };
		expect(errResult.error).toBeDefined();
	});

	it("exits with code 1 when template dir does not exist", () => {
		const input = JSON.stringify({
			template: "/nonexistent",
			output: path.join(tmpDir, "out"),
			context: {},
		});

		const { stderr, exitCode } = runCli(input);
		expect(exitCode).toBe(1);
		const errResult = JSON.parse(stderr) as { error: string };
		expect(errResult.error).toContain("does not exist");
	});
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/template-engine && npx vitest run src/index.test.ts`
Expected: FAIL — `index.ts` not found or not executable

- [ ] **Step 3: Implement the CLI entry point**

Create `packages/template-engine/src/index.ts`:

```typescript
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
		typeof obj["template"] === "string" &&
		typeof obj["output"] === "string" &&
		typeof obj["context"] === "object" &&
		obj["context"] !== null
	);
}

async function main(): Promise<void> {
	let raw: string;
	try {
		raw = await readStdin();
	} catch {
		process.stderr.write(JSON.stringify({ error: "Failed to read stdin" }) + "\n");
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
		process.stderr.write(JSON.stringify({ error: message }) + "\n");
		process.exit(1);
	}

	try {
		const result = await processTemplate(input);
		process.stdout.write(JSON.stringify(result) + "\n");
	} catch (err) {
		const message = err instanceof Error ? err.message : "Template processing failed";
		process.stderr.write(JSON.stringify({ error: message }) + "\n");
		process.exit(1);
	}
}

main();
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/template-engine && npx vitest run src/index.test.ts`
Expected: PASS — all 3 tests green

- [ ] **Step 5: Run all tests and lint**

Run: `cd packages/template-engine && npx vitest run && npx biome check . && npx tsc --noEmit`
Expected: All pass

- [ ] **Step 6: Build the package**

Run: `cd packages/template-engine && npm run build`
Expected: Clean compilation to `dist/`

- [ ] **Step 7: Commit**

```bash
git add packages/template-engine/src/index.ts packages/template-engine/src/index.test.ts
git commit -m "feat(template-engine): add stdin/stdout CLI entry point"
```

---

## Phase 2: CLI Template

This phase creates all the template files that live inside `plugins/compact-cli-dev/skills/core/templates/cli/`. These are static files with `{{PLACEHOLDER}}` markers — they are NOT executed during this phase. They are the payload the template engine stamps out.

**Important:** All TypeScript files in the template use `{{PLACEHOLDER}}` syntax in import paths, package names, etc. The template engine substitutes these at scaffold time. The files must be syntactically valid TypeScript AFTER substitution, not necessarily before.

### Task 4: CLI template — project config files

**Files:**
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/package.json.tmpl`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/tsconfig.json`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/biome.json`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/.gitignore`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/bin/run.ts`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/bin/dev.ts`

- [ ] **Step 1: Create `package.json.tmpl`**

```json
{
	"name": "{{CLI_PACKAGE_NAME}}",
	"version": "0.1.0",
	"description": "CLI for interacting with the {{CONTRACT_NAME}} contract on Midnight devnet",
	"type": "module",
	"license": "MIT",
	"oclif": {
		"bin": "{{CLI_PACKAGE_NAME}}",
		"dirname": "{{CLI_PACKAGE_NAME}}",
		"commands": {
			"strategy": "pattern",
			"target": "./dist/commands"
		},
		"topicSeparator": ":"
	},
	"bin": {
		"{{CLI_PACKAGE_NAME}}": "./bin/run.ts"
	},
	"scripts": {
		"build": "tsc",
		"check": "tsc --noEmit",
		"dev": "tsx ./bin/dev.ts",
		"test": "vitest run",
		"test:watch": "vitest",
		"lint": "biome check .",
		"lint:fix": "biome check --write .",
		"format": "biome format --write .",
		"prepare": "husky"
	},
	"dependencies": {
		"{{CONTRACT_PACKAGE}}": "*",
		"@midnight-ntwrk/compact-runtime": "0.15.0",
		"@midnight-ntwrk/compact-js": "^4.0.0",
		"@midnight-ntwrk/ledger-v8": "^8.0.0",
		"@midnight-ntwrk/midnight-js-contracts": "^4.0.0",
		"@midnight-ntwrk/midnight-js-http-client-proof-provider": "^4.0.0",
		"@midnight-ntwrk/midnight-js-indexer-public-data-provider": "^4.0.0",
		"@midnight-ntwrk/midnight-js-level-private-state-provider": "^4.0.0",
		"@midnight-ntwrk/midnight-js-network-id": "^4.0.0",
		"@midnight-ntwrk/midnight-js-node-zk-config-provider": "^4.0.0",
		"@midnight-ntwrk/midnight-js-types": "^4.0.0",
		"@midnight-ntwrk/midnight-js-utils": "^4.0.0",
		"@midnight-ntwrk/wallet-sdk-address-format": "^3.0.0",
		"@midnight-ntwrk/wallet-sdk-dust-wallet": "^3.0.0",
		"@midnight-ntwrk/wallet-sdk-facade": "^3.0.0",
		"@midnight-ntwrk/wallet-sdk-hd": "^3.0.0",
		"@midnight-ntwrk/wallet-sdk-shielded": "^2.0.0",
		"@midnight-ntwrk/wallet-sdk-unshielded-wallet": "^2.0.0",
		"@oclif/core": "^4.0.0",
		"cli-progress": "^3.12.0",
		"ora": "^8.0.0",
		"rxjs": "^7.8.0",
		"ws": "^8.19.0"
	},
	"devDependencies": {
		"@biomejs/biome": "^1.9.4",
		"@oclif/test": "^4.0.0",
		"@types/cli-progress": "^3.11.6",
		"@types/node": "^20.17.0",
		"@types/ws": "^8.18.1",
		"husky": "^9.0.0",
		"tsx": "^4.21.0",
		"typescript": "^5.7.0",
		"vitest": "^3.0.0"
	},
	"generated": "{{GENERATED_AT}}"
}
```

- [ ] **Step 2: Create `tsconfig.json`**

Same content as the template-engine tsconfig.json from Task 1, Step 2. Copy it to `plugins/compact-cli-dev/skills/core/templates/cli/tsconfig.json`.

- [ ] **Step 3: Create `biome.json`**

Same content as the template-engine biome.json from Task 1, Step 3. Copy it to `plugins/compact-cli-dev/skills/core/templates/cli/biome.json`.

- [ ] **Step 4: Create `.gitignore`**

```
node_modules/
dist/
coverage/
.midnight-expert/
*.tsbuildinfo
```

- [ ] **Step 5: Create `bin/run.ts`**

```typescript
#!/usr/bin/env tsx
import { execute } from "@oclif/core";

await execute({ dir: import.meta.url });
```

- [ ] **Step 6: Create `bin/dev.ts`**

```typescript
#!/usr/bin/env tsx
// Dev mode — uses ts-node for live reloading
import { execute } from "@oclif/core";

await execute({ development: true, dir: import.meta.url });
```

- [ ] **Step 7: Commit**

```bash
git add plugins/compact-cli-dev/skills/core/templates/cli/
git commit -m "feat(compact-cli-dev): add CLI template project config files"
```

---

### Task 5: CLI template — constants, config, errors, progress

**Files:**
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/lib/constants.ts`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/lib/config.ts`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/lib/errors.ts`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/lib/progress.ts`

- [ ] **Step 1: Create `src/lib/constants.ts`**

```typescript
import path from "node:path";

// File system
export const STATE_DIR = ".midnight-expert";
export const WALLETS_FILE = "wallets.json";
export const CONTRACTS_FILE = "deployed-contracts.json";
export const INIT_MARKER = ".initialized";
export const DIR_MODE = 0o700;
export const FILE_MODE_PRIVATE = 0o600;
export const FILE_MODE_PUBLIC = 0o644;

// Wallet
export const GENESIS_SEED = "0000000000000000000000000000000000000000000000000000000000000001";
export const SEED_LENGTH = 64; // hex chars = 32 bytes

// Network
export const DEFAULT_TTL_MINUTES = 10;

// Fees
export const ADDITIONAL_FEE_OVERHEAD = 300_000_000_000_000n;
export const FEE_BLOCKS_MARGIN = 5;
export const DUST_MIN_REQUIREMENT = 800_000_000_000_000n;

// Timeouts (ms)
export const WALLET_SYNC_TIMEOUT = 120_000;
export const DUST_GENERATION_TIMEOUT = 120_000;
export const DUST_POLL_INTERVAL = 5_000;
export const FUND_POLL_INTERVAL = 10_000;
export const PROOF_TIMEOUT = 300_000;

// Retry
export const MAX_RETRIES = 3;

// Token precision
export const NIGHT_DECIMALS = 6;
export const DUST_DECIMALS = 15;

// Devnet compose file search order
export const COMPOSE_SEARCH_PATHS = [
	"devnet.yml",
	path.join(".midnight", "devnet.yml"),
];
export const COMPOSE_FALLBACK = path.join(
	process.env["HOME"] ?? "~",
	".midnight-expert",
	"devnet",
	"devnet.yml",
);

// Contract
export const ZK_CONFIG_PATH = "{{CONTRACT_ZK_CONFIG_PATH}}";
export const CONTRACT_NAME = "{{CONTRACT_NAME}}";
```

- [ ] **Step 2: Create `src/lib/config.ts`**

```typescript
import { setNetworkId } from "@midnight-ntwrk/midnight-js-network-id";

export interface NetworkConfig {
	readonly indexer: string;
	readonly indexerWS: string;
	readonly node: string;
	readonly proofServer: string;
	readonly networkId: string;
}

export const DEVNET_CONFIG: NetworkConfig = {
	indexer: "http://127.0.0.1:8088/api/v3/graphql",
	indexerWS: "ws://127.0.0.1:8088/api/v3/graphql/ws",
	node: "http://127.0.0.1:9944",
	proofServer: "http://127.0.0.1:6300",
	networkId: "undeployed",
};

export function initializeNetwork(): void {
	setNetworkId(DEVNET_CONFIG.networkId);
}
```

- [ ] **Step 3: Create `src/lib/errors.ts`**

```typescript
export enum ErrorCode {
	DUST_REQUIRED = "DUST_REQUIRED",
	SERVICE_DOWN = "SERVICE_DOWN",
	CONTRACT_NOT_FOUND = "CONTRACT_NOT_FOUND",
	WALLET_NOT_FOUND = "WALLET_NOT_FOUND",
	STALE_UTXO = "STALE_UTXO",
	SYNC_TIMEOUT = "SYNC_TIMEOUT",
	INVALID_SEED = "INVALID_SEED",
	UNKNOWN = "UNKNOWN",
}

interface ClassifiedError {
	code: ErrorCode;
	message: string;
	action: string;
}

const CLI_NAME = "{{CLI_PACKAGE_NAME}}";

export function classifyError(err: unknown): ClassifiedError {
	const message = err instanceof Error ? err.message : String(err);
	const lower = message.toLowerCase();

	if (lower.includes("dust") || lower.includes("no dust") || lower.includes("insufficient fee")) {
		return {
			code: ErrorCode.DUST_REQUIRED,
			message,
			action: `Run \`${CLI_NAME} dust:register <wallet>\` to generate DUST tokens.`,
		};
	}

	if (lower.includes("econnrefused") && lower.includes("6300")) {
		return {
			code: ErrorCode.SERVICE_DOWN,
			message: "Proof server is not reachable at localhost:6300.",
			action: `Run \`${CLI_NAME} devnet:start\` to start all services.`,
		};
	}

	if (lower.includes("econnrefused") && (lower.includes("8088") || lower.includes("9944"))) {
		return {
			code: ErrorCode.SERVICE_DOWN,
			message: "Devnet services are not reachable.",
			action: `Run \`${CLI_NAME} devnet:status\` to check which services are down.`,
		};
	}

	if (lower.includes("contract") && lower.includes("not found")) {
		return {
			code: ErrorCode.CONTRACT_NOT_FOUND,
			message,
			action: "Verify the contract address and that the devnet is running.",
		};
	}

	if (lower.includes("timeout") || lower.includes("timed out")) {
		return {
			code: ErrorCode.SYNC_TIMEOUT,
			message,
			action: "The devnet may still be starting. Wait a moment and retry.",
		};
	}

	return {
		code: ErrorCode.UNKNOWN,
		message,
		action: "Check the devnet logs for more details.",
	};
}

export function formatError(classified: ClassifiedError): string {
	return `Error [${classified.code}]: ${classified.message}\n  → ${classified.action}`;
}
```

- [ ] **Step 4: Create `src/lib/progress.ts`**

```typescript
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
```

- [ ] **Step 5: Commit**

```bash
git add plugins/compact-cli-dev/skills/core/templates/cli/src/lib/
git commit -m "feat(compact-cli-dev): add template lib — constants, config, errors, progress"
```

---

### Task 6: CLI template — wallet management

**Files:**
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/lib/wallet.ts`

- [ ] **Step 1: Create `src/lib/wallet.ts`**

```typescript
import fs from "node:fs";
import path from "node:path";
import * as ledger from "@midnight-ntwrk/ledger-v8";
import { getNetworkId } from "@midnight-ntwrk/midnight-js-network-id";
import { WalletFacade } from "@midnight-ntwrk/wallet-sdk-facade";
import { DustWallet } from "@midnight-ntwrk/wallet-sdk-dust-wallet";
import { HDWallet, Roles, generateRandomSeed } from "@midnight-ntwrk/wallet-sdk-hd";
import { ShieldedWallet } from "@midnight-ntwrk/wallet-sdk-shielded";
import {
	createKeystore,
	InMemoryTransactionHistoryStorage,
	PublicKey,
	UnshieldedWallet,
	type UnshieldedKeystore,
} from "@midnight-ntwrk/wallet-sdk-unshielded-wallet";
import { WebSocket } from "ws";
import {
	ADDITIONAL_FEE_OVERHEAD,
	FEE_BLOCKS_MARGIN,
	FILE_MODE_PRIVATE,
	DIR_MODE,
	SEED_LENGTH,
	STATE_DIR,
	WALLETS_FILE,
} from "./constants.js";

// Required for GraphQL subscriptions in Node.js
// @ts-expect-error WebSocket polyfill for apollo client
globalThis.WebSocket = WebSocket;

// --- Types ---

export interface StoredWallet {
	seed: string;
	address: string;
	createdAt: string;
}

export interface WalletStore {
	[name: string]: StoredWallet;
}

export interface WalletContext {
	facade: WalletFacade;
	shieldedSecretKeys: ledger.ZswapSecretKeys;
	dustSecretKey: ledger.DustSecretKey;
	keystore: UnshieldedKeystore;
}

// --- Seed & Key Derivation ---

export function newSeed(): string {
	return Buffer.from(generateRandomSeed()).toString("hex");
}

export function deriveKeys(seed: string): {
	zswap: Uint8Array;
	nightExternal: Uint8Array;
	dust: Uint8Array;
} {
	if (seed.length !== SEED_LENGTH) {
		throw new Error(`Invalid seed length: expected ${String(SEED_LENGTH)} hex chars, got ${String(seed.length)}`);
	}
	const hdWallet = HDWallet.fromSeed(Buffer.from(seed, "hex"));
	if (hdWallet.type !== "seedOk") {
		throw new Error("Invalid seed: HD wallet derivation failed");
	}
	const result = hdWallet.hdWallet
		.selectAccount(0)
		.selectRoles([Roles.Zswap, Roles.NightExternal, Roles.Dust])
		.deriveKeysAt(0);
	if (result.type !== "keysDerived") {
		throw new Error("Key derivation failed");
	}
	hdWallet.hdWallet.clear();
	return {
		zswap: result.keys[Roles.Zswap],
		nightExternal: result.keys[Roles.NightExternal],
		dust: result.keys[Roles.Dust],
	};
}

// --- WalletFacade Building ---

export async function buildFacade(seed: string): Promise<WalletContext> {
	const keys = deriveKeys(seed);
	const networkId = getNetworkId();

	const shieldedSecretKeys = ledger.ZswapSecretKeys.fromSeed(keys.zswap);
	const dustSecretKey = ledger.DustSecretKey.fromSeed(keys.dust);
	const keystore = createKeystore(keys.nightExternal, networkId);

	const walletConfig = {
		networkId,
		indexerClientConnection: {
			indexerHttpUrl: "http://127.0.0.1:8088/api/v3/graphql",
			indexerWsUrl: "ws://127.0.0.1:8088/api/v3/graphql/ws",
		},
		costParameters: {
			additionalFeeOverhead: ADDITIONAL_FEE_OVERHEAD,
			feeBlocksMargin: FEE_BLOCKS_MARGIN,
		},
		txHistoryStorage: new InMemoryTransactionHistoryStorage(),
	};

	const facade = await WalletFacade.init({
		configuration: walletConfig,
		shielded: (cfg) => ShieldedWallet(cfg).startWithSecretKeys(shieldedSecretKeys),
		unshielded: (cfg) =>
			UnshieldedWallet({
				...cfg,
				txHistoryStorage: new InMemoryTransactionHistoryStorage(),
			}).startWithPublicKey(PublicKey.fromKeyStore(keystore)),
		dust: (cfg) =>
			DustWallet(cfg).startWithSecretKey(
				dustSecretKey,
				ledger.LedgerParameters.initialParameters().dust,
			),
	});

	return { facade, shieldedSecretKeys, dustSecretKey, keystore };
}

// --- Persistence ---

function walletsPath(): string {
	return path.join(process.cwd(), STATE_DIR, WALLETS_FILE);
}

function ensureStateDir(): void {
	const dir = path.join(process.cwd(), STATE_DIR);
	if (!fs.existsSync(dir)) {
		fs.mkdirSync(dir, { mode: DIR_MODE, recursive: true });
	}
}

export function loadWallets(): WalletStore {
	const filePath = walletsPath();
	if (!fs.existsSync(filePath)) {
		return {};
	}
	const raw = fs.readFileSync(filePath, "utf-8");
	return JSON.parse(raw) as WalletStore;
}

export function saveWallets(store: WalletStore): void {
	ensureStateDir();
	const filePath = walletsPath();
	fs.writeFileSync(filePath, JSON.stringify(store, null, "\t") + "\n", {
		mode: FILE_MODE_PRIVATE,
	});
}

export function getWallet(name: string): StoredWallet {
	const store = loadWallets();
	const wallet = store[name];
	if (!wallet) {
		throw new Error(
			`Wallet "${name}" not found. Run \`wallet:create ${name}\` to create it.`,
		);
	}
	return wallet;
}

export function saveWallet(name: string, wallet: StoredWallet): void {
	const store = loadWallets();
	store[name] = wallet;
	saveWallets(store);
}
```

- [ ] **Step 2: Commit**

```bash
git add plugins/compact-cli-dev/skills/core/templates/cli/src/lib/wallet.ts
git commit -m "feat(compact-cli-dev): add template lib — wallet management"
```

---

### Task 7: CLI template — providers, funding, contract

**Files:**
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/lib/providers.ts`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/lib/funding.ts`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/lib/contract.ts`

- [ ] **Step 1: Create `src/lib/providers.ts`**

```typescript
import { httpClientProofProvider } from "@midnight-ntwrk/midnight-js-http-client-proof-provider";
import { indexerPublicDataProvider } from "@midnight-ntwrk/midnight-js-indexer-public-data-provider";
import { levelPrivateStateProvider } from "@midnight-ntwrk/midnight-js-level-private-state-provider";
import { NodeZkConfigProvider } from "@midnight-ntwrk/midnight-js-node-zk-config-provider";
import type { MidnightProvider, WalletProvider } from "@midnight-ntwrk/midnight-js-types";
import type { WalletFacade } from "@midnight-ntwrk/wallet-sdk-facade";
import type * as ledger from "@midnight-ntwrk/ledger-v8";
import * as Rx from "rxjs";
import { DEVNET_CONFIG } from "./config.js";
import { ZK_CONFIG_PATH } from "./constants.js";
import type { UnshieldedKeystore } from "@midnight-ntwrk/wallet-sdk-unshielded-wallet";

export interface Providers {
	privateStateProvider: ReturnType<typeof levelPrivateStateProvider>;
	publicDataProvider: ReturnType<typeof indexerPublicDataProvider>;
	zkConfigProvider: NodeZkConfigProvider<string>;
	proofProvider: ReturnType<typeof httpClientProofProvider>;
	walletProvider: WalletProvider & MidnightProvider;
	midnightProvider: WalletProvider & MidnightProvider;
}

export async function createWalletProvider(
	facade: WalletFacade,
	shieldedSecretKeys: ledger.ZswapSecretKeys,
	dustSecretKey: ledger.DustSecretKey,
	keystore: UnshieldedKeystore,
): Promise<WalletProvider & MidnightProvider> {
	const state = await Rx.firstValueFrom(facade.state().pipe(Rx.filter((s) => s.isSynced)));

	return {
		getCoinPublicKey: () => state.shielded.coinPublicKey.toHexString(),
		getEncryptionPublicKey: () => state.shielded.encryptionPublicKey.toHexString(),
		async balanceTx(tx, ttl) {
			const recipe = await facade.balanceUnboundTransaction(
				tx,
				{ shieldedSecretKeys, dustSecretKey },
				{ ttl: ttl ?? new Date(Date.now() + 30 * 60 * 1000) },
			);
			const finalized = await facade.finalizeRecipe(recipe);
			return finalized;
		},
		submitTx: (tx) => facade.submitTransaction(tx),
	} as WalletProvider & MidnightProvider;
}

export async function createProviders(
	facade: WalletFacade,
	shieldedSecretKeys: ledger.ZswapSecretKeys,
	dustSecretKey: ledger.DustSecretKey,
	keystore: UnshieldedKeystore,
	privateStateStoreName: string,
): Promise<Providers> {
	const walletProvider = await createWalletProvider(
		facade,
		shieldedSecretKeys,
		dustSecretKey,
		keystore,
	);

	const zkConfigProvider = new NodeZkConfigProvider(ZK_CONFIG_PATH);

	return {
		privateStateProvider: levelPrivateStateProvider({
			privateStateStoreName,
		}),
		publicDataProvider: indexerPublicDataProvider(
			DEVNET_CONFIG.indexer,
			DEVNET_CONFIG.indexerWS,
		),
		zkConfigProvider,
		proofProvider: httpClientProofProvider(DEVNET_CONFIG.proofServer, zkConfigProvider),
		walletProvider,
		midnightProvider: walletProvider,
	};
}
```

- [ ] **Step 2: Create `src/lib/funding.ts`**

```typescript
import * as ledger from "@midnight-ntwrk/ledger-v8";
import { unshieldedToken } from "@midnight-ntwrk/ledger-v8";
import type { WalletFacade } from "@midnight-ntwrk/wallet-sdk-facade";
import type { UnshieldedKeystore } from "@midnight-ntwrk/wallet-sdk-unshielded-wallet";
import * as Rx from "rxjs";
import {
	DUST_GENERATION_TIMEOUT,
	DUST_POLL_INTERVAL,
	FUND_POLL_INTERVAL,
	GENESIS_SEED,
} from "./constants.js";
import { buildFacade, type WalletContext } from "./wallet.js";
import { withSpinner } from "./progress.js";

export async function waitForFunds(facade: WalletFacade): Promise<bigint> {
	return Rx.firstValueFrom(
		facade.state().pipe(
			Rx.throttleTime(FUND_POLL_INTERVAL),
			Rx.filter((state) => state.isSynced),
			Rx.map((s) => s.unshielded.balances[unshieldedToken().raw] ?? 0n),
			Rx.filter((balance) => balance > 0n),
		),
	);
}

export async function waitForDust(facade: WalletFacade): Promise<bigint> {
	return Rx.firstValueFrom(
		facade.state().pipe(
			Rx.throttleTime(DUST_POLL_INTERVAL),
			Rx.filter((s) => s.isSynced),
			Rx.map((s) => s.dust.walletBalance(new Date())),
			Rx.filter((balance) => balance > 0n),
			Rx.timeout(DUST_GENERATION_TIMEOUT),
		),
	);
}

export async function airdropFromGenesis(
	targetAddress: string,
	amount: bigint,
): Promise<string> {
	return withSpinner("Airdropping from genesis wallet...", async () => {
		const genesis = await buildFacade(GENESIS_SEED);
		try {
			await Rx.firstValueFrom(
				genesis.facade.state().pipe(
					Rx.throttleTime(FUND_POLL_INTERVAL),
					Rx.filter((s) => s.isSynced),
					Rx.map((s) => s.unshielded.balances[unshieldedToken().raw] ?? 0n),
					Rx.filter((b) => b > 0n),
				),
			);

			const ttl = new Date(Date.now() + 10 * 60 * 1000);
			const recipe = await genesis.facade.transferTransaction(
				[
					{
						type: "unshielded",
						outputs: [
							{
								amount,
								receiverAddress: targetAddress,
								type: unshieldedToken().raw,
							},
						],
					},
				],
				{
					shieldedSecretKeys: genesis.shieldedSecretKeys,
					dustSecretKey: genesis.dustSecretKey,
				},
				{ ttl, payFees: true },
			);

			const signed = await genesis.facade.signRecipe(recipe, (msg) =>
				genesis.keystore.signData(msg),
			);
			const finalized = await genesis.facade.finalizeRecipe(signed);
			const txHash = await genesis.facade.submitTransaction(finalized);
			return txHash;
		} finally {
			await genesis.facade.stop();
		}
	});
}

export async function registerDust(
	facade: WalletFacade,
	keystore: UnshieldedKeystore,
): Promise<string | null> {
	return withSpinner("Registering for DUST generation...", async () => {
		const state = await Rx.firstValueFrom(
			facade.state().pipe(Rx.filter((s) => s.isSynced)),
		);

		if (state.dust.availableCoins.length > 0) {
			return null; // Already has DUST
		}

		const nightUtxos = state.unshielded.availableCoins.filter(
			(coin: { meta?: { registeredForDustGeneration?: boolean } }) =>
				!coin.meta?.registeredForDustGeneration,
		);

		if (nightUtxos.length === 0) {
			throw new Error("No unregistered NIGHT UTXOs available for DUST generation.");
		}

		const dustState = state.dust;
		const ttl = new Date(Date.now() + 10 * 60 * 1000);

		const recipe = await facade.dust.createDustGenerationTransaction(
			new Date(),
			ttl,
			nightUtxos.map((u: { utxo: unknown; meta: { ctime: string } }) => ({
				...u.utxo,
				ctime: new Date(u.meta.ctime),
			})),
			keystore.getPublicKey(),
			dustState.address,
		);

		const intent = recipe.intents?.get(1);
		if (!intent) {
			throw new Error("Failed to create DUST generation intent.");
		}
		const sig = keystore.signData(intent.signatureData(1));
		const signed = await facade.dust.addDustGenerationSignature(recipe, sig);
		const finalized = await facade.finalizeTransaction(signed);
		const txHash = await facade.submitTransaction(finalized);
		return txHash;
	});
}
```

- [ ] **Step 3: Create `src/lib/contract.ts`**

```typescript
import fs from "node:fs";
import path from "node:path";
import { deployContract, findDeployedContract } from "@midnight-ntwrk/midnight-js-contracts";
import { CompiledContract } from "@midnight-ntwrk/compact-js";
import type { Providers } from "./providers.js";
import {
	CONTRACT_NAME,
	CONTRACTS_FILE,
	FILE_MODE_PUBLIC,
	STATE_DIR,
	ZK_CONFIG_PATH,
} from "./constants.js";
import { withSpinner } from "./progress.js";

// --- Contract Loading ---

// NOTE: The contract module is imported dynamically at runtime because
// the import path depends on the compiled contract output.
// The agent should update this import to match the actual contract package.
export async function loadCompiledContract() {
	const ContractModule = await import("{{CONTRACT_PACKAGE}}");
	return CompiledContract.make(CONTRACT_NAME, ContractModule.Contract).pipe(
		CompiledContract.withVacantWitnesses,
		CompiledContract.withCompiledFileAssets(ZK_CONFIG_PATH),
	);
}

// --- Deploy / Join ---

export interface DeployResult {
	contractAddress: string;
	txId: string;
	blockHeight: bigint;
}

export async function deploy(
	providers: Providers,
	initialPrivateState: Record<string, unknown>,
): Promise<DeployResult> {
	return withSpinner("Deploying contract (this may take 30-60 seconds)...", async () => {
		const compiledContract = await loadCompiledContract();

		const deployed = await deployContract(providers, {
			compiledContract,
			privateStateId: `${CONTRACT_NAME}PrivateState`,
			initialPrivateState,
		});

		const result: DeployResult = {
			contractAddress: deployed.deployTxData.public.contractAddress,
			txId: deployed.deployTxData.public.txId,
			blockHeight: deployed.deployTxData.public.blockHeight,
		};

		saveDeployedContract(CONTRACT_NAME, result);
		return result;
	});
}

export async function join(
	providers: Providers,
	contractAddress: string,
	initialPrivateState: Record<string, unknown>,
) {
	return withSpinner("Joining contract...", async () => {
		const compiledContract = await loadCompiledContract();

		return findDeployedContract(providers, {
			contractAddress,
			compiledContract,
			privateStateId: `${CONTRACT_NAME}PrivateState`,
			initialPrivateState,
		});
	});
}

// --- Persistence ---

interface DeployedContractStore {
	[name: string]: {
		address: string;
		deployedAt: string;
		txId: string;
	};
}

function contractsPath(): string {
	return path.join(process.cwd(), STATE_DIR, CONTRACTS_FILE);
}

export function loadDeployedContracts(): DeployedContractStore {
	const filePath = contractsPath();
	if (!fs.existsSync(filePath)) {
		return {};
	}
	return JSON.parse(fs.readFileSync(filePath, "utf-8")) as DeployedContractStore;
}

function saveDeployedContract(name: string, result: DeployResult): void {
	const store = loadDeployedContracts();
	store[name] = {
		address: result.contractAddress,
		deployedAt: new Date().toISOString(),
		txId: result.txId,
	};
	const dir = path.join(process.cwd(), STATE_DIR);
	if (!fs.existsSync(dir)) {
		fs.mkdirSync(dir, { recursive: true });
	}
	fs.writeFileSync(contractsPath(), JSON.stringify(store, null, "\t") + "\n", {
		mode: FILE_MODE_PUBLIC,
	});
}
```

- [ ] **Step 4: Commit**

```bash
git add plugins/compact-cli-dev/skills/core/templates/cli/src/lib/providers.ts plugins/compact-cli-dev/skills/core/templates/cli/src/lib/funding.ts plugins/compact-cli-dev/skills/core/templates/cli/src/lib/contract.ts
git commit -m "feat(compact-cli-dev): add template lib — providers, funding, contract"
```

---

### Task 8: CLI template — base command

**Files:**
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/base-command.ts`

- [ ] **Step 1: Create `src/base-command.ts`**

```typescript
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
```

- [ ] **Step 2: Commit**

```bash
git add plugins/compact-cli-dev/skills/core/templates/cli/src/base-command.ts
git commit -m "feat(compact-cli-dev): add template base command with error handling and welcome banner"
```

---

### Task 9: CLI template — wallet commands

**Files:**
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/commands/wallet/create.ts`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/commands/wallet/list.ts`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/commands/wallet/info.ts`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/commands/wallet/fund.ts`

- [ ] **Step 1: Create `wallet:create`**

```typescript
import { Args } from "@oclif/core";
import { BaseCommand } from "../../base-command.js";
import { newSeed, deriveKeys, saveWallet } from "../../lib/wallet.js";
import { createKeystore } from "@midnight-ntwrk/wallet-sdk-unshielded-wallet";
import { getNetworkId } from "@midnight-ntwrk/midnight-js-network-id";

export default class WalletCreate extends BaseCommand {
	static override description = "Generate a new wallet with a random seed";

	static override args = {
		name: Args.string({
			description: "Name for the wallet",
			default: "default",
		}),
	};

	async run(): Promise<void> {
		const { args } = await this.parse(WalletCreate);
		const name = args.name;

		const seed = newSeed();
		const keys = deriveKeys(seed);
		const keystore = createKeystore(keys.nightExternal, getNetworkId());
		const address = keystore.getBech32Address();

		const wallet = {
			seed,
			address,
			createdAt: new Date().toISOString(),
		};

		saveWallet(name, wallet);

		if (!this.jsonEnabled) {
			this.log(`Wallet "${name}" created.`);
			this.log(`  Address: ${address}`);
			this.log(`  Seed:    ${seed}`);
		}

		this.outputResult({ name, address, seed });
	}
}
```

- [ ] **Step 2: Create `wallet:list`**

```typescript
import { BaseCommand } from "../../base-command.js";
import { loadWallets } from "../../lib/wallet.js";

export default class WalletList extends BaseCommand {
	static override description = "List all saved wallets";

	async run(): Promise<void> {
		const store = loadWallets();
		const entries = Object.entries(store);

		if (entries.length === 0) {
			if (!this.jsonEnabled) {
				this.log("No wallets found. Run `wallet:create` to create one.");
			}
			this.outputResult([]);
			return;
		}

		const result = entries.map(([name, w]) => ({ name, address: w.address }));

		if (!this.jsonEnabled) {
			for (const { name, address } of result) {
				this.log(`  ${name}: ${address}`);
			}
		}

		this.outputResult(result);
	}
}
```

- [ ] **Step 3: Create `wallet:info`**

```typescript
import { Args } from "@oclif/core";
import { BaseCommand } from "../../base-command.js";
import { getWallet } from "../../lib/wallet.js";

export default class WalletInfo extends BaseCommand {
	static override description = "Show wallet details";

	static override args = {
		name: Args.string({
			description: "Wallet name",
			required: true,
		}),
	};

	async run(): Promise<void> {
		const { args } = await this.parse(WalletInfo);
		const wallet = getWallet(args.name);

		const result = {
			name: args.name,
			address: wallet.address,
			createdAt: wallet.createdAt,
		};

		if (!this.jsonEnabled) {
			this.log(`Wallet: ${args.name}`);
			this.log(`  Address:    ${wallet.address}`);
			this.log(`  Created:    ${wallet.createdAt}`);
		}

		this.outputResult(result);
	}
}
```

- [ ] **Step 4: Create `wallet:fund`**

```typescript
import { Args, Flags } from "@oclif/core";
import { BaseCommand } from "../../base-command.js";
import { buildFacade, getWallet } from "../../lib/wallet.js";
import { airdropFromGenesis, registerDust, waitForFunds, waitForDust } from "../../lib/funding.js";
import { withSpinner } from "../../lib/progress.js";

export default class WalletFund extends BaseCommand {
	static override description = "Fund a wallet from the genesis account and register for DUST";

	static override args = {
		name: Args.string({
			description: "Wallet name",
			required: true,
		}),
	};

	static override flags = {
		...BaseCommand.baseFlags,
		amount: Flags.string({
			description: "Amount of NIGHT to airdrop (in micro-NIGHT)",
			default: "1000000000",
		}),
	};

	async run(): Promise<void> {
		const { args, flags } = await this.parse(WalletFund);
		const wallet = getWallet(args.name);
		const amount = BigInt(flags.amount);

		// Step 1: Airdrop from genesis
		const txId = await airdropFromGenesis(wallet.address, amount);
		if (!this.jsonEnabled) {
			this.log(`  Airdrop tx: ${txId}`);
		}

		// Step 2: Build facade and wait for funds to arrive
		const ctx = await withSpinner("Syncing wallet...", () => buildFacade(wallet.seed));
		try {
			await withSpinner("Waiting for funds to arrive...", () => waitForFunds(ctx.facade));

			// Step 3: Register for DUST
			const dustTx = await registerDust(ctx.facade, ctx.keystore);
			if (dustTx) {
				if (!this.jsonEnabled) {
					this.log(`  DUST registration tx: ${dustTx}`);
				}
				await withSpinner("Waiting for DUST generation...", () => waitForDust(ctx.facade));
			}

			if (!this.jsonEnabled) {
				this.log(`  Wallet "${args.name}" funded and DUST registered.`);
			}

			this.outputResult({ name: args.name, txId, dustTx });
		} finally {
			await ctx.facade.stop();
		}
	}
}
```

- [ ] **Step 5: Commit**

```bash
git add plugins/compact-cli-dev/skills/core/templates/cli/src/commands/wallet/
git commit -m "feat(compact-cli-dev): add template wallet commands"
```

---

### Task 10: CLI template — dust, balance, deploy, join, call, query commands

**Files:**
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/commands/dust/register.ts`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/commands/dust/status.ts`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/commands/balance.ts`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/commands/deploy.ts`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/commands/join.ts`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/commands/call.ts`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/commands/query.ts`

- [ ] **Step 1: Create `dust:register`**

```typescript
import { Args } from "@oclif/core";
import { BaseCommand } from "../../base-command.js";
import { buildFacade, getWallet } from "../../lib/wallet.js";
import { registerDust, waitForDust, waitForFunds } from "../../lib/funding.js";
import { withSpinner } from "../../lib/progress.js";

export default class DustRegister extends BaseCommand {
	static override description = "Register NIGHT UTXOs for DUST generation";

	static override args = {
		name: Args.string({ description: "Wallet name", required: true }),
	};

	async run(): Promise<void> {
		const { args } = await this.parse(DustRegister);
		const wallet = getWallet(args.name);

		const ctx = await withSpinner("Building wallet...", () => buildFacade(wallet.seed));
		try {
			await withSpinner("Syncing...", () => waitForFunds(ctx.facade));
			const txId = await registerDust(ctx.facade, ctx.keystore);

			if (txId) {
				await withSpinner("Waiting for DUST...", () => waitForDust(ctx.facade));
				if (!this.jsonEnabled) {
					this.log(`  DUST registered. tx: ${txId}`);
				}
				this.outputResult({ txId, registered: true });
			} else {
				if (!this.jsonEnabled) {
					this.log("  DUST already available.");
				}
				this.outputResult({ txId: null, registered: false });
			}
		} finally {
			await ctx.facade.stop();
		}
	}
}
```

- [ ] **Step 2: Create `dust:status`**

```typescript
import { Args } from "@oclif/core";
import * as Rx from "rxjs";
import { BaseCommand } from "../../base-command.js";
import { buildFacade, getWallet } from "../../lib/wallet.js";
import { withSpinner } from "../../lib/progress.js";

export default class DustStatus extends BaseCommand {
	static override description = "Check DUST balance and registration status";

	static override args = {
		name: Args.string({ description: "Wallet name", required: true }),
	};

	async run(): Promise<void> {
		const { args } = await this.parse(DustStatus);
		const wallet = getWallet(args.name);

		const ctx = await withSpinner("Syncing wallet...", () => buildFacade(wallet.seed));
		try {
			const state = await Rx.firstValueFrom(
				ctx.facade.state().pipe(
					Rx.throttleTime(5_000),
					Rx.filter((s) => s.isSynced),
				),
			);

			const balance = state.dust.walletBalance(new Date());
			const available = state.dust.availableCoins.length;
			const registered = state.unshielded.availableCoins.filter(
				(c: { meta?: { registeredForDustGeneration?: boolean } }) =>
					c.meta?.registeredForDustGeneration === true,
			).length;

			const result = {
				balance: balance.toString(),
				available,
				registered,
			};

			if (!this.jsonEnabled) {
				this.log(`  DUST balance:    ${balance.toString()}`);
				this.log(`  Available coins: ${String(available)}`);
				this.log(`  Registered:      ${String(registered)}`);
			}

			this.outputResult(result);
		} finally {
			await ctx.facade.stop();
		}
	}
}
```

- [ ] **Step 3: Create `balance`**

```typescript
import { Args } from "@oclif/core";
import { unshieldedToken } from "@midnight-ntwrk/ledger-v8";
import * as Rx from "rxjs";
import { BaseCommand } from "../base-command.js";
import { buildFacade, getWallet } from "../lib/wallet.js";
import { withSpinner } from "../lib/progress.js";

export default class Balance extends BaseCommand {
	static override description = "Check NIGHT and DUST balances for a wallet";

	static override args = {
		name: Args.string({ description: "Wallet name", required: true }),
	};

	async run(): Promise<void> {
		const { args } = await this.parse(Balance);
		const wallet = getWallet(args.name);

		const ctx = await withSpinner("Syncing wallet...", () => buildFacade(wallet.seed));
		try {
			const state = await Rx.firstValueFrom(
				ctx.facade.state().pipe(
					Rx.throttleTime(5_000),
					Rx.filter((s) => s.isSynced),
				),
			);

			const night = state.unshielded.balances[unshieldedToken().raw] ?? 0n;
			const dust = state.dust.walletBalance(new Date());

			const result = {
				night: night.toString(),
				dust: dust.toString(),
			};

			if (!this.jsonEnabled) {
				this.log(`  NIGHT: ${night.toString()}`);
				this.log(`  DUST:  ${dust.toString()}`);
			}

			this.outputResult(result);
		} finally {
			await ctx.facade.stop();
		}
	}
}
```

- [ ] **Step 4: Create `deploy`**

```typescript
import { Flags } from "@oclif/core";
import { BaseCommand } from "../base-command.js";
import { buildFacade, getWallet } from "../lib/wallet.js";
import { createProviders } from "../lib/providers.js";
import { deploy } from "../lib/contract.js";
import { CONTRACT_NAME } from "../lib/constants.js";
import { withSpinner } from "../lib/progress.js";
import { waitForFunds } from "../lib/funding.js";

export default class Deploy extends BaseCommand {
	static override description = "Deploy the compiled contract to devnet";

	static override flags = {
		...BaseCommand.baseFlags,
		wallet: Flags.string({
			description: "Wallet name to use for deployment",
			default: "default",
		}),
	};

	async run(): Promise<void> {
		const { flags } = await this.parse(Deploy);
		const walletData = getWallet(flags.wallet);

		const ctx = await withSpinner("Building wallet...", () => buildFacade(walletData.seed));
		try {
			await withSpinner("Syncing...", () => waitForFunds(ctx.facade));

			const providers = await withSpinner("Configuring providers...", () =>
				createProviders(
					ctx.facade,
					ctx.shieldedSecretKeys,
					ctx.dustSecretKey,
					ctx.keystore,
					`${CONTRACT_NAME}-private-state`,
				),
			);

			const result = await deploy(providers, {});

			if (!this.jsonEnabled) {
				this.log(`  Contract deployed!`);
				this.log(`  Address:      ${result.contractAddress}`);
				this.log(`  Transaction:  ${result.txId}`);
				this.log(`  Block:        ${result.blockHeight.toString()}`);
			}

			this.outputResult({
				contractAddress: result.contractAddress,
				txId: result.txId,
				blockHeight: result.blockHeight.toString(),
			});
		} finally {
			await ctx.facade.stop();
		}
	}
}
```

- [ ] **Step 5: Create `join`**

```typescript
import { Args, Flags } from "@oclif/core";
import { BaseCommand } from "../base-command.js";
import { buildFacade, getWallet } from "../lib/wallet.js";
import { createProviders } from "../lib/providers.js";
import { join } from "../lib/contract.js";
import { CONTRACT_NAME } from "../lib/constants.js";
import { withSpinner } from "../lib/progress.js";
import { waitForFunds } from "../lib/funding.js";

export default class Join extends BaseCommand {
	static override description = "Join an existing deployed contract";

	static override args = {
		address: Args.string({
			description: "Contract address to join",
			required: true,
		}),
	};

	static override flags = {
		...BaseCommand.baseFlags,
		wallet: Flags.string({
			description: "Wallet name",
			default: "default",
		}),
	};

	async run(): Promise<void> {
		const { args, flags } = await this.parse(Join);
		const walletData = getWallet(flags.wallet);

		const ctx = await withSpinner("Building wallet...", () => buildFacade(walletData.seed));
		try {
			await withSpinner("Syncing...", () => waitForFunds(ctx.facade));

			const providers = await createProviders(
				ctx.facade,
				ctx.shieldedSecretKeys,
				ctx.dustSecretKey,
				ctx.keystore,
				`${CONTRACT_NAME}-private-state`,
			);

			await join(providers, args.address, {});

			if (!this.jsonEnabled) {
				this.log(`  Joined contract at: ${args.address}`);
			}

			this.outputResult({ contractAddress: args.address });
		} finally {
			await ctx.facade.stop();
		}
	}
}
```

- [ ] **Step 6: Create `call` (stub with pattern)**

```typescript
import { Args, Flags } from "@oclif/core";
import { BaseCommand } from "../base-command.js";

export default class Call extends BaseCommand {
	static override description = "Call a contract circuit (transaction)";

	static override args = {
		circuit: Args.string({
			description: "Circuit name to call",
			required: true,
		}),
	};

	static override flags = {
		...BaseCommand.baseFlags,
		wallet: Flags.string({
			description: "Wallet name",
			default: "default",
		}),
	};

	async run(): Promise<void> {
		const { args } = await this.parse(Call);

		// TODO: Replace this stub with your contract's actual circuit calls.
		//
		// Example pattern (using the counter contract):
		//
		//   import { buildFacade, getWallet } from "../lib/wallet.js";
		//   import { createProviders } from "../lib/providers.js";
		//   import { join } from "../lib/contract.js";
		//   import { loadDeployedContracts } from "../lib/contract.js";
		//
		//   const walletData = getWallet(flags.wallet);
		//   const ctx = await buildFacade(walletData.seed);
		//   const providers = await createProviders(ctx.facade, ctx.shieldedSecretKeys, ctx.dustSecretKey, ctx.keystore, "counter-private-state");
		//   const contracts = loadDeployedContracts();
		//   const contract = await join(providers, contracts["counter"].address, { privateCounter: 0 });
		//
		//   const txData = await contract.callTx.increment();
		//   this.log(`Transaction: ${txData.public.txId}`);
		//   this.log(`Block: ${txData.public.blockHeight}`);

		this.log(`Circuit "${args.circuit}" is not yet implemented.`);
		this.log("Edit src/commands/call.ts to add your contract's circuit calls.");
	}
}
```

- [ ] **Step 7: Create `query` (stub with pattern)**

```typescript
import { Args, Flags } from "@oclif/core";
import { BaseCommand } from "../base-command.js";

export default class Query extends BaseCommand {
	static override description = "Query contract public state (read-only)";

	static override args = {
		field: Args.string({
			description: "Ledger field to query",
			required: true,
		}),
	};

	static override flags = {
		...BaseCommand.baseFlags,
		address: Flags.string({
			description: "Contract address (uses deployed address if omitted)",
		}),
	};

	async run(): Promise<void> {
		const { args } = await this.parse(Query);

		// TODO: Replace this stub with your contract's actual state queries.
		//
		// Example pattern (using the counter contract):
		//
		//   import { createProviders } from "../lib/providers.js";
		//   import { loadDeployedContracts } from "../lib/contract.js";
		//   import { DEVNET_CONFIG } from "../lib/config.js";
		//   import { indexerPublicDataProvider } from "@midnight-ntwrk/midnight-js-indexer-public-data-provider";
		//   import { Counter } from "@midnight-ntwrk/counter-contract";
		//
		//   const contracts = loadDeployedContracts();
		//   const address = flags.address ?? contracts["counter"].address;
		//   const publicDataProvider = indexerPublicDataProvider(DEVNET_CONFIG.indexer, DEVNET_CONFIG.indexerWS);
		//   const state = await publicDataProvider.queryContractState(address);
		//
		//   if (state) {
		//     const ledgerState = Counter.ledger(state.data);
		//     this.log(`Counter value: ${ledgerState.round}`);
		//   }

		this.log(`Field "${args.field}" query is not yet implemented.`);
		this.log("Edit src/commands/query.ts to add your contract's state queries.");
	}
}
```

- [ ] **Step 8: Commit**

```bash
git add plugins/compact-cli-dev/skills/core/templates/cli/src/commands/
git commit -m "feat(compact-cli-dev): add template commands — dust, balance, deploy, join, call, query"
```

---

### Task 11: CLI template — devnet commands

**Files:**
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/commands/devnet/start.ts`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/commands/devnet/stop.ts`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/src/commands/devnet/status.ts`

- [ ] **Step 1: Create shared compose file finder**

Add to the top of each devnet command or create a small helper. For simplicity, we'll inline the logic since it's small. Each command uses this pattern:

```typescript
import fs from "node:fs";
import path from "node:path";
import { COMPOSE_SEARCH_PATHS, COMPOSE_FALLBACK } from "../../lib/constants.js";

function findComposeFile(): string {
	for (const relative of COMPOSE_SEARCH_PATHS) {
		const abs = path.resolve(relative);
		if (fs.existsSync(abs)) return abs;
	}
	if (fs.existsSync(COMPOSE_FALLBACK)) return COMPOSE_FALLBACK;
	throw new Error(
		"No devnet.yml found. Search paths:\n" +
			COMPOSE_SEARCH_PATHS.map((p) => `  - ${p}`).join("\n") +
			`\n  - ${COMPOSE_FALLBACK}\n` +
			"Generate one with the midnight-tooling:devnet skill.",
	);
}
```

- [ ] **Step 2: Create `devnet:start`**

```typescript
import { execSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { BaseCommand } from "../../base-command.js";
import { COMPOSE_SEARCH_PATHS, COMPOSE_FALLBACK } from "../../lib/constants.js";

function findComposeFile(): string {
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

export default class DevnetStart extends BaseCommand {
	static override description = "Start the local devnet via Docker Compose";

	async run(): Promise<void> {
		const composeFile = findComposeFile();

		if (!this.jsonEnabled) {
			this.log(`  Using: ${composeFile}`);
		}

		execSync(`docker compose -f "${composeFile}" up -d`, {
			stdio: this.jsonEnabled ? "pipe" : "inherit",
		});

		const result = { composePath: composeFile, started: true };
		if (!this.jsonEnabled) {
			this.log("  Devnet started.");
		}
		this.outputResult(result);
	}
}
```

- [ ] **Step 3: Create `devnet:stop`**

```typescript
import { execSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { BaseCommand } from "../../base-command.js";
import { COMPOSE_SEARCH_PATHS, COMPOSE_FALLBACK } from "../../lib/constants.js";

function findComposeFile(): string {
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

export default class DevnetStop extends BaseCommand {
	static override description = "Stop the local devnet";

	async run(): Promise<void> {
		const composeFile = findComposeFile();

		execSync(`docker compose -f "${composeFile}" down`, {
			stdio: this.jsonEnabled ? "pipe" : "inherit",
		});

		if (!this.jsonEnabled) {
			this.log("  Devnet stopped.");
		}
		this.outputResult({ stopped: true });
	}
}
```

- [ ] **Step 4: Create `devnet:status`**

```typescript
import { BaseCommand } from "../../base-command.js";

interface ServiceStatus {
	name: string;
	url: string;
	healthy: boolean;
	error?: string;
}

async function checkService(name: string, url: string): Promise<ServiceStatus> {
	try {
		const response = await fetch(url, { signal: AbortSignal.timeout(5_000) });
		return { name, url, healthy: response.ok || response.status === 400 };
	} catch (err) {
		return {
			name,
			url,
			healthy: false,
			error: err instanceof Error ? err.message : String(err),
		};
	}
}

export default class DevnetStatus extends BaseCommand {
	static override description = "Check health of devnet services";

	async run(): Promise<void> {
		const services = await Promise.all([
			checkService("node", "http://127.0.0.1:9944"),
			checkService("indexer", "http://127.0.0.1:8088/api/v3/graphql"),
			checkService("proof-server", "http://127.0.0.1:6300"),
		]);

		const result = {
			node: services[0],
			indexer: services[1],
			proofServer: services[2],
		};

		if (!this.jsonEnabled) {
			for (const svc of services) {
				const icon = svc.healthy ? "+" : "x";
				this.log(`  [${icon}] ${svc.name}: ${svc.url}`);
				if (svc.error) {
					this.log(`      ${svc.error}`);
				}
			}
		}

		this.outputResult(result);
	}
}
```

- [ ] **Step 5: Commit**

```bash
git add plugins/compact-cli-dev/skills/core/templates/cli/src/commands/devnet/
git commit -m "feat(compact-cli-dev): add template devnet commands"
```

---

### Task 12: CLI template — tests and tooling config

**Files:**
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/test/lib/errors.test.ts`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/test/lib/wallet.test.ts`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/.husky/pre-commit`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/.husky/pre-push`
- Create: `plugins/compact-cli-dev/skills/core/templates/cli/.github/workflows/ci.yml`

- [ ] **Step 1: Create error classification tests**

Create `plugins/compact-cli-dev/skills/core/templates/cli/test/lib/errors.test.ts`:

```typescript
import { describe, expect, it } from "vitest";
import { classifyError, ErrorCode } from "../../src/lib/errors.js";

describe("classifyError", () => {
	it("classifies DUST-related errors", () => {
		const result = classifyError(new Error("Insufficient dust for transaction fees"));
		expect(result.code).toBe(ErrorCode.DUST_REQUIRED);
		expect(result.action).toContain("dust:register");
	});

	it("classifies proof server connection errors", () => {
		const result = classifyError(new Error("connect ECONNREFUSED 127.0.0.1:6300"));
		expect(result.code).toBe(ErrorCode.SERVICE_DOWN);
		expect(result.action).toContain("devnet:start");
	});

	it("classifies indexer connection errors", () => {
		const result = classifyError(new Error("connect ECONNREFUSED 127.0.0.1:8088"));
		expect(result.code).toBe(ErrorCode.SERVICE_DOWN);
		expect(result.action).toContain("devnet:status");
	});

	it("classifies timeout errors", () => {
		const result = classifyError(new Error("Operation timed out"));
		expect(result.code).toBe(ErrorCode.SYNC_TIMEOUT);
	});

	it("classifies contract not found errors", () => {
		const result = classifyError(new Error("Contract not found at address"));
		expect(result.code).toBe(ErrorCode.CONTRACT_NOT_FOUND);
	});

	it("classifies unknown errors", () => {
		const result = classifyError(new Error("Something unexpected"));
		expect(result.code).toBe(ErrorCode.UNKNOWN);
	});

	it("handles non-Error values", () => {
		const result = classifyError("string error");
		expect(result.code).toBe(ErrorCode.UNKNOWN);
		expect(result.message).toBe("string error");
	});
});
```

- [ ] **Step 2: Create wallet unit tests**

Create `plugins/compact-cli-dev/skills/core/templates/cli/test/lib/wallet.test.ts`:

```typescript
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { loadWallets, saveWallet, saveWallets, getWallet } from "../../src/lib/wallet.js";
import { STATE_DIR, WALLETS_FILE } from "../../src/lib/constants.js";

describe("wallet persistence", () => {
	let originalCwd: string;
	let tmpDir: string;

	beforeEach(() => {
		originalCwd = process.cwd();
		tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "wallet-test-"));
		process.chdir(tmpDir);
	});

	afterEach(() => {
		process.chdir(originalCwd);
		fs.rmSync(tmpDir, { recursive: true, force: true });
	});

	it("returns empty store when no wallets file exists", () => {
		expect(loadWallets()).toEqual({});
	});

	it("saves and loads wallets", () => {
		const wallet = { seed: "a".repeat(64), address: "addr1", createdAt: "2026-01-01" };
		saveWallet("alice", wallet);

		const store = loadWallets();
		expect(store["alice"]).toEqual(wallet);
	});

	it("sets restrictive file permissions on wallets.json", () => {
		saveWallets({});
		const filePath = path.join(tmpDir, STATE_DIR, WALLETS_FILE);
		const stats = fs.statSync(filePath);
		// Check owner-only read/write (0o600 = 384 decimal, masked to lower 9 bits)
		expect(stats.mode & 0o777).toBe(0o600);
	});

	it("throws when getting nonexistent wallet", () => {
		expect(() => getWallet("nobody")).toThrow('Wallet "nobody" not found');
	});
});
```

- [ ] **Step 3: Create Husky pre-commit hook**

Create `plugins/compact-cli-dev/skills/core/templates/cli/.husky/pre-commit`:

```bash
npx biome check --staged --no-errors-on-unmatched
```

- [ ] **Step 4: Create Husky pre-push hook**

Create `plugins/compact-cli-dev/skills/core/templates/cli/.husky/pre-push`:

```bash
npx biome check .
npx tsc --noEmit
npx vitest run
```

- [ ] **Step 5: Create GitHub Actions CI workflow**

Create `plugins/compact-cli-dev/skills/core/templates/cli/.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - run: npm ci

      - name: Lint
        run: npx biome check .

      - name: Type check
        run: npx tsc --noEmit

      - name: Test
        run: npx vitest run
```

- [ ] **Step 6: Commit**

```bash
git add plugins/compact-cli-dev/skills/core/templates/cli/test/ plugins/compact-cli-dev/skills/core/templates/cli/.husky/ plugins/compact-cli-dev/skills/core/templates/cli/.github/
git commit -m "feat(compact-cli-dev): add template tests, Husky hooks, and CI workflow"
```

---

## Phase 3: Plugin Shell

### Task 13: Plugin metadata and skill

**Files:**
- Create: `plugins/compact-cli-dev/.claude-plugin/plugin.json`
- Create: `plugins/compact-cli-dev/skills/core/SKILL.md`
- Create: `plugins/compact-cli-dev/skills/core/references/oclif-patterns.md`
- Create: `plugins/compact-cli-dev/skills/core/references/wallet-management.md`
- Create: `plugins/compact-cli-dev/skills/core/references/provider-setup.md`
- Create: `plugins/compact-cli-dev/skills/core/references/contract-lifecycle.md`
- Create: `plugins/compact-cli-dev/skills/core/references/error-handling.md`

- [ ] **Step 1: Create plugin.json**

```json
{
	"name": "compact-cli-dev",
	"version": "0.1.0",
	"description": "Scaffold and develop Oclif CLIs for Midnight Compact smart contracts. Includes a complete CLI template with wallet management, contract deployment, devnet control, and an AI agent for ongoing development.",
	"author": {
		"name": "Aaron Bassett",
		"email": "aaron@devrel-ai.com"
	},
	"homepage": "https://github.com/devrelaicom/midnight-expert",
	"repository": "https://github.com/devrelaicom/midnight-expert.git",
	"license": "MIT",
	"keywords": [
		"midnight",
		"compact",
		"cli",
		"oclif",
		"scaffold",
		"template",
		"wallet",
		"deployment",
		"devnet",
		"typescript"
	]
}
```

- [ ] **Step 2: Create SKILL.md**

Write the skill markdown file with YAML frontmatter. The description should trigger on CLI-related queries. The content should provide an overview of the CLI architecture, a quick command reference, the `src/lib/` module guide, and patterns for adding new commands. Keep it under 200 lines — deep dives go in the references.

The SKILL.md should reference the 5 reference docs and explain when to consult each one.

- [ ] **Step 3: Create reference docs**

Write each of the 5 reference files with code examples pulled from the template files created in Tasks 5-12. Each reference should be self-contained and include:
- **oclif-patterns.md**: How Oclif commands work, the `BaseCommand` class, `--json` support, command anatomy (flags, args, run method), topic grouping, and the pattern for adding a new command.
- **wallet-management.md**: HD derivation flow, WalletFacade building, seed generation, persistence to `.midnight-expert/wallets.json`, the `WalletContext` type, and the `getWallet`/`saveWallet` API.
- **provider-setup.md**: The 6-provider bundle, `createProviders()` factory, `createWalletProvider()`, network config, and the `Providers` type.
- **contract-lifecycle.md**: Compiled contract loading, `deploy()`, `join()`, `callTx.*` pattern, `queryContractState()` pattern, address persistence.
- **error-handling.md**: Error classification, `classifyError()`, `formatError()`, actionable messages, the `ErrorCode` enum, and how `BaseCommand.catch()` uses it.

- [ ] **Step 4: Commit**

```bash
git add plugins/compact-cli-dev/.claude-plugin/ plugins/compact-cli-dev/skills/
git commit -m "feat(compact-cli-dev): add plugin metadata, skill, and reference docs"
```

---

### Task 14: Agent and command

**Files:**
- Create: `plugins/compact-cli-dev/agents/dev.md`
- Create: `plugins/compact-cli-dev/commands/init.md`

- [ ] **Step 1: Create agent definition**

Write `plugins/compact-cli-dev/agents/dev.md` with YAML frontmatter:
- `name`: `dev`
- `description`: Trigger description covering "add a CLI", "create CLI commands", "work on the CLI", "add a command to interact with my contract", "I need a CLI for my contract", "scaffold CLI", "CLI development"
- `model`: `sonnet`
- `color`: a distinctive color (e.g., `green`)

The agent body should instruct:
1. Always load `compact-cli-dev:core` and `devs:typescript-core` skills first
2. Check for existing CLI (look for Oclif config in package.json, or `.midnight-expert/` directory)
3. If no CLI exists, run `/compact-cli-dev:init`
4. If CLI exists, work with the existing code
5. After writing code, always run `biome check`, `tsc --noEmit`, `vitest run`
6. Never read template files — use the template engine
7. Follow patterns from the skill references

- [ ] **Step 2: Create init command**

Write `plugins/compact-cli-dev/commands/init.md` with YAML frontmatter:
- `description`: "Initialize a new CLI package for a Midnight Compact contract"
- `allowed-tools`: `Bash, Read, AskUserQuestion`
- `argument-hint`: `[directory] [--project-name <name>] [--contract-name <name>] [--contract-path <path>]`

The command body should detail the step-by-step process:
1. Parse arguments from `$ARGUMENTS`
2. Infer missing values by inspecting the project (read root package.json, scan for .compact files, look for managed/ directories)
3. Ask for anything that can't be inferred
4. Build the context object with all 6 placeholders
5. Resolve the template path (the command knows its own plugin root via the skill's location)
6. Pipe JSON to `npx @aaronbassett/template-engine`
7. Run `npm install` in the output directory
8. Run `npx husky` setup
9. Report results

- [ ] **Step 3: Commit**

```bash
git add plugins/compact-cli-dev/agents/ plugins/compact-cli-dev/commands/
git commit -m "feat(compact-cli-dev): add dev agent and init command"
```

---

### Task 15: Final validation

- [ ] **Step 1: Run template engine tests**

Run: `cd packages/template-engine && npx vitest run && npx biome check . && npx tsc --noEmit`
Expected: All pass

- [ ] **Step 2: Verify template files are syntactically complete**

Run a quick check that all template TypeScript files have balanced braces and no truncated content:

```bash
find plugins/compact-cli-dev/skills/core/templates/cli/src -name "*.ts" -exec grep -c "^}" {} + | grep ":0$" && echo "WARN: Some files may be incomplete" || echo "All template files have closing braces"
```

- [ ] **Step 3: Verify plugin structure matches the design**

```bash
find plugins/compact-cli-dev -type f | sort
```

Compare output against the spec's plugin structure diagram.

- [ ] **Step 4: Verify template command count matches spec**

Count command files:
```bash
find plugins/compact-cli-dev/skills/core/templates/cli/src/commands -name "*.ts" | wc -l
```
Expected: 12 (wallet/create, wallet/list, wallet/info, wallet/fund, dust/register, dust/status, balance, deploy, join, call, query, devnet/start, devnet/stop, devnet/status) — actually 14 files for 12 logical commands (devnet has 3 files). The spec says 12 commands.

- [ ] **Step 5: Final commit with version bump**

```bash
git add -A
git status  # Review for any unstaged files
git commit -m "chore(compact-cli-dev): finalize plugin structure and validate"
```
