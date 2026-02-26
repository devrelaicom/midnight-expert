# Windows Setup

Resolve Windows-specific setup issues for Midnight Network development.

## Fetch Current Guide

Fetch the latest Windows setup guide from the Midnight docs repository:

```
githubGetFileContent(
  owner: "midnightntwrk",
  repo: "midnight-docs",
  path: "docs/guides/windows-compact-setup.mdx",
  fullContent: true
)
```

Parse the fetched MDX content by stripping frontmatter, JSX imports, and component wrappers. Present the remaining markdown instructions to the user.

## Quick Fixes (if fetch is unavailable)

If the MCP tool is unavailable, try these common resolutions:

- Install WSL 2: `wsl --install` from an elevated PowerShell, then restart
- Run all Midnight tools inside WSL, not native Windows PowerShell/cmd
- Configure git line endings: `git config --global core.autocrlf input`
- Ensure Docker Desktop is installed with WSL 2 backend enabled for the proof server

## Common Windows Issues

- **WSL vs native** - Most Midnight tools are designed for Unix-like environments. WSL (Windows Subsystem for Linux) is typically required for full compatibility.
- **Path separators** - Windows uses backslashes (`\`) while Midnight tooling expects forward slashes (`/`). Running inside WSL avoids this issue.
- **Line endings** - Git on Windows may convert line endings to CRLF, which can corrupt shell scripts. Configure git:
  ```bash
  git config --global core.autocrlf input
  ```
- **Docker Desktop** - Windows requires Docker Desktop with WSL 2 backend for the proof server. Ensure WSL integration is enabled in Docker Desktop settings.
- **File permissions** - WSL may not preserve Unix file permissions correctly depending on the mount configuration. Check `/etc/wsl.conf` for metadata settings.

## If the Guide Does Not Resolve the Issue

1. Search for Windows-related issues: `gh search issues "windows org:midnightntwrk" --state=open --limit=20 --sort=updated --json "title,url,updatedAt,commentsCount"`
2. Also search for WSL-specific issues: `gh search issues "WSL org:midnightntwrk" --state=open --limit=20 --sort=updated --json "title,url,updatedAt,commentsCount"`
