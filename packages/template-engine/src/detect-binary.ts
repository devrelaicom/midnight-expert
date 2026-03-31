import path from "node:path";

const BINARY_EXTENSIONS = new Set([
	// Images
	".png",
	".jpg",
	".jpeg",
	".gif",
	".bmp",
	".webp",
	".ico",
	".tiff",
	".tif",
	// Fonts
	".woff",
	".woff2",
	".ttf",
	".eot",
	".otf",
	// Archives
	".zip",
	".tar",
	".gz",
	".bz2",
	".7z",
	".rar",
	// Compiled / binary
	".wasm",
	".exe",
	".dll",
	".so",
	".dylib",
	".o",
	".a",
	// Media
	".mp3",
	".mp4",
	".avi",
	".mov",
	".flv",
	".ogg",
	".wav",
	// Documents
	".pdf",
	".doc",
	".docx",
	".xls",
	".xlsx",
	".ppt",
	".pptx",
	// Database
	".sqlite",
	".db",
]);

export function isBinaryPath(filePath: string): boolean {
	const ext = path.extname(filePath).toLowerCase();
	return BINARY_EXTENSIONS.has(ext);
}
