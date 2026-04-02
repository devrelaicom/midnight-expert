---
name: midnight-tooling:install-statusline-script
description: Install, update, or uninstall the Midnight statusline script. Displays proof server and Compact CLI status in the Claude Code status bar.
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion, Skill
argument-hint: "[--update | --uninstall | --theme <name> | --style <name>]"
---

Install the Midnight statusline script, which shows proof server and Compact CLI status in the Claude Code status bar. The script chains with any existing statusLine configuration rather than replacing it.

## Step 1: Parse Arguments

Analyze `$ARGUMENTS` to determine intent:

- **`--uninstall`**: Remove the installed script and restore original statusLine. Jump to Step 6.
- **`--update`**: Re-copy the script from the plugin source (preserves chain.conf). Proceed from Step 3.
- **`--theme <name>`**: Set the default theme. Valid themes: dark, light, neutral, tokyo, miami, marrakech (default), reykjavik, cartagena, berlin. Note the preference for Step 5.
- **`--style <name>`**: Set the default style. Valid styles: minimal, powerline (default), capsule. Note the preference for Step 5.
- **No arguments**: Fresh install. Proceed from Step 2.

## Step 2: Check Prerequisites

Check for recommended tools. Warn but do not block installation if missing:

```bash
command -v jq >/dev/null 2>&1 && echo "jq: found" || echo "jq: not found (statusline will use fallback parsing)"
command -v curl >/dev/null 2>&1 && echo "curl: found" || echo "curl: not found (proof server status will show as off)"
command -v docker >/dev/null 2>&1 && echo "docker: found" || echo "docker: not found (cannot detect proof server on alternate ports)"
```

Report findings but proceed regardless.

## Step 3: Copy Script to Installation Directory

1. Create the installation directory:

```bash
mkdir -p "$HOME/.midnight-expert/statusLine"
```

2. Locate the plugin source script. The script is at `${CLAUDE_PLUGIN_ROOT}/scripts/sl.sh` relative to the plugin root. If `CLAUDE_PLUGIN_ROOT` is not set or the file is not found there, use the `midnight-plugin-utils:find-claude-plugin-root` skill to locate the `midnight-tooling` plugin root, then use `scripts/sl.sh` from that path.

3. Copy the script:

```bash
cp "$PLUGIN_ROOT/scripts/sl.sh" "$HOME/.midnight-expert/statusLine/sl.sh"
chmod +x "$HOME/.midnight-expert/statusLine/sl.sh"
```

Where `$PLUGIN_ROOT` is the resolved plugin root from the previous step.

4. Verify the copy:

```bash
test -x "$HOME/.midnight-expert/statusLine/sl.sh" && echo "Script installed successfully" || echo "ERROR: Script not found or not executable"
```

## Step 4: Detect and Preserve Existing StatusLine

Check settings files in precedence order for an existing `statusLine` configuration:

1. `.claude/settings.local.json` (project-local)
2. `.claude/settings.json` (project)
3. `~/.claude/settings.json` (user global)

For each file, check if it contains a `statusLine` key:

```bash
for f in ".claude/settings.local.json" ".claude/settings.json" "$HOME/.claude/settings.json"; do
  if [ -f "$f" ]; then
    if grep -q '"statusLine"' "$f" 2>/dev/null; then
      echo "Found statusLine in: $f"
    fi
  fi
done
```

**If an existing statusLine command is found at higher precedence than the plugin's `settings.json`:**

The plugin's `settings.json` sets `statusLine` at plugin scope, but a user's setting in `.claude/settings.local.json`, `.claude/settings.json`, or `~/.claude/settings.json` will take precedence and override it. This means our script won't run automatically.

1. Extract the existing command. Use `jq` if available, otherwise `grep`/`sed`:

```bash
jq -r '.statusLine.command // empty' "$SETTINGS_FILE" 2>/dev/null
```

2. Check if the existing command already references our script (recursion guard):
   - If it contains `midnight-expert/statusLine` or both `midnight-tooling` and `sl.sh`, it's already configured. Report this and skip.

3. Save the existing command to `chain.conf` so our script can chain it:

```bash
echo "$EXISTING_COMMAND" > "$HOME/.midnight-expert/statusLine/chain.conf"
```

4. Use AskUserQuestion to ask the user whether they want to update their settings file to point to our script. Explain that:
   - Their current statusLine command will be preserved and chained (it runs first, then our Midnight status appears after)
   - The original command is saved in `~/.midnight-expert/statusLine/chain.conf`
   - They can restore it at any time with `--uninstall`

5. If the user agrees, update their settings file to point to our script:
   - Read the current file content
   - Replace the `statusLine` command value with: `bash -c 'exec "$HOME/.midnight-expert/statusLine/sl.sh"'`
   - Write the updated file using Edit (to preserve other settings)

**If no existing statusLine is found at higher precedence:**

The plugin's `settings.json` will be used automatically. No changes needed. Inform the user that the statusline is active via the plugin settings.

## Step 5: Configure Theme and Style

If `--theme` or `--style` was provided in the arguments:

Explain to the user that themes and styles are configured via environment variables. Offer to set them in their Claude Code settings:

- `MIDNIGHT_TOOLING_STATUSLINE_THEME` for theme
- `MIDNIGHT_TOOLING_STATUSLINE_STYLE` for style

Check if `.claude/settings.json` or `.claude/settings.local.json` exists and has an `env` section. Offer to add the env vars there:

```json
{
  "env": {
    "MIDNIGHT_TOOLING_STATUSLINE_THEME": "<theme>",
    "MIDNIGHT_TOOLING_STATUSLINE_STYLE": "<style>"
  }
}
```

Use AskUserQuestion to confirm before modifying settings files.

## Step 6: Uninstall (if `--uninstall`)

1. Check if `chain.conf` exists and has content:

```bash
if [ -f "$HOME/.midnight-expert/statusLine/chain.conf" ]; then
  ORIGINAL_CMD="$(cat "$HOME/.midnight-expert/statusLine/chain.conf")"
  echo "Original statusLine command: $ORIGINAL_CMD"
fi
```

2. If an original command was saved, offer to restore it in the user's settings file.

3. Remove the installed files:

```bash
rm -rf "$HOME/.midnight-expert/statusLine"
```

4. Clean up any cache files:

```bash
rm -f /tmp/midnight-sl-* /tmp/midnight-detect-* /tmp/midnight-compact-check-*
```

5. Inform the user that the plugin's `settings.json` still references the script. Since the script no longer exists, the statusline will show the "run install" message. This is expected — the user can re-install at any time.

## Step 7: Report Success

Present a summary of what was done:

- Script location: `~/.midnight-expert/statusLine/sl.sh`
- Chained command: (the original statusLine command, if any, or "none")
- Theme: (configured theme or "marrakech (default)")
- Style: (configured style or "powerline (default)")
- Settings file updated: (which file, if any)

Remind the user to **restart Claude Code** for the statusline to take effect.

Available themes: dark, light, neutral, tokyo, miami, marrakech, reykjavik, cartagena, berlin

Available styles: minimal, powerline, capsule

Environment variables:
- `MIDNIGHT_TOOLING_STATUSLINE_THEME` — override theme
- `MIDNIGHT_TOOLING_STATUSLINE_STYLE` — override style
- `MIDNIGHT_TOOLING_STATUSLINE_ACTIVE=1` — force statusline to show (skip project detection)
