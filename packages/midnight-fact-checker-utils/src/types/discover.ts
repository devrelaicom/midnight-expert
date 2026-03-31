/** Reason why a file was not matched by the discovery process */
export type UnmatchedReason = "GLOB_MISS" | "GIT_IGNORED";

/** A file that was not matched, with the reason for exclusion */
export interface UnmatchedFile {
	readonly path: string;
	readonly reason: UnmatchedReason;
}

/** Discovery results for a single directory */
export interface DirectoryResult {
	readonly directory: string;
	readonly matched: readonly string[];
	readonly unmatched: readonly UnmatchedFile[];
}

/** Top-level discovery output */
export interface DiscoverResult {
	readonly directories: readonly DirectoryResult[];
}

/** Options for the discover command */
export interface DiscoverOptions {
	/** Glob pattern to match files against */
	readonly pattern: string;
	/** Base directory to search from (defaults to cwd) */
	readonly cwd?: string;
	/** Whether to respect .gitignore files (defaults to true) */
	readonly gitignore?: boolean;
}
