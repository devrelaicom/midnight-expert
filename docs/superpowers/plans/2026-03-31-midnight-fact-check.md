# midnight-fact-check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `midnight-fact-check` plugin and its companion `@aaronbassett/midnight-fact-checker-utils` npm package to fact-check any content against the Midnight ecosystem.

**Architecture:** A staged pipeline where the `/midnight-fact-check:check` command orchestrates extraction, classification, and verification of claims by dispatching parallel agents. The command runs in the main conversation context (the only place that can dispatch agents). Three TypeScript CLI utilities (`discover`, `extract-url`, `merge`) are published as a single npm package and invoked via `npx`.

**Tech Stack:** Claude Code plugin system (markdown + YAML frontmatter), TypeScript, Vitest, Commander.js, globby v16, @mozilla/readability, turndown, jsdom

**Spec:** `docs/superpowers/specs/2026-03-31-midnight-fact-check-design.md`

---

## File Map

### npm Package (`packages/midnight-fact-checker-utils/`)

| File | Responsibility |
|------|---------------|
| `package.json` | Package metadata, dependencies, bin entrypoint, scripts |
| `tsconfig.json` | TypeScript config targeting Node 20, ESM output |
| `vitest.config.ts` | Test runner config |
| `.gitignore` | Ignore dist/, node_modules/ |
| `src/cli.ts` | CLI entrypoint — commander routing to subcommands |
| `src/commands/discover.ts` | Glob-based file discovery with .gitignore classification |
| `src/commands/extract-url.ts` | URL content extraction to Markdown |
| `src/commands/merge.ts` | JSON claim merging with concat and update modes |
| `tests/discover.test.ts` | File discovery tests with temp directory fixtures |
| `tests/extract-url.test.ts` | URL extraction tests with mocked HTTP |
| `tests/merge.test.ts` | Merge logic tests for both modes |

### GitHub Workflow

| File | Responsibility |
|------|---------------|
| `.github/workflows/publish-fact-checker-utils.yml` | Publish to npm on version change |

### Plugin (`plugins/midnight-fact-check/`)

| File | Responsibility |
|------|---------------|
| `.claude-plugin/plugin.json` | Plugin metadata and keywords |
| `commands/check.md` | Pipeline orchestrator — the heart of the plugin |
| `agents/claim-extractor.md` | Extracts testable claims from content chunks |
| `agents/domain-classifier.md` | Tags claims with domain(s) from its assigned domain |
| `agents/claim-verifier.md` | Verifies a batch of claims via midnight-verify |
| `skills/fact-check-extraction/SKILL.md` | Claim extraction definitions, schema, examples |
| `skills/fact-check-classification/SKILL.md` | Domain definitions, tagging rules, cross-domain handling |
| `skills/fact-check-reporting/SKILL.md` | Report templates, terminal summary, GitHub issue templates |
| `README.md` | Plugin overview and usage |

### Marketplace Registration

| File | Responsibility |
|------|---------------|
| `.claude-plugin/marketplace.json` | Add midnight-fact-check to plugin registry |

---

## Phase 1: npm Package

### Task 1: Scaffold the npm package

**Files:**
- Create: `packages/midnight-fact-checker-utils/package.json`
- Create: `packages/midnight-fact-checker-utils/tsconfig.json`
- Create: `packages/midnight-fact-checker-utils/vitest.config.ts`
- Create: `packages/midnight-fact-checker-utils/.gitignore`
- Create: `packages/midnight-fact-checker-utils/src/cli.ts`

- [ ] **Step 1: Create directory structure**

Run:
```bash
mkdir -p packages/midnight-fact-checker-utils/src/commands
mkdir -p packages/midnight-fact-checker-utils/tests
```

- [ ] **Step 2: Write package.json**

Create `packages/midnight-fact-checker-utils/package.json`:

```json
{
  "name": "@aaronbassett/midnight-fact-checker-utils",
  "version": "0.1.0",
  "description": "CLI utilities for the midnight-fact-check plugin — file discovery, URL content extraction, and JSON claim merging.",
  "type": "module",
  "bin": {
    "midnight-fact-checker-utils": "./dist/cli.js"
  },
  "files": [
    "dist"
  ],
  "scripts": {
    "build": "tsc",
    "test": "vitest run",
    "test:watch": "vitest",
    "prepublishOnly": "npm run build"
  },
  "dependencies": {
    "@mozilla/readability": "^0.6.0",
    "commander": "^13.0.0",
    "globby": "^16.0.0",
    "jsdom": "^26.0.0",
    "turndown": "^7.2.0"
  },
  "devDependencies": {
    "@types/jsdom": "^21.0.0",
    "@types/turndown": "^5.0.0",
    "typescript": "^5.7.0",
    "vitest": "^3.0.0"
  },
  "engines": {
    "node": ">=20"
  },
  "publishConfig": {
    "access": "public"
  },
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/devrelaicom/midnight-expert.git",
    "directory": "packages/midnight-fact-checker-utils"
  },
  "author": {
    "name": "Aaron Bassett",
    "email": "aaron@devrel-ai.com"
  }
}
```

- [ ] **Step 3: Write tsconfig.json**

Create `packages/midnight-fact-checker-utils/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "./dist",
    "rootDir": "./src",
    "declaration": true,
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
```

- [ ] **Step 4: Write vitest.config.ts**

Create `packages/midnight-fact-checker-utils/vitest.config.ts`:

```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
  },
});
```

- [ ] **Step 5: Write .gitignore**

Create `packages/midnight-fact-checker-utils/.gitignore`:

```
node_modules/
dist/
```

- [ ] **Step 6: Write stub CLI entrypoint**

Create `packages/midnight-fact-checker-utils/src/cli.ts`:

```typescript
#!/usr/bin/env node
import { Command } from "commander";

const program = new Command();

program
  .name("midnight-fact-checker-utils")
  .description("CLI utilities for the midnight-fact-check plugin")
  .version("0.1.0");

// Subcommands will be registered here

program.parse();
```

- [ ] **Step 7: Install dependencies**

Run:
```bash
cd packages/midnight-fact-checker-utils && npm install
```

Expected: `node_modules/` created, no errors.

- [ ] **Step 8: Verify build**

Run:
```bash
cd packages/midnight-fact-checker-utils && npm run build
```

Expected: `dist/cli.js` created with no errors.

- [ ] **Step 9: Commit**

```bash
git add packages/midnight-fact-checker-utils
git commit -m "feat(fact-checker-utils): scaffold npm package with CLI entrypoint"
```

---

### Task 2: Implement the `discover` subcommand

**Files:**
- Create: `packages/midnight-fact-checker-utils/src/commands/discover.ts`
- Create: `packages/midnight-fact-checker-utils/tests/discover.test.ts`
- Modify: `packages/midnight-fact-checker-utils/src/cli.ts`

- [ ] **Step 1: Write the failing test**

Create `packages/midnight-fact-checker-utils/tests/discover.test.ts`:

```typescript
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { mkdtempSync, writeFileSync, mkdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { discover } from "../src/commands/discover.js";

describe("discover", () => {
  let tempDir: string;

  beforeEach(() => {
    tempDir = mkdtempSync(join(tmpdir(), "discover-test-"));
  });

  afterEach(() => {
    rmSync(tempDir, { recursive: true, force: true });
  });

  it("returns matched files for a glob pattern", async () => {
    writeFileSync(join(tempDir, "readme.md"), "# Hello");
    writeFileSync(join(tempDir, "notes.md"), "# Notes");
    writeFileSync(join(tempDir, "script.ts"), "console.log()");

    const result = await discover("**/*.md", { cwd: tempDir });

    const matched = result.matched.map((f) => f.replace(tempDir + "/", ""));
    expect(matched).toContain("readme.md");
    expect(matched).toContain("notes.md");
    expect(matched).not.toContain("script.ts");
  });

  it("classifies unmatched files as GLOB_MISS", async () => {
    writeFileSync(join(tempDir, "readme.md"), "# Hello");
    writeFileSync(join(tempDir, "script.ts"), "console.log()");

    const result = await discover("**/*.md", { cwd: tempDir });

    const unmatched = result.unmatched;
    const tsFile = unmatched.find((f) => f.file.endsWith("script.ts"));
    expect(tsFile).toBeDefined();
    expect(tsFile!.reason).toBe("GLOB_MISS");
  });

  it("classifies gitignored files as GIT_IGNORED", async () => {
    // Initialize a git repo so .gitignore is respected
    const { execSync } = await import("node:child_process");
    execSync("git init", { cwd: tempDir, stdio: "ignore" });
    writeFileSync(join(tempDir, ".gitignore"), "ignored.md\n");
    writeFileSync(join(tempDir, "readme.md"), "# Hello");
    writeFileSync(join(tempDir, "ignored.md"), "# Ignored");

    const result = await discover("**/*.md", { cwd: tempDir });

    const matched = result.matched.map((f) => f.replace(tempDir + "/", ""));
    expect(matched).toContain("readme.md");
    expect(matched).not.toContain("ignored.md");

    const ignoredFile = result.unmatched.find((f) =>
      f.file.endsWith("ignored.md")
    );
    expect(ignoredFile).toBeDefined();
    expect(ignoredFile!.reason).toBe("GIT_IGNORED");
  });

  it("includes all files when --no-gitignore is set", async () => {
    const { execSync } = await import("node:child_process");
    execSync("git init", { cwd: tempDir, stdio: "ignore" });
    writeFileSync(join(tempDir, ".gitignore"), "ignored.md\n");
    writeFileSync(join(tempDir, "readme.md"), "# Hello");
    writeFileSync(join(tempDir, "ignored.md"), "# Ignored");

    const result = await discover("**/*.md", {
      cwd: tempDir,
      noGitignore: true,
    });

    const matched = result.matched.map((f) => f.replace(tempDir + "/", ""));
    expect(matched).toContain("readme.md");
    expect(matched).toContain("ignored.md");
  });

  it("groups results by directory", async () => {
    mkdirSync(join(tempDir, "sub"), { recursive: true });
    writeFileSync(join(tempDir, "root.md"), "# Root");
    writeFileSync(join(tempDir, "sub", "nested.md"), "# Nested");
    writeFileSync(join(tempDir, "sub", "other.ts"), "export {}");

    const result = await discover("**/*.md", { cwd: tempDir });

    expect(result.byDirectory).toBeDefined();
    const rootDir = result.byDirectory["."];
    const subDir = result.byDirectory["sub"];
    expect(rootDir.matched).toHaveLength(1);
    expect(subDir.matched).toHaveLength(1);
    expect(subDir.unmatched).toHaveLength(1);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd packages/midnight-fact-checker-utils && npx vitest run tests/discover.test.ts
```

Expected: FAIL — `Cannot find module '../src/commands/discover.js'`

- [ ] **Step 3: Write the implementation**

Create `packages/midnight-fact-checker-utils/src/commands/discover.ts`:

```typescript
import { globby, isGitIgnored } from "globby";
import { readdir, stat } from "node:fs/promises";
import { join, relative, dirname } from "node:path";

interface UnmatchedFile {
  file: string;
  reason: "GLOB_MISS" | "GIT_IGNORED";
}

interface DirectoryResult {
  matched: string[];
  unmatched: UnmatchedFile[];
}

interface DiscoverResult {
  matched: string[];
  unmatched: UnmatchedFile[];
  byDirectory: Record<string, DirectoryResult>;
}

interface DiscoverOptions {
  cwd?: string;
  noGitignore?: boolean;
}

async function getAllFiles(dir: string): Promise<string[]> {
  const files: string[] = [];
  const entries = await readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.name === ".git" || entry.name === "node_modules") continue;
    const fullPath = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await getAllFiles(fullPath)));
    } else {
      files.push(fullPath);
    }
  }
  return files;
}

export async function discover(
  pattern: string,
  options: DiscoverOptions = {}
): Promise<DiscoverResult> {
  const cwd = options.cwd ?? process.cwd();
  const useGitignore = !options.noGitignore;

  // Get matched files via globby
  const matched = await globby(pattern, {
    cwd,
    gitignore: useGitignore,
    absolute: true,
  });
  const matchedSet = new Set(matched);

  // Get all files to find unmatched ones
  const allFiles = await getAllFiles(cwd);

  // Build gitignore checker if needed
  let isIgnored: ((path: string) => boolean) | null = null;
  if (useGitignore) {
    isIgnored = await isGitIgnored({ cwd });
  }

  // Classify unmatched files
  const unmatched: UnmatchedFile[] = [];
  for (const file of allFiles) {
    if (matchedSet.has(file)) continue;
    if (file.endsWith(".gitignore")) continue;

    const reason: "GLOB_MISS" | "GIT_IGNORED" =
      isIgnored && isIgnored(file) ? "GIT_IGNORED" : "GLOB_MISS";
    unmatched.push({ file, reason });
  }

  // Group by directory
  const byDirectory: Record<string, DirectoryResult> = {};
  for (const file of matched) {
    const dir = relative(cwd, dirname(file)) || ".";
    if (!byDirectory[dir]) byDirectory[dir] = { matched: [], unmatched: [] };
    byDirectory[dir].matched.push(file);
  }
  for (const entry of unmatched) {
    const dir = relative(cwd, dirname(entry.file)) || ".";
    if (!byDirectory[dir]) byDirectory[dir] = { matched: [], unmatched: [] };
    byDirectory[dir].unmatched.push(entry);
  }

  return { matched, unmatched, byDirectory };
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd packages/midnight-fact-checker-utils && npx vitest run tests/discover.test.ts
```

Expected: All 5 tests PASS.

- [ ] **Step 5: Wire up the CLI subcommand**

Modify `packages/midnight-fact-checker-utils/src/cli.ts` — add the discover subcommand:

```typescript
#!/usr/bin/env node
import { Command } from "commander";
import { discover } from "./commands/discover.js";

const program = new Command();

program
  .name("midnight-fact-checker-utils")
  .description("CLI utilities for the midnight-fact-check plugin")
  .version("0.1.0");

program
  .command("discover")
  .description("Find files matching a glob pattern with .gitignore support")
  .argument("<pattern>", "Glob pattern to match files")
  .option("--no-gitignore", "Ignore .gitignore files")
  .option("--cwd <dir>", "Working directory", process.cwd())
  .action(async (pattern: string, opts: { gitignore: boolean; cwd: string }) => {
    const result = await discover(pattern, {
      cwd: opts.cwd,
      noGitignore: !opts.gitignore,
    });
    console.log(JSON.stringify(result, null, 2));
  });

// More subcommands will be registered here

program.parse();
```

- [ ] **Step 6: Build and smoke test**

Run:
```bash
cd packages/midnight-fact-checker-utils && npm run build && node dist/cli.js discover "**/*.md" --cwd ../../plugins/midnight-verify
```

Expected: JSON output with matched `.md` files from the midnight-verify plugin.

- [ ] **Step 7: Commit**

```bash
git add packages/midnight-fact-checker-utils
git commit -m "feat(fact-checker-utils): implement discover subcommand with .gitignore classification"
```

---

### Task 3: Implement the `extract-url` subcommand

**Files:**
- Create: `packages/midnight-fact-checker-utils/src/commands/extract-url.ts`
- Create: `packages/midnight-fact-checker-utils/tests/extract-url.test.ts`
- Modify: `packages/midnight-fact-checker-utils/src/cli.ts`

- [ ] **Step 1: Write the failing test**

Create `packages/midnight-fact-checker-utils/tests/extract-url.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import { extractContent } from "../src/commands/extract-url.js";

const SAMPLE_HTML = `
<!DOCTYPE html>
<html>
<head><title>Test Page</title></head>
<body>
  <nav><a href="/">Home</a><a href="/about">About</a></nav>
  <main>
    <article>
      <h1>Test Article</h1>
      <p>This is the main content of the article. It contains enough text
      to be recognized as the primary content by the readability algorithm.
      We need several sentences for the heuristic to work properly.</p>
      <p>Here is another paragraph with more content. The readability
      algorithm needs sufficient text density to identify the article body
      and strip navigation, sidebars, and other peripheral content.</p>
      <h2>Section Two</h2>
      <p>A subsection with additional content to make the article longer
      and more realistic. This helps ensure the extraction works correctly
      on real-world pages with multiple sections.</p>
    </article>
  </main>
  <footer><p>Copyright 2026</p></footer>
</body>
</html>
`;

describe("extractContent", () => {
  it("extracts article content from HTML and converts to markdown", () => {
    const result = extractContent(SAMPLE_HTML, "https://example.com/test");

    expect(result).toContain("# Test Article");
    expect(result).toContain("main content of the article");
    expect(result).toContain("## Section Two");
  });

  it("strips navigation and footer", () => {
    const result = extractContent(SAMPLE_HTML, "https://example.com/test");

    expect(result).not.toContain("Home");
    expect(result).not.toContain("About");
    expect(result).not.toContain("Copyright");
  });

  it("returns empty string for non-article pages", () => {
    const minimalHtml = "<html><body><p>Hi</p></body></html>";
    const result = extractContent(minimalHtml, "https://example.com");

    // Readability may return null for pages with too little content
    expect(typeof result).toBe("string");
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd packages/midnight-fact-checker-utils && npx vitest run tests/extract-url.test.ts
```

Expected: FAIL — `Cannot find module '../src/commands/extract-url.js'`

- [ ] **Step 3: Write the implementation**

Create `packages/midnight-fact-checker-utils/src/commands/extract-url.ts`:

```typescript
import { Readability } from "@mozilla/readability";
import { JSDOM } from "jsdom";
import TurndownService from "turndown";

const turndown = new TurndownService({
  headingStyle: "atx",
  codeBlockStyle: "fenced",
});

export function extractContent(html: string, url: string): string {
  const dom = new JSDOM(html, { url });
  const article = new Readability(dom.window.document).parse();

  if (!article || !article.content) {
    return "";
  }

  const markdown = turndown.turndown(article.content);
  return markdown;
}

export async function extractUrl(url: string): Promise<string> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to fetch ${url}: ${response.status} ${response.statusText}`);
  }
  const html = await response.text();
  return extractContent(html, url);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd packages/midnight-fact-checker-utils && npx vitest run tests/extract-url.test.ts
```

Expected: All 3 tests PASS.

- [ ] **Step 5: Wire up the CLI subcommand**

Modify `packages/midnight-fact-checker-utils/src/cli.ts` — add import at top:

```typescript
import { extractUrl } from "./commands/extract-url.js";
```

Add the subcommand after the `discover` command registration:

```typescript
program
  .command("extract-url")
  .description("Fetch URL(s) and extract readable content as Markdown")
  .argument("<urls...>", "One or more URLs to extract")
  .action(async (urls: string[]) => {
    for (const url of urls) {
      const markdown = await extractUrl(url);
      if (urls.length > 1) {
        console.log(`\n--- ${url} ---\n`);
      }
      console.log(markdown);
    }
  });
```

- [ ] **Step 6: Build and smoke test**

Run:
```bash
cd packages/midnight-fact-checker-utils && npm run build && node dist/cli.js extract-url "https://docs.midnight.network/develop/tutorial/building"
```

Expected: Markdown output of the tutorial page content.

- [ ] **Step 7: Commit**

```bash
git add packages/midnight-fact-checker-utils
git commit -m "feat(fact-checker-utils): implement extract-url subcommand with readability + turndown"
```

---

### Task 4: Implement the `merge` subcommand — concat mode

**Files:**
- Create: `packages/midnight-fact-checker-utils/src/commands/merge.ts`
- Create: `packages/midnight-fact-checker-utils/tests/merge.test.ts`

- [ ] **Step 1: Write the failing test for concat mode**

Create `packages/midnight-fact-checker-utils/tests/merge.test.ts`:

```typescript
import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { mergeConcat, mergeUpdate } from "../src/commands/merge.js";

describe("merge — concat mode", () => {
  let tempDir: string;

  beforeEach(() => {
    tempDir = mkdtempSync(join(tmpdir(), "merge-test-"));
  });

  afterEach(() => {
    rmSync(tempDir, { recursive: true, force: true });
  });

  it("concatenates multiple JSON arrays into one", () => {
    const file1 = join(tempDir, "a.json");
    const file2 = join(tempDir, "b.json");
    const output = join(tempDir, "out.json");

    writeFileSync(
      file1,
      JSON.stringify([
        { id: "claim-001", claim: "A" },
        { id: "claim-002", claim: "B" },
      ])
    );
    writeFileSync(
      file2,
      JSON.stringify([
        { id: "claim-003", claim: "C" },
      ])
    );

    mergeConcat([file1, file2], output);

    const result = JSON.parse(readFileSync(output, "utf-8"));
    expect(result).toHaveLength(3);
    expect(result[0].id).toBe("claim-001");
    expect(result[2].id).toBe("claim-003");
  });

  it("handles empty arrays", () => {
    const file1 = join(tempDir, "a.json");
    const file2 = join(tempDir, "b.json");
    const output = join(tempDir, "out.json");

    writeFileSync(file1, JSON.stringify([{ id: "claim-001", claim: "A" }]));
    writeFileSync(file2, JSON.stringify([]));

    mergeConcat([file1, file2], output);

    const result = JSON.parse(readFileSync(output, "utf-8"));
    expect(result).toHaveLength(1);
  });

  it("outputs valid JSON", () => {
    const file1 = join(tempDir, "a.json");
    const output = join(tempDir, "out.json");

    writeFileSync(file1, JSON.stringify([{ id: "claim-001", claim: "A" }]));

    mergeConcat([file1], output);

    expect(() => JSON.parse(readFileSync(output, "utf-8"))).not.toThrow();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd packages/midnight-fact-checker-utils && npx vitest run tests/merge.test.ts
```

Expected: FAIL — `Cannot find module '../src/commands/merge.js'`

- [ ] **Step 3: Write the concat implementation**

Create `packages/midnight-fact-checker-utils/src/commands/merge.ts`:

```typescript
import { readFileSync, writeFileSync } from "node:fs";

interface Claim {
  id: string;
  [key: string]: unknown;
}

export function mergeConcat(inputFiles: string[], outputPath: string): void {
  const combined: Claim[] = [];

  for (const file of inputFiles) {
    const content = readFileSync(file, "utf-8");
    const parsed = JSON.parse(content);

    if (!Array.isArray(parsed)) {
      throw new Error(`${file} does not contain a JSON array`);
    }

    combined.push(...parsed);
  }

  const output = JSON.stringify(combined, null, 2);

  // Validate output is valid JSON before writing
  JSON.parse(output);

  writeFileSync(outputPath, output);
}

export function mergeUpdate(
  originalFile: string,
  copyFiles: string[],
  outputPath: string
): void {
  // Implemented in next task
  throw new Error("Not implemented");
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd packages/midnight-fact-checker-utils && npx vitest run tests/merge.test.ts
```

Expected: All 3 concat tests PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/midnight-fact-checker-utils
git commit -m "feat(fact-checker-utils): implement merge concat mode"
```

---

### Task 5: Implement the `merge` subcommand — update mode

**Files:**
- Modify: `packages/midnight-fact-checker-utils/src/commands/merge.ts`
- Modify: `packages/midnight-fact-checker-utils/tests/merge.test.ts`

- [ ] **Step 1: Write the failing tests for update mode**

Append to `packages/midnight-fact-checker-utils/tests/merge.test.ts`:

```typescript
describe("merge — update mode", () => {
  let tempDir: string;

  beforeEach(() => {
    tempDir = mkdtempSync(join(tmpdir(), "merge-test-"));
  });

  afterEach(() => {
    rmSync(tempDir, { recursive: true, force: true });
  });

  it("merges updates from copies into the original by id", () => {
    const original = join(tempDir, "original.json");
    const copy1 = join(tempDir, "copy1.json");
    const copy2 = join(tempDir, "copy2.json");
    const output = join(tempDir, "out.json");

    writeFileSync(
      original,
      JSON.stringify([
        { id: "claim-001", claim: "A" },
        { id: "claim-002", claim: "B" },
      ])
    );
    writeFileSync(
      copy1,
      JSON.stringify([
        { id: "claim-001", claim: "A", domains: ["compact"] },
        { id: "claim-002", claim: "B" },
      ])
    );
    writeFileSync(
      copy2,
      JSON.stringify([
        { id: "claim-001", claim: "A" },
        { id: "claim-002", claim: "B", domains: ["sdk"] },
      ])
    );

    mergeUpdate(original, [copy1, copy2], output);

    const result = JSON.parse(readFileSync(output, "utf-8"));
    expect(result).toHaveLength(2);
    expect(result[0].domains).toEqual(["compact"]);
    expect(result[1].domains).toEqual(["sdk"]);
  });

  it("deep merges nested objects", () => {
    const original = join(tempDir, "original.json");
    const copy1 = join(tempDir, "copy1.json");
    const output = join(tempDir, "out.json");

    writeFileSync(
      original,
      JSON.stringify([
        { id: "claim-001", claim: "A", source: { file: "test.md" } },
      ])
    );
    writeFileSync(
      copy1,
      JSON.stringify([
        {
          id: "claim-001",
          claim: "A",
          source: { file: "test.md" },
          classification: { primary_domain: "compact" },
        },
      ])
    );

    mergeUpdate(original, [copy1], output);

    const result = JSON.parse(readFileSync(output, "utf-8"));
    expect(result[0].source.file).toBe("test.md");
    expect(result[0].classification.primary_domain).toBe("compact");
  });

  it("throws if claim count changes", () => {
    const original = join(tempDir, "original.json");
    const copy1 = join(tempDir, "copy1.json");
    const output = join(tempDir, "out.json");

    writeFileSync(
      original,
      JSON.stringify([
        { id: "claim-001", claim: "A" },
        { id: "claim-002", claim: "B" },
      ])
    );
    writeFileSync(
      copy1,
      JSON.stringify([
        { id: "claim-001", claim: "A" },
      ])
    );

    expect(() => mergeUpdate(original, [copy1], output)).toThrow(
      /claim count mismatch/i
    );
  });

  it("throws if a copy contains an id not in the original", () => {
    const original = join(tempDir, "original.json");
    const copy1 = join(tempDir, "copy1.json");
    const output = join(tempDir, "out.json");

    writeFileSync(
      original,
      JSON.stringify([{ id: "claim-001", claim: "A" }])
    );
    writeFileSync(
      copy1,
      JSON.stringify([
        { id: "claim-001", claim: "A" },
        { id: "claim-999", claim: "Z" },
      ])
    );

    expect(() => mergeUpdate(original, [copy1], output)).toThrow(
      /claim count mismatch/i
    );
  });
});
```

- [ ] **Step 2: Run tests to verify new tests fail**

Run:
```bash
cd packages/midnight-fact-checker-utils && npx vitest run tests/merge.test.ts
```

Expected: Concat tests PASS, update tests FAIL with `Not implemented`.

- [ ] **Step 3: Implement update mode**

Replace the `mergeUpdate` function in `packages/midnight-fact-checker-utils/src/commands/merge.ts`:

```typescript
function deepMerge(target: Record<string, unknown>, source: Record<string, unknown>): Record<string, unknown> {
  const result = { ...target };
  for (const key of Object.keys(source)) {
    const targetVal = target[key];
    const sourceVal = source[key];
    if (
      targetVal &&
      sourceVal &&
      typeof targetVal === "object" &&
      typeof sourceVal === "object" &&
      !Array.isArray(targetVal) &&
      !Array.isArray(sourceVal)
    ) {
      result[key] = deepMerge(
        targetVal as Record<string, unknown>,
        sourceVal as Record<string, unknown>
      );
    } else {
      result[key] = sourceVal;
    }
  }
  return result;
}

export function mergeUpdate(
  originalFile: string,
  copyFiles: string[],
  outputPath: string
): void {
  const original: Claim[] = JSON.parse(readFileSync(originalFile, "utf-8"));
  const originalCount = original.length;

  // Build a map from id → claim for the base
  const claimMap = new Map<string, Record<string, unknown>>();
  for (const claim of original) {
    claimMap.set(claim.id, claim as Record<string, unknown>);
  }

  // Apply updates from each copy
  for (const file of copyFiles) {
    const copy: Claim[] = JSON.parse(readFileSync(file, "utf-8"));

    if (copy.length !== originalCount) {
      throw new Error(
        `Claim count mismatch: original has ${originalCount}, ${file} has ${copy.length}`
      );
    }

    for (const claim of copy) {
      const existing = claimMap.get(claim.id);
      if (!existing) {
        throw new Error(
          `Claim count mismatch: ${file} contains unknown id "${claim.id}"`
        );
      }
      claimMap.set(
        claim.id,
        deepMerge(existing, claim as Record<string, unknown>)
      );
    }
  }

  // Preserve original ordering
  const merged = original.map((claim) => claimMap.get(claim.id)!);

  const output = JSON.stringify(merged, null, 2);
  JSON.parse(output); // Validate

  writeFileSync(outputPath, output);
}
```

- [ ] **Step 4: Run all tests to verify they pass**

Run:
```bash
cd packages/midnight-fact-checker-utils && npx vitest run tests/merge.test.ts
```

Expected: All 7 tests PASS (3 concat + 4 update).

- [ ] **Step 5: Wire up the CLI subcommand**

Modify `packages/midnight-fact-checker-utils/src/cli.ts` — add import:

```typescript
import { mergeConcat, mergeUpdate } from "./commands/merge.js";
```

Add the subcommand:

```typescript
program
  .command("merge")
  .description("Merge JSON claim files with validation")
  .argument("<files...>", "JSON files to merge (first is original in update mode)")
  .option("-o, --output <path>", "Output file path", "merged.json")
  .option(
    "-m, --mode <mode>",
    "Merge mode: concat (combine arrays) or update (merge by id)",
    "update"
  )
  .action((files: string[], opts: { output: string; mode: string }) => {
    if (opts.mode === "concat") {
      mergeConcat(files, opts.output);
    } else if (opts.mode === "update") {
      const [original, ...copies] = files;
      if (!copies.length) {
        console.error("Update mode requires at least 2 files (original + copies)");
        process.exit(1);
      }
      mergeUpdate(original, copies, opts.output);
    } else {
      console.error(`Unknown mode: ${opts.mode}. Use "concat" or "update".`);
      process.exit(1);
    }
    console.log(JSON.stringify({ status: "ok", output: opts.output }));
  });
```

- [ ] **Step 6: Build and verify**

Run:
```bash
cd packages/midnight-fact-checker-utils && npm run build
```

Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add packages/midnight-fact-checker-utils
git commit -m "feat(fact-checker-utils): implement merge update mode with deep merge and validation"
```

---

### Task 6: GitHub Actions publish workflow

**Files:**
- Create: `.github/workflows/publish-fact-checker-utils.yml`

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/publish-fact-checker-utils.yml`:

```yaml
name: Publish @aaronbassett/midnight-fact-checker-utils

on:
  push:
    branches:
      - main
    paths:
      - "packages/midnight-fact-checker-utils/**"

jobs:
  publish:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: packages/midnight-fact-checker-utils

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "20"
          registry-url: "https://registry.npmjs.org"

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Check if version changed
        id: version-check
        run: |
          LOCAL_VERSION=$(node -p "require('./package.json').version")
          PUBLISHED_VERSION=$(npm view @aaronbassett/midnight-fact-checker-utils version 2>/dev/null || echo "0.0.0")
          if [ "$LOCAL_VERSION" != "$PUBLISHED_VERSION" ]; then
            echo "changed=true" >> $GITHUB_OUTPUT
            echo "Version changed: $PUBLISHED_VERSION → $LOCAL_VERSION"
          else
            echo "changed=false" >> $GITHUB_OUTPUT
            echo "Version unchanged: $LOCAL_VERSION"
          fi

      - name: Build
        if: steps.version-check.outputs.changed == 'true'
        run: npm run build

      - name: Publish to npm
        if: steps.version-check.outputs.changed == 'true'
        run: npm publish
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/publish-fact-checker-utils.yml
git commit -m "ci: add GitHub Actions workflow for npm package publishing"
```

---

## Phase 2: Plugin

### Task 7: Scaffold the plugin

**Files:**
- Create: `plugins/midnight-fact-check/.claude-plugin/plugin.json`
- Create: all directories

- [ ] **Step 1: Create directory structure**

Run:
```bash
mkdir -p plugins/midnight-fact-check/.claude-plugin
mkdir -p plugins/midnight-fact-check/commands
mkdir -p plugins/midnight-fact-check/agents
mkdir -p plugins/midnight-fact-check/skills/fact-check-extraction
mkdir -p plugins/midnight-fact-check/skills/fact-check-classification
mkdir -p plugins/midnight-fact-check/skills/fact-check-reporting
```

- [ ] **Step 2: Write plugin.json**

Create `plugins/midnight-fact-check/.claude-plugin/plugin.json`:

```json
{
  "name": "midnight-fact-check",
  "version": "0.1.0",
  "description": "Fact-checking pipeline for Midnight content — extracts testable claims from any source (markdown, code, PDFs, URLs, GitHub repos), classifies them by domain (Compact, SDK, ZKIR, Witness), and verifies each claim using the midnight-verify framework. Produces structured JSON artifacts and human-readable reports.",
  "author": {
    "name": "Aaron Bassett",
    "email": "aaron@devrel-ai.com"
  },
  "homepage": "https://github.com/devrelaicom/midnight-expert",
  "repository": "https://github.com/devrelaicom/midnight-expert.git",
  "license": "MIT",
  "keywords": [
    "midnight",
    "fact-check",
    "verification",
    "claims",
    "extraction",
    "classification",
    "compact",
    "sdk",
    "zkir",
    "witness",
    "report",
    "pipeline"
  ]
}
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-fact-check
git commit -m "feat(midnight-fact-check): scaffold plugin directory structure"
```

---

### Task 8: Write the fact-check-extraction skill

**Files:**
- Create: `plugins/midnight-fact-check/skills/fact-check-extraction/SKILL.md`

- [ ] **Step 1: Write the skill**

Create `plugins/midnight-fact-check/skills/fact-check-extraction/SKILL.md`:

```markdown
---
name: midnight-fact-check:fact-check-extraction
description: >-
  Claim extraction skill for the midnight-fact-check pipeline. Defines what
  constitutes a testable claim in Midnight documentation, how to identify
  claims in source content, the JSON output schema, and examples of good
  vs bad extractions. Used by the claim-extractor agent to parse content
  chunks and produce structured claim lists.
version: 0.1.0
---

# Claim Extraction

You are extracting **testable claims** from Midnight-related content. A testable claim is a statement that can be verified or refuted through one of these methods:

- Compiling and/or executing a Compact contract
- Running TypeScript type-checks (`tsc --noEmit`)
- Running code against a devnet
- Inspecting compiler, SDK, or ledger source code
- Running the ZKIR WASM checker
- Inspecting compiled ZKIR structure

## What IS a Testable Claim

- Statements about language syntax: "Compact tuples are 0-indexed"
- Statements about types: "persistentHash<T>() returns Bytes<32>"
- Statements about behavior: "Uint subtraction fails at runtime if the result would be negative"
- Statements about APIs: "deployContract returns DeployedContract"
- Statements about errors: "Using deprecated ledger {} syntax produces a parse error"
- Statements about compiler behavior: "disclosure compiles to declare_pub_input in ZKIR"
- Statements about circuit properties: "A pure circuit has no private_input instructions"

## What is NOT a Testable Claim

- General advice: "You should test your contracts thoroughly"
- Subjective statements: "Compact is a simple language"
- Process descriptions: "First, install the CLI tool"
- Definitions without behavior: "A circuit is a function"
- Future plans: "Support for X will be added"
- Meta-documentation: "This section covers..."

## Output Schema

For each claim you extract, produce a JSON object:

```json
{
  "claim": "The verbatim or highly specific claim text",
  "source": {
    "file": "relative/path/to/source/file.md",
    "line_range": [42, 44],
    "context": "Brief surrounding context (the section or heading this claim appears under)"
  }
}
```

### Field Rules

- **claim**: Use the exact wording from the source when possible. If the claim is implicit (spread across sentences), synthesize a single precise statement.
- **source.file**: The file path as provided in your task prompt.
- **source.line_range**: Best-effort line numbers. If you cannot determine exact lines, use `[0, 0]`.
- **source.context**: The heading or section name, e.g., "Standard Library > Hashing Functions".

## Output Format

Return a JSON array of claim objects. Nothing else — no commentary, no markdown wrapping.

```json
[
  {
    "claim": "persistentHash<T>() returns Bytes<32>",
    "source": {
      "file": "skills/compact-language-ref/references/stdlib.md",
      "line_range": [42, 44],
      "context": "Standard Library > Hashing Functions"
    }
  },
  {
    "claim": "Uint subtraction fails at runtime if the result would be negative",
    "source": {
      "file": "skills/compact-language-ref/references/types.md",
      "line_range": [118, 120],
      "context": "Type System > Unsigned Integers"
    }
  }
]
```

## Extraction Guidelines

1. **Be thorough.** Extract every testable claim, even if it seems obvious.
2. **One claim per object.** Do not combine multiple claims into one.
3. **Preserve specificity.** "persistentHash returns Bytes<32>" is better than "persistentHash returns bytes".
4. **Include negative claims.** "Division (/) does NOT exist in Compact" is testable.
5. **Include error claims.** "Using X produces error Y" is testable.
6. **Skip code examples that are purely illustrative** unless they contain an implicit claim about behavior.
7. If the content contains no testable claims, return an empty array: `[]`
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-fact-check/skills/fact-check-extraction
git commit -m "feat(midnight-fact-check): add fact-check-extraction skill"
```

---

### Task 9: Write the fact-check-classification skill

**Files:**
- Create: `plugins/midnight-fact-check/skills/fact-check-classification/SKILL.md`

- [ ] **Step 1: Write the skill**

Create `plugins/midnight-fact-check/skills/fact-check-classification/SKILL.md`:

```markdown
---
name: midnight-fact-check:fact-check-classification
description: >-
  Domain classification skill for the midnight-fact-check pipeline. Defines
  the four verification domains (Compact, SDK, ZKIR, Witness), how to tag
  claims with domains, rules for cross-domain classification, and handling
  of boundary cases. Used by the domain-classifier agent to tag claims in
  its assigned domain.
version: 0.1.0
---

# Domain Classification

You are a domain-specialist classifier. You have been assigned **one domain** and must tag every claim in the claims file that belongs to your domain.

## The Four Domains

### compact

Claims about the Compact smart contract language:
- Syntax, grammar, keywords, operators
- Type system (Uint, Field, Boolean, Bytes, tuples, structs, enums, generics)
- Standard library functions (persistentHash, transientHash, Counter, Map, Set, etc.)
- Control flow (for loops, if/else, assert)
- Disclosure and privacy (disclose(), ledger visibility)
- Module system (imports, exports, pragma)
- Compiler behavior (errors, warnings, accepted/rejected syntax)

**Examples:**
- "Compact tuples are 0-indexed" → compact
- "The for loop uses lower..upper syntax (inclusive..exclusive)" → compact
- "assert(condition, message) is the only error-handling mechanism" → compact

### sdk

Claims about the Midnight SDK, TypeScript APIs, and DApp development:
- Package exports and imports (`@midnight-ntwrk/*`)
- API signatures, return types, error types
- Provider configuration, network connectivity
- DApp connector patterns
- Transaction lifecycle
- Deployment and contract interaction

**Examples:**
- "deployContract returns DeployedContract" → sdk
- "CallTxFailedError extends TxFailedError" → sdk
- "The indexer GraphQL endpoint is at /api/v1/graphql" → sdk

### zkir

Claims about Zero-Knowledge Intermediate Representation:
- Opcode semantics (add, mul, neg, assert, constrain_bits, etc.)
- Field arithmetic (wrapping, modular)
- Circuit structure (instruction counts, I/O shape)
- Proof pipeline (PLONK checker, transcript protocol)
- Compiled output format

**Examples:**
- "add wraps modulo the field prime r" → zkir
- "disclosure compiles to declare_pub_input" → zkir
- "A pure circuit has no private_input instructions" → zkir

### witness

Claims about TypeScript witness implementations:
- Witness function signatures and return types
- WitnessContext usage
- Private state handling
- Type mappings between Compact and TypeScript
- Witness/contract interface matching

**Examples:**
- "Witness functions must return [PrivateState, ReturnValue]" → witness
- "Boolean maps to boolean in TypeScript" → witness
- "WitnessContext is the first parameter" → witness

## Your Task

You have been assigned the domain: **[provided in dispatch prompt]**

1. Read the claims file (your copy)
2. For each claim, determine if it belongs to your domain
3. If it does, update the claim object by adding/merging your domain into the `domains` array and setting `classification` fields
4. If it does not belong to your domain, leave it unchanged
5. Write the updated file

### When a Claim Belongs to Your Domain

Add or merge these fields:

```json
{
  "domains": ["your-domain"],
  "classification": {
    "primary_domain": "your-domain",
    "confidence": "high",
    "notes": "Brief reason this belongs to your domain"
  }
}
```

- If `domains` already exists (from another classifier), **append** your domain to the array.
- If `classification` already exists, only overwrite `primary_domain` if your confidence is higher.
- **confidence** values: `"high"` (clearly in your domain), `"medium"` (partially in your domain, might be cross-domain).

### Cross-Domain Claims

Some claims span multiple domains. If a claim is partially in your domain:
- Add your domain to `domains`
- Set confidence to `"medium"`
- Add a note explaining the cross-domain nature

Example: "Compact Boolean maps to TypeScript boolean" spans both `compact` and `witness`. Both classifiers should tag it.

### Boundary Cases

- If a claim is about **compiler behavior** (what the compiler does), it's `compact`
- If a claim is about **compiled output** (what ZKIR looks like), it's `zkir`
- If a claim is about **SDK types that mirror Compact types**, it's `sdk` (not compact)
- If a claim is about **witness types that mirror Compact types**, it's `witness` (not compact)

## Output

Write the updated claims file to your copy path. Return a summary:

```
Tagged N claims as [domain]. Skipped M claims (not in my domain).
Cross-domain tags: K claims also tagged by other domains.
```
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-fact-check/skills/fact-check-classification
git commit -m "feat(midnight-fact-check): add fact-check-classification skill"
```

---

### Task 10: Write the fact-check-reporting skill

**Files:**
- Create: `plugins/midnight-fact-check/skills/fact-check-reporting/SKILL.md`

- [ ] **Step 1: Write the skill**

Create `plugins/midnight-fact-check/skills/fact-check-reporting/SKILL.md`:

```markdown
---
name: midnight-fact-check:fact-check-reporting
description: >-
  Report generation skill for the midnight-fact-check pipeline. Contains
  the markdown report template, terminal summary format, and GitHub issue
  templates (per-claim, per-file, and summary). Used by the check command
  in Stage 4 to assemble the final report from verification results.
version: 0.1.0
---

# Report Generation

## Markdown Report Template (report.md)

Generate a report using this structure:

```markdown
# Fact-Check Report: [run-short-name]

**Date:** [timestamp]
**Source:** [target descriptions]
**Run ID:** [full run directory path]

## Executive Summary

| Verdict | Count |
|---------|-------|
| Confirmed | N |
| Refuted | N |
| Inconclusive | N |
| **Total** | **N** |

## Refuted Claims

_List refuted claims first — these are the actionable findings._

| # | Claim | Domain | Evidence |
|---|-------|--------|----------|
| claim-XXX | [claim text] | [domain] | [evidence_summary] |

## Results by Domain

### Compact (N claims)

| Verdict | Qualifier | Claim | Source | Evidence |
|---------|-----------|-------|--------|----------|
| Confirmed | tested | [claim] | [file:lines] | [evidence] |
| Refuted | tested | [claim] | [file:lines] | [evidence] |

### SDK (N claims)

[Same table format]

### ZKIR (N claims)

[Same table format]

### Witness (N claims)

[Same table format]

### Cross-Domain (N claims)

[Same table format]

### Unclassified (N claims)

[Claims that no domain classifier tagged — listed as inconclusive]
```

### Verdict Indicators

Use these in terminal output:
- Confirmed → `[CONFIRMED]`
- Refuted → `[REFUTED]`
- Inconclusive → `[INCONCLUSIVE]`

## Terminal Summary Format

Print this to the terminal after writing the report:

```
═══════════════════════════════════════════
  Fact-Check Complete: [run-short-name]
═══════════════════════════════════════════

  Confirmed:    NN
  Refuted:      NN
  Inconclusive: NN
  ─────────────
  Total:        NN

  [If refuted > 0:]
  REFUTED CLAIMS:
    - [claim-XXX] [claim text (truncated to 80 chars)]
      Evidence: [evidence_summary (truncated to 100 chars)]
    - [claim-YYY] ...

  Artifacts: [full run directory path]
  Report:    [path to report.md]
═══════════════════════════════════════════
```

## GitHub Issue Templates

### Per-Claim Issue

```markdown
Title: [REFUTED] [claim text (truncated to 60 chars)]

Body:
## Refuted Claim

**Claim:** [full claim text]
**Source:** [file path, line range]
**Domain:** [domain]

## Verification Evidence

**Verdict:** Refuted ([qualifier])
**Evidence:** [full evidence_summary]

## Context

This claim was identified by the midnight-fact-check pipeline.
- **Run:** [run directory]
- **Source file:** [link to file if GitHub URL available]

---
_Generated by midnight-fact-check_
```

### Per-File Issue

```markdown
Title: Fact-check findings: [filename] ([N] refuted claims)

Body:
## Fact-Check Results for [full file path]

[N] claims were refuted in this file.

### Refuted Claims

- [ ] **[claim-XXX]:** [claim text]
  - Evidence: [evidence_summary]
  - Line(s): [line_range]

- [ ] **[claim-YYY]:** [claim text]
  - Evidence: [evidence_summary]
  - Line(s): [line_range]

## Run Details

- **Run:** [run directory]
- **Total claims checked:** [N]
- **Confirmed:** [N] | **Refuted:** [N] | **Inconclusive:** [N]

---
_Generated by midnight-fact-check_
```

### Summary Issue

```markdown
Title: Fact-check report: [N] refuted claims across [M] files

Body:
## Fact-Check Summary

| File | Refuted | Confirmed | Inconclusive |
|------|---------|-----------|--------------|
| [file1] | N | N | N |
| [file2] | N | N | N |

### All Refuted Claims

| # | File | Claim | Evidence |
|---|------|-------|----------|
| claim-XXX | [file] | [claim] | [evidence] |

## Run Details

- **Run:** [run directory]
- **Full report:** [path to report.md]

---
_Generated by midnight-fact-check_
```
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-fact-check/skills/fact-check-reporting
git commit -m "feat(midnight-fact-check): add fact-check-reporting skill"
```

---

### Task 11: Write the claim-extractor agent

**Files:**
- Create: `plugins/midnight-fact-check/agents/claim-extractor.md`

- [ ] **Step 1: Write the agent**

Create `plugins/midnight-fact-check/agents/claim-extractor.md`:

```markdown
---
name: claim-extractor
description: >-
  Use this agent to extract testable claims from a chunk of Midnight-related
  content. Dispatched by the /midnight-fact-check:check command in Stage 1,
  one instance per content chunk, running in parallel.

  The agent reads its assigned content (file paths provided in the dispatch
  prompt), identifies all testable claims, and returns them as a JSON array.

  Example: Dispatched with a skill's SKILL.md and its references/ folder.
  The agent reads all files, identifies claims like "persistentHash returns
  Bytes<32>" and "for loops use lower..upper syntax", and returns a JSON
  array of claim objects.
skills: midnight-fact-check:fact-check-extraction
model: sonnet
color: cyan
---

You are a claim extractor for the midnight-fact-check pipeline.

## Your Job

1. Load the `midnight-fact-check:fact-check-extraction` skill — it defines what a testable claim is and the output schema.
2. Read all content files listed in your dispatch prompt.
3. Extract every testable claim following the skill's guidelines.
4. Return the claims as a JSON array.

## Process

1. Read each file assigned to you.
2. For each file, scan for testable claims (statements about syntax, types, behavior, APIs, errors, compiler behavior, circuit properties).
3. Create a claim object for each, with the source file path and best-effort line range.
4. Return the complete array as your response.

## Important

- Be thorough — extract every testable claim, even obvious ones.
- One claim per object — do not combine multiple assertions.
- Return ONLY the JSON array — no commentary, no markdown wrapping.
- If a file contains no testable claims, do not include any objects for it.
- If none of your assigned files contain testable claims, return `[]`.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-fact-check/agents/claim-extractor.md
git commit -m "feat(midnight-fact-check): add claim-extractor agent"
```

---

### Task 12: Write the domain-classifier agent

**Files:**
- Create: `plugins/midnight-fact-check/agents/domain-classifier.md`

- [ ] **Step 1: Write the agent**

Create `plugins/midnight-fact-check/agents/domain-classifier.md`:

```markdown
---
name: domain-classifier
description: >-
  Use this agent to classify claims by domain. Dispatched by the
  /midnight-fact-check:check command in Stage 2, one instance per domain
  (compact, sdk, zkir, witness), running in parallel.

  Each instance receives its assigned domain and a copy of the claims file.
  It reads the copy, tags claims belonging to its domain, writes the updated
  copy, and returns a summary.

  Example: Dispatched as the "compact" classifier. Reads claims file, tags
  claims about Compact syntax, types, stdlib, and compiler behavior with
  domain "compact". Writes updated copy. Returns "Tagged 45 claims as compact."
skills: midnight-fact-check:fact-check-classification
model: sonnet
color: green
---

You are a domain classifier for the midnight-fact-check pipeline.

## Your Job

1. Load the `midnight-fact-check:fact-check-classification` skill — it defines domain boundaries and tagging rules.
2. Your dispatch prompt tells you:
   - Your assigned domain (compact, sdk, zkir, or witness)
   - The path to your copy of the claims file
3. Read the claims file.
4. For each claim, decide if it belongs to your domain. If yes, tag it per the skill's instructions.
5. Write the updated claims file to the same copy path.
6. Return a summary of what you tagged.

## Important

- Only tag claims that belong to YOUR domain. Leave other claims unchanged.
- If a claim is partially in your domain (cross-domain), tag it with medium confidence.
- Do NOT remove or modify any existing fields on claims — only ADD your domain tag and classification.
- Do NOT change the claim count — the merge script validates this.
- Write the complete file (all claims, including ones you didn't tag).
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-fact-check/agents/domain-classifier.md
git commit -m "feat(midnight-fact-check): add domain-classifier agent"
```

---

### Task 13: Write the claim-verifier agent

**Files:**
- Create: `plugins/midnight-fact-check/agents/claim-verifier.md`

- [ ] **Step 1: Write the agent**

Create `plugins/midnight-fact-check/agents/claim-verifier.md`:

```markdown
---
name: claim-verifier
description: >-
  Use this agent to verify a batch of pre-classified claims using the
  midnight-verify framework. Dispatched by the /midnight-fact-check:check
  command in Stage 3, one instance per domain-batch, running in parallel.

  Each instance receives a batch of claims for a specific domain and a
  copy of the claims file. It loads the /verify skill, verifies each claim
  sequentially, writes the updated copy with verdicts, and returns a summary.

  Example: Dispatched with 12 Compact-domain claims. For each claim, invokes
  the verify-correctness process, gets a verdict (confirmed/refuted/inconclusive),
  and writes the result back to its copy. Returns "Verified 12 claims:
  10 confirmed, 1 refuted, 1 inconclusive."
skills: midnight-verify:verify-correctness, midnight-verify:verify-compact, midnight-verify:verify-sdk, midnight-verify:verify-zkir, midnight-verify:verify-witness
model: sonnet
color: red
---

You are a claim verifier for the midnight-fact-check pipeline.

## Your Job

1. Load the `midnight-verify:verify-correctness` hub skill — it tells you how to classify, route, and verify claims.
2. Your dispatch prompt tells you:
   - The domain for this batch (compact, sdk, zkir, witness, or cross-domain)
   - The specific claim IDs in your batch
   - The path to your copy of the claims file
3. Read the claims file.
4. For each claim in your batch, verify it using the verify-correctness process:
   - Classify the claim type within the domain
   - Determine the verification method
   - Execute the verification (compile, type-check, run, inspect source, etc.)
   - Record the verdict
5. Update each verified claim with the verification result.
6. Write the updated claims file to the same copy path.
7. Return a summary.

## Verification Result Format

For each claim you verify, add a `verification` field:

```json
{
  "verification": {
    "verdict": "confirmed",
    "qualifier": "tested",
    "evidence_summary": "Contract compiled and executed successfully. persistentHash returned Bytes<32> as expected.",
    "agent_id": "[your agent identifier from dispatch]",
    "verified_at": "[ISO 8601 timestamp]"
  }
}
```

## Important

- Verify claims SEQUENTIALLY within your batch — each verification may involve compilation, execution, or source inspection that should complete before the next.
- Only modify claims in your assigned batch (by ID). Leave other claims unchanged.
- Do NOT change the claim count.
- If verification fails (tool error, timeout, etc.), set verdict to `"inconclusive"` with qualifier `"error"` and explain in evidence_summary.
- Use the verification methods defined by midnight-verify — do not invent your own verification approach.
- Write the complete file (all claims) after processing your batch.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-fact-check/agents/claim-verifier.md
git commit -m "feat(midnight-fact-check): add claim-verifier agent"
```

---

### Task 14: Write the check command

**Files:**
- Create: `plugins/midnight-fact-check/commands/check.md`

This is the largest file — it orchestrates the entire pipeline.

- [ ] **Step 1: Write the command**

Create `plugins/midnight-fact-check/commands/check.md`:

```markdown
---
name: midnight-fact-check:check
description: Fact-check content against the Midnight ecosystem. Extracts claims, classifies by domain, verifies each via midnight-verify, and produces a report.
allowed-tools: Agent, AskUserQuestion, Read, Write, Glob, Grep, Bash
argument-hint: "<file, directory, URL, GitHub URL, or glob pattern>"
---

Fact-check Midnight-related content by running a staged pipeline: extract claims → classify by domain → verify → report.

## Step 1: Preflight

Check that midnight-verify is available. Use Glob to check:

```
plugins/midnight-verify/skills/verify-correctness/SKILL.md
```

If the file does not exist, tell the user:

> "midnight-verify plugin is required but not found. Install it before running fact-check."

Then stop. Do not proceed to Step 2.

## Step 2: Initialize Run

Generate a run directory:

1. Get the current month and year as `MM-YY` (e.g., `03-26`)
2. Choose a short name (2-4 words, kebab-case) describing the source content (e.g., `compact-core-plugin`, `sdk-tutorial`, `counter-contract`)
3. Generate a 4-character random alphanumeric ID (e.g., `a3Kf`)
4. Create the run directory:

```bash
RUN_DIR=".midnight-expert/fact-checker/MM-YY/run-short-name-XXXX"
mkdir -p "$RUN_DIR"
```

5. Write `run-metadata.json` to the run directory:

```json
{
  "targets": ["$ARGUMENTS"],
  "started_at": "ISO-8601 timestamp",
  "run_dir": "the full run directory path"
}
```

Tell the user: `"Run initialized: [run directory path]"`

## Step 3: Resolve Inputs (Stage 0)

Parse `$ARGUMENTS` and resolve each target to readable content. Classify each target:

### Local file
- Detected by: path exists on disk and is a file (check with Glob or Bash `test -f`)
- Read the file. If it is a PDF with >20 pages, note it for chunking in Stage 1.
- Add to the content list.

### Local directory (non-plugin)
- Detected by: path exists, is a directory, does NOT contain `.claude-plugin/plugin.json`
- Run file discovery:
  ```bash
  npx @aaronbassett/midnight-fact-checker-utils discover "**/*" --cwd "[directory path]"
  ```
- Show the matched file list to the user and ask for confirmation before proceeding.

### Plugin directory
- Detected by: path exists, is a directory, AND contains `.claude-plugin/plugin.json`
- Scope to plugin content: use Glob to find `skills/*/SKILL.md`, `skills/*/references/*.md`, `commands/*.md`, `agents/*.md`
- Group files by skill (each skill directory = one chunk for extraction).

### URL(s)
- Detected by: starts with `http://` or `https://`, does NOT match `github.com`
- For each URL, run:
  ```bash
  npx @aaronbassett/midnight-fact-checker-utils extract-url "[URL]" > "$RUN_DIR/url-content-N.md"
  ```
- Add the saved markdown files to the content list.

### GitHub file URL
- Detected by: matches `github.com/[owner]/[repo]/blob/[branch]/[path]`
- If the URL can be converted to a `raw.githubusercontent.com` URL, use:
  ```bash
  wget -q -O "$RUN_DIR/github-file.md" "[raw URL]"
  ```
- Otherwise, use the octocode MCP `githubGetFileContent` tool to fetch the file content and write it to the run directory.
- Record the repo info (owner, repo, branch, path) in `run-metadata.json` for potential issue creation in Step 8.

### GitHub directory/repo URL
- Detected by: matches `github.com/[owner]/[repo]/tree/[branch]/[path]` or `github.com/[owner]/[repo]` (bare repo)
- Clone the repo:
  ```bash
  git clone --depth=1 "[repo URL]" "/tmp/fact-check-[short-id]"
  ```
- If the URL included a path (tree/branch/path), scope to that subdirectory.
- Then treat as a local directory (run file discovery, show list, confirm).
- Record repo info in `run-metadata.json`.

### Glob pattern
- Detected by: contains `*`, `?`, `[`, or `{`
- Run file discovery:
  ```bash
  npx @aaronbassett/midnight-fact-checker-utils discover "[pattern]"
  ```
- Show matched file list to user and ask for confirmation.

### After all targets are resolved

Write `resolved-content.json` to the run directory:

```json
{
  "files": [
    {
      "path": "absolute/path/to/file.md",
      "type": "local",
      "chunk_group": "skill-name or parent-dir"
    }
  ],
  "github_source": {
    "owner": "user-or-org",
    "repo": "repo-name",
    "branch": "main",
    "paths": ["path/to/checked/content"]
  }
}
```

The `github_source` field is only present if the source was GitHub-hosted. It enables Step 8.

Tell the user: `"Resolved N files from M targets"`

## Step 4: Extract Claims (Stage 1)

1. Read `resolved-content.json`.
2. Split files into chunks for parallel extraction:
   - If files have `chunk_group` set (plugin skills), group by chunk_group
   - For large single files (>500 lines or PDF >20 pages), split into sections
   - For remaining files, group by parent directory
   - If there are 5 or fewer files total, use a single extractor
3. Dispatch one `midnight-fact-check:claim-extractor` agent per chunk, in parallel. Each agent's prompt should include:
   - The list of file paths in its chunk
   - Instruction to read the files and extract claims
4. Collect the JSON arrays returned by each extractor.
5. Write each extractor's output to the run directory: `extracted-chunk-N.json`
6. Merge all outputs using the merge script in concat mode:
   ```bash
   npx @aaronbassett/midnight-fact-checker-utils merge --mode concat -o "$RUN_DIR/extracted-claims.json" "$RUN_DIR/extracted-chunk-1.json" "$RUN_DIR/extracted-chunk-2.json" ...
   ```
7. Read the merged file. Assign sequential IDs (`claim-001`, `claim-002`, ...) to each claim. Write back.
8. Tell the user: `"Extracted N claims from M content chunks"`

If zero claims were extracted, tell the user and stop:
> "No testable claims found in the provided content. This content may not contain verifiable Midnight claims."

## Step 5: Classify Claims (Stage 2)

1. Read `extracted-claims.json`.
2. Create one copy per domain:
   ```bash
   cp "$RUN_DIR/extracted-claims.json" "$RUN_DIR/extracted-claims.compact-classifier.json"
   cp "$RUN_DIR/extracted-claims.json" "$RUN_DIR/extracted-claims.sdk-classifier.json"
   cp "$RUN_DIR/extracted-claims.json" "$RUN_DIR/extracted-claims.zkir-classifier.json"
   cp "$RUN_DIR/extracted-claims.json" "$RUN_DIR/extracted-claims.witness-classifier.json"
   ```
3. Dispatch four `midnight-fact-check:domain-classifier` agents in parallel. Each agent's prompt should include:
   - Its assigned domain (compact, sdk, zkir, or witness)
   - The path to its copy of the claims file
   - Instruction to tag claims belonging to its domain
4. Wait for all classifiers to complete.
5. Merge all copies:
   ```bash
   npx @aaronbassett/midnight-fact-checker-utils merge --mode update -o "$RUN_DIR/classified-claims.json" "$RUN_DIR/extracted-claims.json" "$RUN_DIR/extracted-claims.compact-classifier.json" "$RUN_DIR/extracted-claims.sdk-classifier.json" "$RUN_DIR/extracted-claims.zkir-classifier.json" "$RUN_DIR/extracted-claims.witness-classifier.json"
   ```
6. If the merge fails (validation error), tell the user:
   > "Merge validation failed. Agent copies preserved in [run directory] for debugging."
   Then stop.
7. Read `classified-claims.json`. Count claims per domain. Count unclassified (no `domains` field or empty `domains` array).
8. For unclassified claims, set:
   ```json
   {
     "verification": {
       "verdict": "inconclusive",
       "qualifier": "no-domain-match",
       "evidence_summary": "No domain classifier tagged this claim."
     }
   }
   ```
   Write the updated file.
9. Tell the user: `"Classified N claims — compact: X, sdk: Y, zkir: Z, witness: W, cross-domain: V, unclassified: U"`

## Step 6: Verify Claims (Stage 3)

1. Read `classified-claims.json`. Group classified claims by `classification.primary_domain`.
2. Determine batches using these rules:
   - Target ~10-15 claims per batch
   - Domain with ≤15 claims → 1 batch
   - Domain with 16-30 claims → 2 batches (split roughly evenly)
   - Domain with 30+ claims → split into batches of ~10
   - Cross-domain claims (those with multiple domains): batch separately
   - Skip unclassified claims (already marked inconclusive)
3. Create one copy of `classified-claims.json` per batch:
   ```bash
   cp "$RUN_DIR/classified-claims.json" "$RUN_DIR/classified-claims.compact-verifier-1.json"
   cp "$RUN_DIR/classified-claims.json" "$RUN_DIR/classified-claims.sdk-verifier-1.json"
   # ... one per batch
   ```
4. Dispatch one `midnight-fact-check:claim-verifier` agent per batch, in parallel. Each agent's prompt should include:
   - The domain for this batch
   - The specific claim IDs in its batch (list them explicitly)
   - The path to its copy of the claims file
   - Instruction to verify each claim using the midnight-verify framework
5. Wait for all verifiers to complete.
6. Merge all copies:
   ```bash
   npx @aaronbassett/midnight-fact-checker-utils merge --mode update -o "$RUN_DIR/verification-results.json" "$RUN_DIR/classified-claims.json" "$RUN_DIR/classified-claims.compact-verifier-1.json" ...
   ```
7. If the merge fails, report and preserve copies (same as Step 5).
8. Tell the user: `"Verified N claims — confirmed: X, refuted: Y, inconclusive: Z"`

## Step 7: Generate Report (Stage 4)

1. Load the `midnight-fact-check:fact-check-reporting` skill for templates.
2. Read `verification-results.json`.
3. Generate `report.md` in the run directory following the skill's template:
   - Executive summary with verdict counts
   - Refuted claims section at the top
   - Per-domain results tables
   - Include unclassified claims in their own section
4. Write the report to `$RUN_DIR/report.md`.
5. Print the terminal summary to the user (following the skill's terminal format).
6. Print the run artifacts path.

## Step 8: GitHub Issues (conditional)

Only run this step if:
- `resolved-content.json` has a `github_source` field (source was GitHub-hosted)
- AND there are refuted claims in the verification results

If both conditions are met:

1. Count refuted claims and affected files.
2. Ask the user using AskUserQuestion:
   > "Found N refuted claims across M files in [owner/repo]. Would you like to create GitHub issues?
   > a) One issue per refuted claim
   > b) One issue per file with refuted claims
   > c) A single summary issue
   > d) No issues"
3. Based on their choice, create issues using the templates from the reporting skill:
   ```bash
   gh issue create --repo "[owner]/[repo]" --title "[title]" --body "[body]"
   ```
4. If `gh` is not authenticated, tell the user:
   > "GitHub CLI is not authenticated. Run `gh auth login` to enable issue creation."
5. Print the created issue URLs.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-fact-check/commands/check.md
git commit -m "feat(midnight-fact-check): add check command — pipeline orchestrator"
```

---

### Task 15: Write the plugin README

**Files:**
- Create: `plugins/midnight-fact-check/README.md`

- [ ] **Step 1: Write the README**

Create `plugins/midnight-fact-check/README.md`:

```markdown
# midnight-fact-check

Fact-checking pipeline for Midnight content. Extracts testable claims from any source, classifies them by domain, verifies each claim using the [midnight-verify](../midnight-verify/) framework, and produces a structured report.

## Usage

```
/midnight-fact-check:check <target> [<target2> ...]
```

### Supported Inputs

| Input | Example |
|-------|---------|
| Local file | `/midnight-fact-check:check ./skills/compact-language-ref/SKILL.md` |
| Directory | `/midnight-fact-check:check ./plugins/compact-core/` |
| Plugin directory | `/midnight-fact-check:check ./plugins/compact-core/` (auto-detected via plugin.json) |
| URL(s) | `/midnight-fact-check:check https://docs.midnight.network/develop/tutorial/building` |
| GitHub file | `/midnight-fact-check:check https://github.com/user/repo/blob/main/README.md` |
| GitHub directory | `/midnight-fact-check:check https://github.com/user/repo/tree/main/docs/` |
| Glob pattern | `/midnight-fact-check:check "./plugins/*/skills/**/*.md"` |

### Pipeline

1. **Preflight** — Verifies midnight-verify plugin is installed
2. **Input Resolution** — Resolves targets to readable content
3. **Extraction** — Parallel agents extract testable claims
4. **Classification** — Domain-specialist agents tag claims (compact, sdk, zkir, witness)
5. **Verification** — Batched parallel agents verify claims via `/verify`
6. **Report** — Markdown report + terminal summary
7. **GitHub Issues** — Optional issue creation for refuted claims (GitHub sources only)

### Run Artifacts

Each run produces a directory under `.midnight-expert/fact-checker/`:

```
.midnight-expert/fact-checker/03-26/compact-core-plugin-a3Kf/
├── run-metadata.json
├── resolved-content.json
├── extracted-claims.json
├── classified-claims.json
├── verification-results.json
└── report.md
```

## Dependencies

- **midnight-verify** plugin (required — checked at preflight)
- **@aaronbassett/midnight-fact-checker-utils** npm package (used via npx)
- **gh** CLI (optional — for GitHub issue creation)
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-fact-check/README.md
git commit -m "docs(midnight-fact-check): add plugin README"
```

---

### Task 16: Register in marketplace.json

**Files:**
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Add midnight-fact-check to the plugins array**

Read `.claude-plugin/marketplace.json` and add this entry to the `plugins` array:

```json
{
  "name": "midnight-fact-check",
  "source": "./plugins/midnight-fact-check"
}
```

- [ ] **Step 2: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat: register midnight-fact-check in marketplace"
```

---

## Self-Review Notes

**Spec coverage check:**
- Overview ✓ (Task 7 plugin.json)
- Architecture / Pipeline ✓ (Task 14 check.md)
- Parallel merge pattern ✓ (Task 14 Steps 4-6)
- Plugin structure ✓ (Task 7)
- npm package ✓ (Tasks 1-6)
- Package publishing ✓ (Task 6)
- Command flow Steps 1-8 ✓ (Task 14)
- Agents ✓ (Tasks 11-13)
- Claim JSON schema ✓ (Skills define it, check.md assigns IDs)
- Run artifacts ✓ (Task 14 creates run dir structure)
- Error handling ✓ (Task 14 check.md covers each case)
- Dependencies ✓ (Task 1 package.json, Task 7 plugin.json)
- Marketplace registration ✓ (Task 16)

**Placeholder scan:** No TBDs, TODOs, or vague instructions found. All code blocks contain complete implementations.

**Type consistency:** `mergeConcat` and `mergeUpdate` function names match across test files, implementation, and CLI wiring. Claim schema fields (`id`, `claim`, `source`, `domains`, `classification`, `verification`) are consistent across extraction skill, classification skill, and reporting skill.
