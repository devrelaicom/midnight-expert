#!/usr/bin/env python3
"""
Dependency Scanner for Claude Plugins

This script scans plugins for dependency patterns by analyzing markdown files,
JSON configs, Python scripts, and shell scripts. It identifies references to
skills, agents, system commands, tools, and other plugins.

Pattern types detected:
- skillReference: Skill invocations, slash commands, skill mentions
- agentReference: Agent mentions, subagent references, Task tool usage
- systemCommand: CLI commands, shebangs, imports, package requirements
- toolReference: Tool mentions, tool invocations, hook references
- pluginReference: Plugin dependencies, requirements, prerequisites

Usage:
    dependency-scanner.py                         # Scan all enabled plugins
    dependency-scanner.py --plugin <name>         # Scan specific installed plugin
    dependency-scanner.py --marketplace <name>    # Scan all plugins from a marketplace
    dependency-scanner.py --plugin-dir <path>     # Scan local plugin directory
    dependency-scanner.py --marketplace-dir <path> # Scan local marketplace directory

Output:
    JSON array of matches with location, matched text, context, and type.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Literal

# Pattern type definitions
PatternType = Literal[
    "skillReference",
    "agentReference",
    "systemCommand",
    "toolReference",
    "pluginReference",
]

# Directories to skip during scanning
SKIP_DIRECTORIES: set[str] = {
    ".git",
    "node_modules",
    "__pycache__",
    ".venv",
    "venv",
    ".mypy_cache",
    ".pytest_cache",
    ".ruff_cache",
    "dist",
    "build",
    ".eggs",
}

# File patterns to scan
SCAN_PATTERNS: list[str] = [
    "**/*.md",
    "**/*.json",
    "**/*.py",
    "**/*.sh",
    "**/*.bash",
]

# Context size (characters before and after match)
CONTEXT_SIZE: int = 30


@dataclass
class PatternDefinition:
    """Definition of a pattern to match."""

    name: str
    pattern: re.Pattern[str]
    type: PatternType


@dataclass
class ScanMatch:
    """A single match found during scanning."""

    scanned_plugin: str
    scanned_marketplace: str
    location: str  # file:line:column
    matched: str
    context: str
    type: PatternType

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "scannedPlugin": self.scanned_plugin,
            "scannedMarketplace": self.scanned_marketplace,
            "location": self.location,
            "matched": self.matched,
            "context": self.context,
            "type": self.type,
        }


def build_patterns() -> list[PatternDefinition]:
    """Build the list of patterns to match.

    Returns:
        List of PatternDefinition objects
    """
    patterns: list[PatternDefinition] = []

    # Skill references
    skill_patterns = [
        # Slash command style: /plugin:skill, /skill
        r"/[\w-]+:[\w-]+",
        r"/[\w-]+(?=\s|$|\)|\])",
        # Skill tool invocations
        r'Skill\s*\(\s*skill\s*=\s*["\'][\w-]+(?::[\w-]+)?["\']',
        r'Skill\s+tool\s+(?:to\s+)?(?:invoke|call|use)',
        r"invoke\s+(?:the\s+)?skill",
        r"use\s+(?:the\s+)?skill",
        r"(?:the\s+)?[\w-]+(?::[\w-]+)?\s+skill(?:\s+to)?",
        # Skill mentions in markdown
        r"`[\w-]+:[\w-]+`\s*skill",
        r"skill\s*[`'\"][\w-]+(?::[\w-]+)?[`'\"]",
    ]
    for p in skill_patterns:
        patterns.append(
            PatternDefinition(
                name=f"skill_{p[:20]}",
                pattern=re.compile(p, re.IGNORECASE),
                type="skillReference",
            )
        )

    # Agent references
    agent_patterns = [
        # @ mentions
        r"@[\w-]+(?:[\s,]|$)",
        # Subagent patterns
        r"sub-?agent",
        r"subagent[_\s]type",
        # Task tool
        r"Task\s+tool",
        r"TaskCreate|TaskUpdate|TaskGet|TaskList",
        # Agent invocations
        r"launch\s+(?:an?\s+)?agent",
        r"spawn\s+(?:an?\s+)?agent",
        r"(?:create|start|invoke)\s+(?:an?\s+)?(?:sub)?agent",
        # Agent file references
        r"agents?/[\w-]+\.md",
        r"AGENT\.md",
    ]
    for p in agent_patterns:
        patterns.append(
            PatternDefinition(
                name=f"agent_{p[:20]}",
                pattern=re.compile(p, re.IGNORECASE),
                type="agentReference",
            )
        )

    # System command references
    system_patterns = [
        # Backticked commands (common CLI tools)
        r"`(?:git|npm|pnpm|yarn|pip|cargo|docker|kubectl|gh|curl|wget|make|cmake)"
        r"(?:\s+[\w-]+)*`",
        # Bash tool invocations
        r"Bash\s+tool",
        r"(?:run|execute)\s+(?:the\s+)?(?:command|script)",
        # Command checks
        r"which\s+[\w-]+",
        r"[\w-]+\s+--version",
        r"command\s+-v\s+[\w-]+",
        # Shebangs
        r"#!/(?:usr/)?(?:local/)?bin/(?:env\s+)?(?:bash|sh|python3?|node|ruby|perl)",
        # Python imports
        r"^import\s+[\w.]+",
        r"^from\s+[\w.]+\s+import",
        # JavaScript/TypeScript requires and imports
        r"require\s*\(\s*['\"][\w@/.-]+['\"]\s*\)",
        r"import\s+.*\s+from\s+['\"][\w@/.-]+['\"]",
        # Package manager install commands
        r"(?:pip|npm|pnpm|yarn|cargo)\s+(?:install|add)\s+[\w@/.-]+",
    ]
    for p in system_patterns:
        patterns.append(
            PatternDefinition(
                name=f"system_{p[:20]}",
                pattern=re.compile(p, re.IGNORECASE | re.MULTILINE),
                type="systemCommand",
            )
        )

    # Tool references
    tool_patterns = [
        # Tool mentions
        r"use\s+(?:the\s+)?[\w]+\s+tool",
        r"[\w]+\s+tool(?:\s+to)?",
        r"call\s+(?:the\s+)?[\w]+\s+tool",
        r"invoke\s+(?:the\s+)?[\w]+\s+tool",
        # Hook references
        r"PreToolUse|PostToolUse",
        r"tool\s*hook",
        # Tool invocations in markdown
        r"<invoke\s+name=['\"][\w]+['\"]",
        r"<parameter",
        # MCP tool references
        r"mcp__[\w-]+__[\w]+",
    ]
    for p in tool_patterns:
        patterns.append(
            PatternDefinition(
                name=f"tool_{p[:20]}",
                pattern=re.compile(p, re.IGNORECASE),
                type="toolReference",
            )
        )

    # Plugin references
    plugin_patterns = [
        # Plugin mentions
        r"[\w-]+\s+plugin",
        r"plugin\s+[\w-]+",
        # Dependency declarations
        r"requires\s+(?:the\s+)?[\w-]+",
        r"depends\s+on\s+[\w-]+",
        r"dependency\s+(?:on\s+)?[\w-]+",
        # Installation references
        r"install\s+[\w-]+(?:@[\w-]+)?",
        r"plugin\s+install\s+[\w-]+",
        # Prerequisite mentions
        r"prerequisite[s]?\s*:?\s*[\w-]+",
        r"needs\s+(?:the\s+)?[\w-]+\s+plugin",
        # JSON dependency declarations (in extends-plugin.json)
        r'"dependencies"\s*:\s*\{',
        r'"optionalDependencies"\s*:\s*\{',
        r'"systemDependencies"\s*:\s*\{',
        # Plugin references in markdown
        r"`[\w-]+@[\w-]+`",
        r"[\w-]+@[\w-]+(?:\s+plugin)?",
    ]
    for p in plugin_patterns:
        patterns.append(
            PatternDefinition(
                name=f"plugin_{p[:20]}",
                pattern=re.compile(p, re.IGNORECASE),
                type="pluginReference",
            )
        )

    return patterns


def should_skip_directory(dir_name: str) -> bool:
    """Check if a directory should be skipped.

    Args:
        dir_name: Name of the directory

    Returns:
        True if directory should be skipped
    """
    return dir_name in SKIP_DIRECTORIES or dir_name.endswith(".egg-info")


def get_files_to_scan(plugin_path: Path) -> list[Path]:
    """Get list of files to scan in a plugin directory.

    Args:
        plugin_path: Path to plugin directory

    Returns:
        List of file paths to scan
    """
    files: set[Path] = set()

    for pattern in SCAN_PATTERNS:
        for file_path in plugin_path.glob(pattern):
            # Check if any parent directory should be skipped
            skip = False
            for parent in file_path.relative_to(plugin_path).parents:
                if should_skip_directory(parent.name):
                    skip = True
                    break
            if not skip and file_path.is_file():
                files.add(file_path)

    return sorted(files)


def extract_context(content: str, match: re.Match[str], context_size: int) -> str:
    """Extract context around a match.

    Args:
        content: Full file content
        match: Regex match object
        context_size: Number of characters of context on each side

    Returns:
        Context string with match surrounded by context
    """
    start = max(0, match.start() - context_size)
    end = min(len(content), match.end() + context_size)

    context = content[start:end]

    # Clean up whitespace but preserve structure
    context = " ".join(context.split())

    # Add ellipsis if truncated
    if start > 0:
        context = "..." + context
    if end < len(content):
        context = context + "..."

    return context


def get_line_column(content: str, position: int) -> tuple[int, int]:
    """Get line and column number from character position.

    Args:
        content: Full file content
        position: Character position in content

    Returns:
        Tuple of (line_number, column_number) (1-indexed)
    """
    lines = content[:position].split("\n")
    line_num = len(lines)
    col_num = len(lines[-1]) + 1 if lines else 1
    return line_num, col_num


def scan_file(
    file_path: Path,
    patterns: list[PatternDefinition],
    plugin_name: str,
    marketplace_name: str,
) -> list[ScanMatch]:
    """Scan a single file for dependency patterns.

    Args:
        file_path: Path to file to scan
        patterns: List of patterns to match
        plugin_name: Name of the plugin being scanned
        marketplace_name: Name of the marketplace

    Returns:
        List of ScanMatch objects
    """
    matches: list[ScanMatch] = []

    try:
        content = file_path.read_text(encoding="utf-8", errors="ignore")
    except OSError as e:
        print(f"Warning: Could not read {file_path}: {e}", file=sys.stderr)
        return matches

    # Track matched positions to avoid duplicates
    matched_positions: set[tuple[int, int, str]] = set()

    for pattern_def in patterns:
        for match in pattern_def.pattern.finditer(content):
            line, col = get_line_column(content, match.start())
            matched_text = match.group(0)

            # Skip if we've already matched this position with similar text
            position_key = (line, col, pattern_def.type)
            if position_key in matched_positions:
                continue
            matched_positions.add(position_key)

            context = extract_context(content, match, CONTEXT_SIZE)

            scan_match = ScanMatch(
                scanned_plugin=plugin_name,
                scanned_marketplace=marketplace_name,
                location=f"{file_path}:{line}:{col}",
                matched=matched_text.strip(),
                context=context,
                type=pattern_def.type,
            )
            matches.append(scan_match)

    return matches


def scan_plugin(
    plugin_path: Path,
    plugin_name: str,
    marketplace_name: str,
    patterns: list[PatternDefinition],
) -> list[ScanMatch]:
    """Scan a plugin directory for dependency patterns.

    Args:
        plugin_path: Path to plugin directory
        plugin_name: Name of the plugin
        marketplace_name: Name of the marketplace
        patterns: List of patterns to match

    Returns:
        List of ScanMatch objects
    """
    if not plugin_path.exists():
        print(f"Warning: Plugin path does not exist: {plugin_path}", file=sys.stderr)
        return []

    files = get_files_to_scan(plugin_path)
    all_matches: list[ScanMatch] = []

    for file_path in files:
        file_matches = scan_file(file_path, patterns, plugin_name, marketplace_name)
        all_matches.extend(file_matches)

    return all_matches


class DependencyScanner:
    """Scanner for plugin dependency patterns."""

    def __init__(self) -> None:
        self.claude_dir = Path.home() / ".claude"
        self.plugins_dir = self.claude_dir / "plugins"
        self.patterns = build_patterns()

        self.installed_plugins: dict[str, list[dict[str, Any]]] = {}
        self.enabled_plugins: dict[str, bool] = {}
        self.known_marketplaces: dict[str, dict[str, Any]] = {}

        self._load_config()

    def _load_config(self) -> None:
        """Load plugin configuration files."""
        # Load installed plugins
        installed_path = self.plugins_dir / "installed_plugins.json"
        if installed_path.exists():
            try:
                data = json.loads(installed_path.read_text())
                self.installed_plugins = data.get("plugins", {})
            except (json.JSONDecodeError, OSError) as e:
                print(
                    f"Warning: Failed to load installed_plugins.json: {e}",
                    file=sys.stderr,
                )

        # Load enabled plugins from settings
        settings_path = self.claude_dir / "settings.json"
        if settings_path.exists():
            try:
                data = json.loads(settings_path.read_text())
                self.enabled_plugins = data.get("enabledPlugins", {})
            except (json.JSONDecodeError, OSError) as e:
                print(f"Warning: Failed to load settings.json: {e}", file=sys.stderr)

        # Load known marketplaces
        marketplaces_path = self.plugins_dir / "known_marketplaces.json"
        if marketplaces_path.exists():
            try:
                self.known_marketplaces = json.loads(marketplaces_path.read_text())
            except (json.JSONDecodeError, OSError) as e:
                print(
                    f"Warning: Failed to load known_marketplaces.json: {e}",
                    file=sys.stderr,
                )

    def _parse_plugin_key(self, plugin_key: str) -> tuple[str, str]:
        """Parse a plugin key into name and marketplace.

        Args:
            plugin_key: Plugin key in format "name@marketplace"

        Returns:
            Tuple of (plugin_name, marketplace_name)
        """
        if "@" in plugin_key:
            parts = plugin_key.rsplit("@", 1)
            return parts[0], parts[1]
        return plugin_key, ""

    def scan_enabled_plugins(self) -> list[ScanMatch]:
        """Scan all enabled plugins.

        Returns:
            List of ScanMatch objects
        """
        all_matches: list[ScanMatch] = []

        for plugin_key, enabled in self.enabled_plugins.items():
            if not enabled:
                continue

            plugin_name, marketplace = self._parse_plugin_key(plugin_key)

            # Find installed plugin info
            if plugin_key in self.installed_plugins:
                installs = self.installed_plugins[plugin_key]
                if installs:
                    install_path = Path(installs[0].get("installPath", ""))
                    if install_path.exists():
                        matches = scan_plugin(
                            install_path, plugin_name, marketplace, self.patterns
                        )
                        all_matches.extend(matches)

        return all_matches

    def scan_specific_plugin(self, plugin_spec: str) -> list[ScanMatch]:
        """Scan a specific installed plugin.

        Args:
            plugin_spec: Plugin specification (name or name@marketplace)

        Returns:
            List of ScanMatch objects
        """
        plugin_name, marketplace = self._parse_plugin_key(plugin_spec)

        # Try to find the plugin
        for plugin_key, installs in self.installed_plugins.items():
            pname, pmkt = self._parse_plugin_key(plugin_key)
            if pname == plugin_name:
                if marketplace and pmkt != marketplace:
                    continue
                if installs:
                    install_path = Path(installs[0].get("installPath", ""))
                    if install_path.exists():
                        return scan_plugin(
                            install_path, plugin_name, pmkt, self.patterns
                        )

        print(f"Warning: Plugin not found: {plugin_spec}", file=sys.stderr)
        return []

    def scan_marketplace(self, marketplace_name: str) -> list[ScanMatch]:
        """Scan all plugins from a specific marketplace.

        Args:
            marketplace_name: Name of the marketplace

        Returns:
            List of ScanMatch objects
        """
        all_matches: list[ScanMatch] = []

        if marketplace_name not in self.known_marketplaces:
            print(f"Warning: Marketplace not found: {marketplace_name}", file=sys.stderr)
            return []

        mkt_info = self.known_marketplaces[marketplace_name]
        install_location = mkt_info.get("installLocation", "")
        if not install_location:
            print(
                f"Warning: No install location for marketplace: {marketplace_name}",
                file=sys.stderr,
            )
            return []

        mkt_path = Path(install_location)
        plugins_dir = mkt_path / "plugins"

        if not plugins_dir.exists():
            # Try marketplace root directly (for single-plugin marketplaces)
            claude_plugin = mkt_path / ".claude-plugin"
            if claude_plugin.exists():
                matches = scan_plugin(
                    mkt_path, mkt_path.name, marketplace_name, self.patterns
                )
                all_matches.extend(matches)
            else:
                print(
                    f"Warning: No plugins directory found in: {mkt_path}",
                    file=sys.stderr,
                )
            return all_matches

        # Scan each plugin in the marketplace
        for plugin_dir in plugins_dir.iterdir():
            if plugin_dir.is_dir():
                claude_plugin = plugin_dir / ".claude-plugin"
                if claude_plugin.exists():
                    matches = scan_plugin(
                        plugin_dir, plugin_dir.name, marketplace_name, self.patterns
                    )
                    all_matches.extend(matches)

        return all_matches

    def scan_plugin_directory(self, plugin_path: str) -> list[ScanMatch]:
        """Scan a local plugin directory.

        Args:
            plugin_path: Path to plugin directory

        Returns:
            List of ScanMatch objects
        """
        path = Path(plugin_path).resolve()
        if not path.exists():
            print(f"Error: Directory does not exist: {plugin_path}", file=sys.stderr)
            return []

        # Determine plugin name from directory
        plugin_name = path.name
        marketplace_name = "local"

        return scan_plugin(path, plugin_name, marketplace_name, self.patterns)

    def scan_marketplace_directory(self, marketplace_path: str) -> list[ScanMatch]:
        """Scan a local marketplace directory.

        Args:
            marketplace_path: Path to marketplace directory

        Returns:
            List of ScanMatch objects
        """
        all_matches: list[ScanMatch] = []
        path = Path(marketplace_path).resolve()

        if not path.exists():
            print(
                f"Error: Directory does not exist: {marketplace_path}", file=sys.stderr
            )
            return []

        marketplace_name = path.name
        plugins_dir = path / "plugins"

        if not plugins_dir.exists():
            # Try marketplace root directly (for single-plugin marketplaces)
            claude_plugin = path / ".claude-plugin"
            if claude_plugin.exists():
                matches = scan_plugin(
                    path, path.name, marketplace_name, self.patterns
                )
                all_matches.extend(matches)
            else:
                print(
                    f"Warning: No plugins directory found in: {path}", file=sys.stderr
                )
            return all_matches

        # Scan each plugin in the marketplace
        for plugin_dir in plugins_dir.iterdir():
            if plugin_dir.is_dir():
                claude_plugin = plugin_dir / ".claude-plugin"
                if claude_plugin.exists():
                    matches = scan_plugin(
                        plugin_dir, plugin_dir.name, marketplace_name, self.patterns
                    )
                    all_matches.extend(matches)

        return all_matches


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Scan Claude plugins for dependency patterns",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                              Scan all enabled plugins
  %(prog)s --plugin devs                Scan specific plugin by name
  %(prog)s --plugin devs@mymarket       Scan specific plugin with marketplace
  %(prog)s --marketplace mymarket       Scan all plugins from a marketplace
  %(prog)s --plugin-dir ./my-plugin     Scan local plugin directory
  %(prog)s --marketplace-dir ./mymarket Scan local marketplace directory

Output is a JSON array of matches with structure:
  [
    {
      "scannedPlugin": "plugin-name",
      "scannedMarketplace": "marketplace-name",
      "location": "/path/to/file.md:42:17",
      "matched": "matched text",
      "context": "...surrounding text...",
      "type": "skillReference|agentReference|systemCommand|toolReference|pluginReference"
    }
  ]
""",
    )

    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument(
        "--plugin",
        metavar="NAME",
        help="Scan specific installed plugin (format: name or name@marketplace)",
    )
    mode_group.add_argument(
        "--marketplace",
        metavar="NAME",
        help="Scan all plugins from a specific marketplace",
    )
    mode_group.add_argument(
        "--plugin-dir",
        metavar="PATH",
        help="Scan a local plugin directory",
    )
    mode_group.add_argument(
        "--marketplace-dir",
        metavar="PATH",
        help="Scan a local marketplace directory",
    )

    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print JSON output",
    )

    parser.add_argument(
        "--type",
        choices=[
            "skillReference",
            "agentReference",
            "systemCommand",
            "toolReference",
            "pluginReference",
        ],
        help="Filter results by pattern type",
    )

    return parser.parse_args()


def main() -> int:
    """Main entry point."""
    args = parse_args()

    scanner = DependencyScanner()

    # Run appropriate scan based on arguments
    if args.plugin:
        matches = scanner.scan_specific_plugin(args.plugin)
    elif args.marketplace:
        matches = scanner.scan_marketplace(args.marketplace)
    elif args.plugin_dir:
        matches = scanner.scan_plugin_directory(args.plugin_dir)
    elif args.marketplace_dir:
        matches = scanner.scan_marketplace_directory(args.marketplace_dir)
    else:
        # Default: scan enabled plugins
        matches = scanner.scan_enabled_plugins()

    # Filter by type if specified
    if args.type:
        matches = [m for m in matches if m.type == args.type]

    # Convert to JSON
    output = [m.to_dict() for m in matches]

    if args.pretty:
        print(json.dumps(output, indent=2))
    else:
        print(json.dumps(output))

    return 0


if __name__ == "__main__":
    sys.exit(main())
