#!/usr/bin/env node
// Vendored template renderer for /compact-cli-dev:init.
//
// Self-contained, zero runtime dependencies (Node's stdlib only) so a fresh
// user never has to install anything. Ported from the former
// @aaronbassett/template-engine package (packages/template-engine).
//
// Reads a single JSON job from stdin:
//   {"template": "<dir>", "output": "<dir>", "context": {"KEY": "value", ...}}
//
// Copies the template directory to the output directory, substituting
// {{KEY}} placeholders in text files and stripping the .tmpl extension from
// rendered filenames. Binary files are copied byte-for-byte.
//
// On success prints {"output": "<abs path>", "files": <count>} to stdout.
// On failure prints {"error": "<message>"} to stderr and exits 1.

import fs from "node:fs";
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

function isBinaryPath(filePath) {
	return BINARY_EXTENSIONS.has(path.extname(filePath).toLowerCase());
}

function substitute(content, context) {
	let result = content;
	for (const [key, value] of Object.entries(context)) {
		result = result.replaceAll(`{{${key}}}`, value);
	}
	return result;
}

function copyRecursive(src, dest, context) {
	let fileCount = 0;
	const entries = fs.readdirSync(src, { withFileTypes: true });

	for (const entry of entries) {
		const srcPath = path.join(src, entry.name);

		// Determine output filename — strip .tmpl extension
		const outputName = entry.name.endsWith(".tmpl") ? entry.name.slice(0, -5) : entry.name;
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

function processTemplate(input) {
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

	return { output: outputDir, files: fileCount };
}

function readStdin() {
	return new Promise((resolve, reject) => {
		const chunks = [];
		process.stdin.setEncoding("utf-8");
		process.stdin.on("data", (chunk) => chunks.push(chunk));
		process.stdin.on("end", () => resolve(chunks.join("")));
		process.stdin.on("error", reject);
	});
}

function isValidInput(value) {
	if (typeof value !== "object" || value === null) return false;
	return (
		typeof value.template === "string" &&
		typeof value.output === "string" &&
		typeof value.context === "object" &&
		value.context !== null
	);
}

async function main() {
	let raw;
	try {
		raw = await readStdin();
	} catch {
		process.stderr.write(`${JSON.stringify({ error: "Failed to read stdin" })}\n`);
		process.exit(1);
	}

	let input;
	try {
		const parsed = JSON.parse(raw);
		if (!isValidInput(parsed)) {
			throw new Error(
				'Invalid input. Expected {"template": string, "output": string, "context": {...}}',
			);
		}
		input = parsed;
	} catch (err) {
		const message = err instanceof Error ? err.message : "Invalid JSON input";
		process.stderr.write(`${JSON.stringify({ error: message })}\n`);
		process.exit(1);
	}

	try {
		const result = processTemplate(input);
		process.stdout.write(`${JSON.stringify(result)}\n`);
	} catch (err) {
		const message = err instanceof Error ? err.message : "Template processing failed";
		process.stderr.write(`${JSON.stringify({ error: message })}\n`);
		process.exit(1);
	}
}

main();
