import { type Dirent, readdirSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { globby, isGitIgnored } from "globby";
import type {
	DirectoryResult,
	DiscoverOptions,
	DiscoverResult,
	UnmatchedFile,
} from "../types/discover.js";

/**
 * Groups file paths by their parent directory.
 * Returns a Map from directory path to array of file paths.
 */
function groupByDirectory(files: readonly string[]): Map<string, string[]> {
	const groups = new Map<string, string[]>();
	for (const file of files) {
		const dir = dirname(file);
		const existing = groups.get(dir);
		if (existing) {
			existing.push(file);
		} else {
			groups.set(dir, [file]);
		}
	}
	return groups;
}

/**
 * Collects all files recursively from a directory.
 * Returns paths relative to the given cwd.
 */
function collectAllFiles(cwd: string): string[] {
	const result: string[] = [];

	function walk(dir: string): void {
		let entries: Dirent[];
		try {
			entries = readdirSync(dir, { withFileTypes: true });
		} catch {
			return;
		}
		for (const entry of entries) {
			const name = entry.name as string;
			const fullPath = join(dir, name);
			if (entry.isDirectory()) {
				if (name === "node_modules" || name === ".git") {
					continue;
				}
				walk(fullPath);
			} else if (entry.isFile()) {
				result.push(relative(cwd, fullPath));
			}
		}
	}

	walk(cwd);
	return result;
}

/**
 * Discovers files matching a glob pattern, grouped by directory.
 * Unmatched files are classified as either GLOB_MISS or GIT_IGNORED.
 */
export async function discover(options: DiscoverOptions): Promise<DiscoverResult> {
	const cwd = options.cwd ?? process.cwd();
	const useGitignore = options.gitignore ?? true;

	const matchedFiles = await globby(options.pattern, {
		cwd,
		gitignore: useGitignore,
		dot: false,
	});

	const matchedSet = new Set(matchedFiles);

	const allFiles = await collectAllFiles(cwd);

	const isIgnored = useGitignore ? await isGitIgnored({ cwd }) : () => false;

	const unmatchedFiles: UnmatchedFile[] = [];
	for (const file of allFiles) {
		if (!matchedSet.has(file)) {
			const fullPath = join(cwd, file);
			const reason = isIgnored(fullPath) ? "GIT_IGNORED" : "GLOB_MISS";
			unmatchedFiles.push({ path: file, reason });
		}
	}

	const allPaths = [...matchedFiles, ...unmatchedFiles.map((u) => u.path)];
	const allDirs = new Set(allPaths.map((f) => dirname(f)));

	const matchedByDir = groupByDirectory(matchedFiles);
	const unmatchedByDir = new Map<string, UnmatchedFile[]>();
	for (const u of unmatchedFiles) {
		const dir = dirname(u.path);
		const existing = unmatchedByDir.get(dir);
		if (existing) {
			existing.push(u);
		} else {
			unmatchedByDir.set(dir, [u]);
		}
	}

	const directories: DirectoryResult[] = [...allDirs].sort().map((dir) => ({
		directory: dir,
		matched: matchedByDir.get(dir) ?? [],
		unmatched: unmatchedByDir.get(dir) ?? [],
	}));

	return { directories };
}
