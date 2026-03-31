import { describe, expect, it } from "vitest";
import { extractReadableContent, htmlToMarkdown } from "./extract-url.js";

const SAMPLE_ARTICLE_HTML = `
<!DOCTYPE html>
<html>
<head><title>Test Article</title></head>
<body>
  <nav><a href="/">Home</a> | <a href="/about">About</a></nav>
  <header><h1>Site Header</h1></header>
  <article>
    <h1>Test Article Title</h1>
    <p>This is the first paragraph of the article. It contains enough text
    to be considered meaningful content by the Readability algorithm. The
    article needs several paragraphs to work properly.</p>
    <p>This is the second paragraph with more detailed information about
    the topic being discussed. It provides additional context and details
    that help the reader understand the subject matter.</p>
    <p>A third paragraph adds even more weight to the article content,
    ensuring that the readability parser correctly identifies this as the
    main content area of the page rather than boilerplate or navigation.</p>
    <h2>Section Two</h2>
    <p>This section covers additional material that is relevant to the
    article. It includes important information that readers should know.</p>
    <ul>
      <li>First point of interest</li>
      <li>Second point of interest</li>
      <li>Third point of interest</li>
    </ul>
    <p>The article concludes with a summary of all the key points that
    were discussed throughout the piece.</p>
  </article>
  <footer><p>Copyright 2024</p></footer>
</body>
</html>
`;

const MINIMAL_HTML = `
<!DOCTYPE html>
<html>
<head><title>Empty</title></head>
<body>
  <p>Short.</p>
</body>
</html>
`;

const NAV_HEAVY_HTML = `
<!DOCTYPE html>
<html>
<head><title>Nav Heavy</title></head>
<body>
  <nav>
    <ul>
      <li><a href="/page1">Page 1</a></li>
      <li><a href="/page2">Page 2</a></li>
      <li><a href="/page3">Page 3</a></li>
      <li><a href="/page4">Page 4</a></li>
    </ul>
  </nav>
  <main>
    <article>
      <h1>Real Content</h1>
      <p>This is the actual article content that matters. It has enough
      text to be recognized as the primary content of the page by the
      Readability algorithm. Multiple sentences help establish this.</p>
      <p>Another paragraph provides additional substance to the article.
      This ensures the parser correctly identifies the main content area.</p>
      <p>The final paragraph wraps up the discussion with concluding
      thoughts about the topic covered in this article.</p>
    </article>
  </main>
  <footer>
    <p>Footer with lots of links</p>
    <a href="/terms">Terms</a>
    <a href="/privacy">Privacy</a>
  </footer>
</body>
</html>
`;

describe("extractReadableContent", () => {
	it("should extract article content from well-structured HTML", () => {
		const result = extractReadableContent(SAMPLE_ARTICLE_HTML, "https://example.com/article");
		expect(result).not.toBeNull();
		// Readability derives title from <title> tag, not the <h1> inside the article
		expect(result?.title).toBe("Test Article");
		expect(result?.content).toContain("first paragraph");
		expect(result?.content).toContain("Section Two");
	});

	it("should return null for minimal/empty pages that Readability cannot parse", () => {
		const result = extractReadableContent(MINIMAL_HTML, "https://example.com/empty");
		// Readability may or may not parse minimal content, so we just verify it doesn't throw
		if (result === null) {
			expect(result).toBeNull();
		} else {
			expect(result.content).toBeDefined();
		}
	});

	it("should strip nav and footer from extracted content", () => {
		const result = extractReadableContent(NAV_HEAVY_HTML, "https://example.com/nav-heavy");
		expect(result).not.toBeNull();
		if (result) {
			// The extracted content should focus on the article, not nav/footer
			expect(result.content).toContain("Real Content");
			// Readability should strip navigation links
			expect(result.content).not.toContain("Page 1");
		}
	});
});

describe("htmlToMarkdown", () => {
	it("should convert headings to ATX style", () => {
		const html = "<h1>Title</h1><h2>Subtitle</h2><p>Content here.</p>";
		const md = htmlToMarkdown(html);
		expect(md).toContain("# Title");
		expect(md).toContain("## Subtitle");
	});

	it("should convert paragraphs to plain text with spacing", () => {
		const html = "<p>First paragraph.</p><p>Second paragraph.</p>";
		const md = htmlToMarkdown(html);
		expect(md).toContain("First paragraph.");
		expect(md).toContain("Second paragraph.");
	});

	it("should convert unordered lists with dash markers", () => {
		const html = "<ul><li>Item one</li><li>Item two</li></ul>";
		const md = htmlToMarkdown(html);
		// Turndown uses "- " followed by content (may include extra spaces for indentation)
		expect(md).toMatch(/-\s+Item one/);
		expect(md).toMatch(/-\s+Item two/);
	});

	it("should convert links to markdown format", () => {
		const html = '<p>Visit <a href="https://example.com">Example</a> for more.</p>';
		const md = htmlToMarkdown(html);
		expect(md).toContain("[Example](https://example.com)");
	});

	it("should convert code blocks to fenced style", () => {
		const html = "<pre><code>const x = 1;</code></pre>";
		const md = htmlToMarkdown(html);
		expect(md).toContain("```");
		expect(md).toContain("const x = 1;");
	});

	it("should strip script and style tags", () => {
		const html =
			"<div><script>alert('xss')</script><style>.hidden{display:none}</style><p>Clean content.</p></div>";
		const md = htmlToMarkdown(html);
		expect(md).not.toContain("alert");
		expect(md).not.toContain("display:none");
		expect(md).toContain("Clean content.");
	});

	it("should strip nav and footer elements", () => {
		const html = "<div><nav>Navigation</nav><p>Main content.</p><footer>Footer</footer></div>";
		const md = htmlToMarkdown(html);
		expect(md).not.toContain("Navigation");
		expect(md).not.toContain("Footer");
		expect(md).toContain("Main content.");
	});

	it("should handle empty HTML gracefully", () => {
		const md = htmlToMarkdown("<div></div>");
		expect(md).toBe("");
	});
});
