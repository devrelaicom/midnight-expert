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

function copyRecursive(src: string, dest: string, context: Record<string, string>): number {
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
