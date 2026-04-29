# README Placement Heuristic

The skill inserts the EC attribution sentence as a GitHub `> [!NOTE]` alert near the top of `README.md`. "Near the top" is judgement-based — different projects structure their READMEs differently — so `scripts/check-readme.sh` returns one of three placement decisions:

- `"after-title-block"` — there is a clear title block at the top of the file; insert immediately after it.
- `"top-of-file"` — the file has no recognisable title block; insert at the very top.
- `"ambiguous"` — the file structure is unusual (multiple H1s, mostly HTML, or weird mixed content) and the SKILL should ask the user where to insert.

## Title-block detection

The "title block" starts at line 1 (or the first non-blank line) and ends at the first line that doesn't fit one of these patterns:

- `# ...` (the H1 title)
- Blank lines
- Badge lines: starting with `[![`, `<a href=`, `<img`, or `<p align="center">`/`</p>`
- Centered banner blocks: `<p align="center">...</p>` spanning multiple lines (everything between the opening `<p` and closing `</p>` counts as title block)
- A single short tagline paragraph (≤ 200 chars, no list markers, no headings, immediately following the H1)

The title block ends at:

- The first H2 (`## ...`)
- The first prose paragraph after the title/tagline (a paragraph longer than 200 chars, or a paragraph after the tagline has already been counted)
- The first list (`- ` or `* ` or `1. `)
- The first horizontal rule (`---`)

## Decision tree

```
1. README.md missing or empty?
   → placement: "top-of-file" (skill creates the file or inserts at line 1)

2. Find first H1 (line starting with `# `):
   - Found exactly one?
     → Find title-block end per rules above
     → placement: "after-title-block", insert at title_block_end_line + 1

   - Found more than one?
     → placement: "ambiguous" (the SKILL asks the user)

   - Found none?
     → Continue to step 3

3. Find an HTML banner at top (`<p align="center">` or `<div align="center">` containing an `<img`):
   - Found?
     → placement: "after-title-block", insert after closing `</p>` / `</div>`

   - Not found?
     → placement: "top-of-file", insert at line 1
```

## Worked examples

### Standard markdown README

```
# My Project

[![CI](https://...)](https://...)
[![License](https://...)](https://...)

A short tagline that describes the project in one sentence.

## Installation
...
```

`first_h1_line: 1`, `title_block_end_line: 5`, `first_h2_line: 7`, `placement: "after-title-block"`. Insert at line 6 (between the tagline and `## Installation`).

### Banner-only README (common in OSS)

```
<p align="center">
  <img src="logo.png" width="200" />
</p>

<p align="center">
  Short marketing description.
</p>

## What is this?
...
```

No H1 found, banner detected. `placement: "after-title-block"`, insert after the closing `</p>` of the second centered block.

### Plain-prose README with no title

```
This is a small utility for X. It does Y by Z.

To install, run npm install.
```

No H1, no banner. `placement: "top-of-file"`, insert at line 1 (pushing existing content down).

### Empty or missing README

`placement: "top-of-file"`, insert at line 1. If the file doesn't exist, create it containing only the alert.

### Multi-H1 README (ambiguous)

```
# Project A

...

# Project B
```

Two H1s — could be a multi-project monorepo README or a typo. `placement: "ambiguous"`. The SKILL asks the user to pick a location.

## Insertion format

Always exactly:

```markdown
> [!NOTE]
> {sentence}
```

With a blank line **before** and **after** the alert. If the insertion point is line 1 of a non-empty file, prepend a trailing blank line so existing content has separation. If the file is empty, write only the alert plus a trailing newline.
