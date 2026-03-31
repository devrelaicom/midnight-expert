/** Result of extracting content from a single URL */
export interface ExtractedContent {
	readonly url: string;
	readonly title: string;
	readonly markdown: string;
}

/** Result when extraction fails for a URL */
export interface ExtractionError {
	readonly url: string;
	readonly error: string;
}

/** Combined result of extracting content from multiple URLs */
export interface ExtractUrlResult {
	readonly successes: readonly ExtractedContent[];
	readonly failures: readonly ExtractionError[];
}
