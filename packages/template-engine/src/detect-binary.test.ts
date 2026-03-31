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
