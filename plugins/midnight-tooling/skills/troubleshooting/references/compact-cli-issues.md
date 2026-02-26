# Compact CLI Installation Issues

Resolve installation and execution problems with the Compact CLI (`compact` / `compactc` commands).

## Shebang Line Corruption

**Symptom:** Running `compact` or `compactc` produces garbled output, unexpected errors, or a "bad interpreter" message.

**Cause:** The `compactc` wrapper script's shebang line (`#!/usr/bin/env bash` or similar) has been corrupted, typically by:
- Line ending conversion (CRLF instead of LF) - common when files pass through Windows or Git with `core.autocrlf=true`
- Encoding issues during download or extraction
- Manual editing that introduced invisible characters

**Fix:**
1. Locate the wrapper script:
   ```bash
   which compactc
   ```
2. Inspect the shebang line:
   ```bash
   head -1 "$(which compactc)" | cat -v
   ```
   Look for `^M` (carriage return) or other non-printable characters.
3. Fix line endings:
   ```bash
   sed -i 's/\r$//' "$(which compactc)"
   ```
   On macOS (BSD sed):
   ```bash
   sed -i '' 's/\r$//' "$(which compactc)"
   ```
4. Verify the fix:
   ```bash
   head -1 "$(which compactc)" | cat -v
   compactc --version
   ```

## Exec Format Error on Linux

**Error:** `exec format error` or `cannot execute binary file`

**Cause:** The binary was downloaded for the wrong CPU architecture (e.g., ARM binary on x86_64 or vice versa).

**Fix:**
1. Check the system architecture:
   ```bash
   uname -m
   ```
   - `x86_64` / `amd64` = Intel/AMD 64-bit
   - `aarch64` / `arm64` = ARM 64-bit
2. Check the binary's architecture:
   ```bash
   file "$(which compact)"
   ```
3. Re-download the correct binary for the detected architecture.
4. If the architecture is correct but the error persists, the binary may be corrupt - re-download.

## PATH Not Updated After Install

**Symptom:** `compact: command not found` immediately after installation.

**Cause:** The installation added the binary to a directory that is not in the current shell's PATH, or the PATH change was added to a shell config file that hasn't been sourced.

**Fix:**
1. Find where the binary was installed:
   ```bash
   find ~/.local/bin /usr/local/bin ~/bin -name "compact*" 2>/dev/null
   ```
2. Check if that directory is in PATH:
   ```bash
   echo $PATH | tr ':' '\n' | grep -i compact
   ```
3. If the directory is not in PATH, **open a new terminal window** (do not just `source ~/.zshrc`).
4. If it's still not found after a new terminal, add the directory to the shell config:
   ```bash
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
   ```
   Then open yet another new terminal.
5. Verify:
   ```bash
   which compact
   compact --version
   ```

## If Issues Persist

1. Search for CLI installation issues: `gh search issues "compact CLI install org:midnightntwrk" --state=open --limit=20 --sort=updated --json "title,url,updatedAt,commentsCount"`
2. Check if the Compact CLI version has known issues via `references/checking-release-notes.md`
3. The compact-cli skill has additional reference material on installation in its `references/installation.md`
