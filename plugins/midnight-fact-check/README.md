# midnight-fact-check

Fact-checking pipeline for Midnight content. Extracts testable claims from any source, classifies them by domain, verifies each claim using the [midnight-verify](../midnight-verify/) framework, and produces a structured report.

## Usage

```
/midnight-fact-check:check <target> [<target2> ...]
```

### Supported Inputs

| Input | Example |
|-------|---------|
| Local file | `/midnight-fact-check:check ./skills/compact-language-ref/SKILL.md` |
| Directory | `/midnight-fact-check:check ./plugins/compact-core/` |
| Plugin directory | `/midnight-fact-check:check ./plugins/compact-core/` (auto-detected via plugin.json) |
| URL(s) | `/midnight-fact-check:check https://docs.midnight.network/develop/tutorial/building` |
| GitHub file | `/midnight-fact-check:check https://github.com/user/repo/blob/main/README.md` |
| GitHub directory | `/midnight-fact-check:check https://github.com/user/repo/tree/main/docs/` |
| Glob pattern | `/midnight-fact-check:check "./plugins/*/skills/**/*.md"` |

### Pipeline

1. **Preflight** — Verifies midnight-verify plugin is installed
2. **Input Resolution** — Resolves targets to readable content
3. **Extraction** — Parallel agents extract testable claims
4. **Classification** — Domain-specialist agents tag claims (compact, sdk, zkir, witness)
5. **Verification** — Batched parallel agents verify claims via `/verify`
6. **Report** — Markdown report + terminal summary
7. **GitHub Issues** — Optional issue creation for refuted claims (GitHub sources only)

### Run Artifacts

Each run produces a directory under `.midnight-expert/fact-checker/`:

```
.midnight-expert/fact-checker/03-26/compact-core-plugin-a3Kf/
├── run-metadata.json
├── resolved-content.json
├── extracted-claims.json
├── classified-claims.json
├── verification-results.json
└── report.md
```

## Dependencies

- **midnight-verify** plugin (required — checked at preflight)
- **@aaronbassett/midnight-fact-checker-utils** npm package (used via npx)
- **gh** CLI (optional — for GitHub issue creation)
