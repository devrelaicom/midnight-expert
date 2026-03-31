/** A claim object with a required id field and arbitrary nested data */
export interface Claim {
	readonly id: string;
	readonly [key: string]: unknown;
}

/** Mode for the merge operation */
export type MergeMode = "concat" | "update";

/** Options for the merge command */
export interface MergeOptions {
	/** Path to the original JSON file (used in update mode) */
	readonly original?: string | undefined;
	/** Paths to the agent-copy JSON files */
	readonly inputs: readonly string[];
	/** Path to the output file */
	readonly output: string;
	/** Merge mode */
	readonly mode: MergeMode;
}

/** Successful merge result */
export interface MergeSuccess {
	readonly ok: true;
	readonly claimCount: number;
	readonly outputPath: string;
}

/** Failed merge result */
export interface MergeFailure {
	readonly ok: false;
	readonly error: string;
}

/** Result of a merge operation */
export type MergeResult = MergeSuccess | MergeFailure;
