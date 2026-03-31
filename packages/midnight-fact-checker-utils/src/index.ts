/** Library exports for programmatic usage */
export { discover } from "./commands/discover.js";
export {
	extractUrls,
	extractSingleUrl,
	extractReadableContent,
	htmlToMarkdown,
} from "./commands/extract-url.js";
export { merge, mergeConcat, mergeUpdate, deepMerge } from "./commands/merge.js";
export type {
	DiscoverOptions,
	DiscoverResult,
	DirectoryResult,
	UnmatchedFile,
	UnmatchedReason,
	ExtractedContent,
	ExtractionError,
	ExtractUrlResult,
	Claim,
	MergeMode,
	MergeOptions,
	MergeResult,
	MergeSuccess,
	MergeFailure,
} from "./types/index.js";
