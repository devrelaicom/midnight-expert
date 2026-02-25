---
name: midnight-plugin-utils:find-claude-plugin-root
description: This skill should be used when the user needs to locate a plugin's installation path, find where a plugin is installed, resolve plugin root directory, or when CLAUDE_PLUGIN_ROOT does not expand in markdown files. It generates a Python resolver script at /tmp/cpr.py that reads installed_plugins.json and supports fuzzy plugin name matching.
version: 0.1.0
---

# Find Claude Plugin Root

To resolve a plugin's installation path, invoke this skill to generate a Python resolver script at `/tmp/cpr.py`. The script reads `~/.claude/plugins/installed_plugins.json` to locate the plugin directory.

## Problem It Solves

`${CLAUDE_PLUGIN_ROOT}` environment variable doesn't expand in markdown command files, making it impossible to reference plugin scripts and resources. This is a known issue: https://github.com/anthropics/claude-code/issues/9354

## Solution

To locate a plugin's installation directory, generate a Python script that:
1. Accepts a plugin name as argument (with optional `--verbose` flag)
2. Checks `${CLAUDE_PLUGIN_ROOT}` first (backwards compatible)
3. Reads installed_plugins.json and searches for a substring match
4. If no substring match, finds similar plugin names via fuzzy matching
5. Outputs the plugin installation path to stdout
6. Saves to `/tmp/cpr.py` (ephemeral, no project pollution)

## Usage

Invoke this skill before executing plugin scripts:

```bash
# Generate the resolver
Skill(skill="midnight-plugin-utils:find-claude-plugin-root")

# Use it to find a plugin and execute its scripts
PLUGIN_ROOT=$(python3 /tmp/cpr.py readme-and-co) || {
    echo "Plugin resolution failed." >&2; exit 1
}
python "$PLUGIN_ROOT/scripts/populate_license.py" --license MIT
```

## Implementation

### Step 1: Create the resolver Python script

```bash
cat > /tmp/cpr.py << 'CPREOF'
#!/usr/bin/env python3
"""
Claude Plugin Root (CPR) Resolver

Usage: python3 /tmp/cpr.py [--verbose] <plugin-name>
Returns: absolute path to plugin installation directory

Searches for plugins in ~/.claude/plugins/installed_plugins.json with fuzzy matching.
"""

import json
import os
import sys
from pathlib import Path
from difflib import SequenceMatcher


def similarity(a, b):
    """Calculate similarity ratio between two strings."""
    return SequenceMatcher(None, a.lower(), b.lower()).ratio()


def get_install_path(value):
    """Extract installPath from a plugin entry (handles list or dict)."""
    if isinstance(value, list) and len(value) > 0:
        value = value[0]
    return value.get('installPath', '').rstrip('/')


def find_plugin_root(plugin_name, verbose=False):
    """
    Find plugin installation directory.

    Returns: (plugin_root_path, match_type, match_detail)
        match_type: 'env_var', 'substring', 'fuzzy', or None
        match_detail: additional info about the match (e.g. similarity score)
    """
    # Try CLAUDE_PLUGIN_ROOT first (backwards compatible)
    env_root = os.environ.get('CLAUDE_PLUGIN_ROOT')
    if env_root and os.path.isdir(env_root):
        if verbose:
            print(f"[verbose] Matched via CLAUDE_PLUGIN_ROOT env var: {env_root}", file=sys.stderr)
        return env_root.rstrip('/'), 'env_var', None

    # Read installed_plugins.json
    plugins_file = Path.home() / '.claude' / 'plugins' / 'installed_plugins.json'

    if not plugins_file.exists():
        if verbose:
            print(f"[verbose] Plugins file not found: {plugins_file}", file=sys.stderr)
        return None, None, None

    try:
        with open(plugins_file, 'r') as f:
            data = json.load(f)
            plugins = data.get('plugins', {})
    except (OSError, json.JSONDecodeError) as e:
        if verbose:
            print(f"[verbose] Failed to read plugins file: {e}", file=sys.stderr)
        return None, None, None

    if verbose:
        print(f"[verbose] Found {len(plugins)} plugin(s) in {plugins_file}", file=sys.stderr)

    # Try substring match first (case-insensitive)
    for key, value in plugins.items():
        if plugin_name.lower() in key.lower():
            install_path = get_install_path(value)
            if install_path and os.path.isdir(install_path):
                if verbose:
                    print(f"[verbose] Substring match: '{plugin_name}' found in key '{key}'", file=sys.stderr)
                return install_path, 'substring', key

    # Try fuzzy matching if no substring match
    matches = []
    for key, value in plugins.items():
        # Extract just the plugin name from key (e.g., "owner/plugin-name" -> "plugin-name")
        key_parts = key.split('/')
        plugin_part = key_parts[-1] if key_parts else key
        # Also handle @ separator (e.g., "plugin-name@plugin-name")
        plugin_part = plugin_part.split('@')[0]

        ratio = similarity(plugin_name, plugin_part)
        if verbose:
            print(f"[verbose] Fuzzy: '{plugin_name}' vs '{plugin_part}' (from '{key}'): similarity={ratio:.2f}", file=sys.stderr)
        if ratio > 0.6:  # 60% similarity threshold
            install_path = get_install_path(value)
            if install_path and os.path.isdir(install_path):
                matches.append((ratio, install_path, key))

    if matches:
        matches.sort(reverse=True, key=lambda x: x[0])
        best_match = matches[0]
        if verbose:
            print(f"[verbose] Best fuzzy match: '{best_match[2]}' (similarity={best_match[0]:.2f})", file=sys.stderr)
        return best_match[1], 'fuzzy', f"{best_match[2]} (similarity={best_match[0]:.2f})"

    return None, None, None


def main():
    args = sys.argv[1:]
    verbose = False

    if '--verbose' in args:
        verbose = True
        args.remove('--verbose')

    if not args:
        print("Usage: python3 /tmp/cpr.py [--verbose] <plugin-name>", file=sys.stderr)
        print("Example: python3 /tmp/cpr.py readme-and-co", file=sys.stderr)
        print("         python3 /tmp/cpr.py --verbose readme-and-co", file=sys.stderr)
        sys.exit(1)

    plugin_name = args[0]
    plugin_root, match_type, match_detail = find_plugin_root(plugin_name, verbose=verbose)

    if plugin_root:
        if verbose:
            print(f"[verbose] Resolved via {match_type}: {plugin_root}", file=sys.stderr)
        # Output just the path to stdout (for command substitution)
        print(plugin_root)
        sys.exit(0)
    else:
        print(f"Error: Could not locate plugin '{plugin_name}'", file=sys.stderr)
        print(f"Checked: $CLAUDE_PLUGIN_ROOT, ~/.claude/plugins/installed_plugins.json", file=sys.stderr)
        if verbose:
            print("[verbose] Try --verbose with a broader name, or check installed_plugins.json manually", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
CPREOF

chmod +x /tmp/cpr.py
```

### Step 2: Verify the script works

```bash
# Test finding the midnight-plugin-utils plugin itself
if PLUGIN_ROOT=$(python3 /tmp/cpr.py midnight-plugin-utils); then
  echo "Resolver created at /tmp/cpr.py"
  echo "Test lookup succeeded: $PLUGIN_ROOT"
else
  echo "Resolver test failed" >&2
  exit 1
fi
```

## Examples

### Find and use readme-and-co plugin

```bash
# Invoke this skill first, then use the resolver
Skill(skill="midnight-plugin-utils:find-claude-plugin-root")

PLUGIN_ROOT=$(python3 /tmp/cpr.py readme-and-co) || {
    echo "Failed to resolve readme-and-co plugin." >&2; exit 1
}
python "$PLUGIN_ROOT/scripts/detect_project_info.py"
```

### Find and use any plugin

```bash
# Resolve any installed plugin by name
PLUGIN_ROOT=$(python3 /tmp/cpr.py my-plugin) || {
    echo "Failed to resolve my-plugin." >&2; exit 1
}
node "$PLUGIN_ROOT/tools/analyzer.js"
```

### Debug resolution with verbose output

```bash
# Use --verbose to see match type and similarity scores on stderr
PLUGIN_ROOT=$(python3 /tmp/cpr.py --verbose readme-and-co)
```

## Benefits

- **No project pollution** -- script saved to /tmp, not in project
- **Backwards compatible** -- checks ${CLAUDE_PLUGIN_ROOT} first
- **Fuzzy matching** -- finds plugins even with approximate names
- **Verbose mode** -- use `--verbose` to inspect match type and similarity scores
- **Pure Python** -- no external dependencies (jq not needed)
- **Reusable** -- one skill resolves any installed plugin
- **Ephemeral** -- /tmp/cpr.py cleaned up on reboot

## Limitations

- Recreated on each system reboot (since /tmp is ephemeral)
- Requires Python 3 (standard on all modern systems)
