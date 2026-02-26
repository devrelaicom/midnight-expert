# Searching for Current Issues

Search open GitHub issues in the midnightntwrk organization to find known problems, workarounds, and ongoing discussions relevant to the current issue.

## Principles

- **Minimize context consumption** - always use JSON output and request only the fields needed for the current step
- **Two-phase approach** - first search for potentially relevant issues (minimal fields), then fetch full details only for confirmed relevant issues
- **Keywords before org** - in the search query string, place keywords before `org:midnightntwrk`

## Phase 1: Search for Issues

### Basic Search (all open issues, recent first)

```bash
gh search issues "org:midnightntwrk" --state=open --limit=50 --sort=updated --json "title,labels,updatedAt,commentsCount,url"
```

### Keyword Search (narrow to relevant issues)

Add keywords before the org filter. Use the exact error message or key terms from the user's problem:

```bash
gh search issues "<keywords> org:midnightntwrk" --state=open --limit=50 --sort=updated --json "title,labels,updatedAt,commentsCount,url"
```

Examples:
```bash
gh search issues "version mismatch org:midnightntwrk" --state=open --limit=50 --sort=updated --json "title,labels,updatedAt,commentsCount,url"
gh search issues "proof server org:midnightntwrk" --state=open --limit=50 --sort=updated --json "title,labels,updatedAt,commentsCount,url"
gh search issues "ERR_UNSUPPORTED_DIR_IMPORT org:midnightntwrk" --state=open --limit=10 --sort=updated --json "title,url"
```

### Available Search Fields

> assignees, author, authorAssociation, body, closedAt, commentsCount, createdAt, id, isLocked, isPullRequest, labels, number, repository, state, title, updatedAt, url

### Field Selection Guidance

When searching with `--state=open`:
- **Omit** `state` (always "open") and `closedAt` (always empty)
- **Omit** `number` and `repository` if `url` is included (URL contains both)
- **Omit** `author` and `assignees` unless specifically investigating who filed/owns the issue
- **Omit** `body` in search results - fetch it separately for relevant issues only

Recommended minimal field set for initial search:
```
--json "title,url,updatedAt,commentsCount"
```

Add `labels` only when label-based filtering is useful for triage.

## Phase 2: View Relevant Issues

Once a relevant issue is identified from the search results, fetch its details using the URL:

### View Issue Body

```bash
gh issue view <url> --json "body"
```

Do **not** re-fetch fields already obtained from the search (title, url, labels, updatedAt).

### View Issue Comments

Only fetch comments after confirming the issue is relevant, and only if the comment count suggests useful discussion:

```bash
gh issue view <url> --json "comments"
```

### Available View Fields

> assignees, author, body, closed, closedAt, closedByPullRequestsReferences, comments, createdAt, id, isPinned, labels, milestone, number, projectCards, projectItems, reactionGroups, state, stateReason, title, updatedAt, url

## Search Strategies

### For Error Messages

Use the exact error message (or a distinctive substring) as the keyword:
```bash
gh search issues "public parameters for k=16 not found org:midnightntwrk" --state=open --limit=10 --sort=updated --json "title,url"
```

### For Component-Specific Issues

Include the component name:
```bash
gh search issues "compact CLI org:midnightntwrk" --state=open --limit=20 --sort=updated --json "title,url,updatedAt,commentsCount"
```

### For Version-Specific Issues

Include the version number:
```bash
gh search issues "1.2.3 org:midnightntwrk" --state=open --limit=20 --sort=updated --json "title,url,updatedAt"
```

### Broadening a Failed Search

If a specific search returns no results:
1. Remove version numbers
2. Use shorter / more generic keywords
3. Try synonyms (e.g., "wallet" vs "Lace", "node" vs "ledger")
4. Search without `--state=open` to include closed issues that may have solutions
