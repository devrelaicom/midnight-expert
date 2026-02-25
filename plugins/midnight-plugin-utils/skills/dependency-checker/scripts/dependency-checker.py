#!/usr/bin/env python3
"""
Dependency Checker for Claude Plugins

This script checks if plugin dependencies are satisfied by examining:
- Plugin dependencies (required plugins)
- Optional plugin dependencies
- System dependencies (CLI tools like gh, git)
- Optional system dependencies

It reads configuration from:
- ~/.claude/plugins/installed_plugins.json (installed plugins)
- ~/.claude/settings.json (enabled plugins)
- ~/.claude/plugins/known_marketplaces.json (marketplace information)
- Each plugin's .claude-plugin/extends-plugin.json (dependency declarations)

Usage:
    dependency-checker.py                    # Check enabled plugins only
    dependency-checker.py --installed        # Check all installed plugins
    dependency-checker.py --all              # Check all plugins in known marketplaces
    dependency-checker.py --plugin <name>    # Check specific plugin (format: plugin-name@marketplace)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Literal


# Version matching utilities
@dataclass
class Version:
    """Represents a semantic version."""

    major: int
    minor: int
    patch: int
    prerelease: str = ""
    build: str = ""

    @classmethod
    def parse(cls, version_str: str) -> Version | None:
        """Parse a version string into a Version object."""
        if not version_str:
            return None

        # Clean version string
        version_str = version_str.strip().lstrip("v")

        # Handle git commit SHAs (12 hex characters)
        if re.match(r"^[0-9a-f]{12}$", version_str):
            return None

        # Basic semver pattern
        pattern = r"^(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:-([a-zA-Z0-9.-]+))?(?:\+([a-zA-Z0-9.-]+))?$"
        match = re.match(pattern, version_str)

        if not match:
            return None

        return cls(
            major=int(match.group(1)),
            minor=int(match.group(2) or 0),
            patch=int(match.group(3) or 0),
            prerelease=match.group(4) or "",
            build=match.group(5) or "",
        )

    def __str__(self) -> str:
        result = f"{self.major}.{self.minor}.{self.patch}"
        if self.prerelease:
            result += f"-{self.prerelease}"
        if self.build:
            result += f"+{self.build}"
        return result

    def __lt__(self, other: Version) -> bool:
        if (self.major, self.minor, self.patch) != (
            other.major,
            other.minor,
            other.patch,
        ):
            return (self.major, self.minor, self.patch) < (
                other.major,
                other.minor,
                other.patch,
            )
        # Prerelease versions are lower than release versions
        if self.prerelease and not other.prerelease:
            return True
        if not self.prerelease and other.prerelease:
            return False
        return self.prerelease < other.prerelease

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, Version):
            return NotImplemented
        return (
            self.major == other.major
            and self.minor == other.minor
            and self.patch == other.patch
            and self.prerelease == other.prerelease
        )

    def __le__(self, other: Version) -> bool:
        return self < other or self == other

    def __gt__(self, other: Version) -> bool:
        return not self <= other

    def __ge__(self, other: Version) -> bool:
        return not self < other


def parse_version_constraint(constraint: str) -> tuple[str, str]:
    """Parse a version constraint into operator and version parts.

    Returns:
        Tuple of (operator, version_string)
    """
    constraint = constraint.strip()

    if constraint == "*":
        return ("*", "")

    # Check for operators
    for op in (">=", "<=", ">", "<", "^", "~", "="):
        if constraint.startswith(op):
            return (op, constraint[len(op) :].strip())

    # No operator means exact match
    return ("=", constraint)


def version_satisfies(installed_version: str, constraint: str) -> bool:
    """Check if an installed version satisfies a version constraint.

    Supports:
    - Exact version: "1.0.0"
    - Greater than or equal: ">=1.0.0"
    - Less than or equal: "<=1.0.0"
    - Greater than: ">1.0.0"
    - Less than: "<1.0.0"
    - Caret range: "^1.0.0" (compatible with 1.x.x)
    - Tilde range: "~1.0.0" (compatible with 1.0.x)
    - Any version: "*"
    """
    if constraint == "*":
        return True

    installed = Version.parse(installed_version)
    if installed is None:
        # If we can't parse the installed version (e.g., git SHA), we can't validate
        # Return True to be permissive - the dependency is installed
        return True

    operator, version_str = parse_version_constraint(constraint)

    if operator == "*":
        return True

    required = Version.parse(version_str)
    if required is None:
        return True  # Can't parse constraint, assume satisfied

    if operator == "=":
        return installed == required
    elif operator == ">=":
        return installed >= required
    elif operator == "<=":
        return installed <= required
    elif operator == ">":
        return installed > required
    elif operator == "<":
        return installed < required
    elif operator == "^":
        # Caret: allows changes that do not modify the left-most non-zero digit
        # ^1.2.3 := >=1.2.3 <2.0.0
        # ^0.2.3 := >=0.2.3 <0.3.0
        # ^0.0.3 := >=0.0.3 <0.0.4
        if installed < required:
            return False
        if required.major != 0:
            return installed.major == required.major
        elif required.minor != 0:
            return installed.major == 0 and installed.minor == required.minor
        else:
            return (
                installed.major == 0
                and installed.minor == 0
                and installed.patch == required.patch
            )
    elif operator == "~":
        # Tilde: allows patch-level changes
        # ~1.2.3 := >=1.2.3 <1.3.0
        if installed < required:
            return False
        return installed.major == required.major and installed.minor == required.minor

    return True


@dataclass
class DependencyResult:
    """Result of checking a single dependency."""

    plugin: str | None = None
    command: str | None = None
    marketplace: str | None = None
    dependent: str = ""
    required_version: str = ""
    installed: bool = False
    enabled: bool = False
    installed_version: str | None = None
    valid: bool = False
    help: str = ""

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        result: dict[str, Any] = {}
        if self.plugin is not None:
            result["plugin"] = self.plugin
        if self.command is not None:
            result["command"] = self.command
        if self.marketplace is not None:
            result["marketplace"] = self.marketplace
        result["dependent"] = self.dependent
        result["requiredVersion"] = self.required_version
        result["installed"] = self.installed
        result["enabled"] = self.enabled
        result["installedVersion"] = self.installed_version
        result["valid"] = self.valid
        result["help"] = self.help
        return result


@dataclass
class CheckResult:
    """Overall result of dependency checking."""

    checked_scope: Literal["enabled", "installed", "all"]
    checked_plugin: str | None
    dependencies: list[DependencyResult] = field(default_factory=list)
    optional_dependencies: list[DependencyResult] = field(default_factory=list)
    system_dependencies: list[DependencyResult] = field(default_factory=list)
    optional_system_dependencies: list[DependencyResult] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "checkedScope": self.checked_scope,
            "checkedPlugin": self.checked_plugin,
            "dependencies": [d.to_dict() for d in self.dependencies],
            "optionalDependencies": [d.to_dict() for d in self.optional_dependencies],
            "systemDependencies": [d.to_dict() for d in self.system_dependencies],
            "optionalSystemDependencies": [
                d.to_dict() for d in self.optional_system_dependencies
            ],
        }


class DependencyChecker:
    """Checks plugin dependencies for satisfaction."""

    def __init__(self) -> None:
        self.claude_dir = Path.home() / ".claude"
        self.plugins_dir = self.claude_dir / "plugins"

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
                print(f"Warning: Failed to load installed_plugins.json: {e}", file=sys.stderr)

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
                print(f"Warning: Failed to load known_marketplaces.json: {e}", file=sys.stderr)

    def _get_plugin_key(self, plugin_name: str, marketplace: str) -> str:
        """Get the standard plugin key format."""
        return f"{plugin_name}@{marketplace}"

    def _parse_plugin_key(self, plugin_key: str) -> tuple[str, str]:
        """Parse a plugin key into name and marketplace."""
        if "@" in plugin_key:
            parts = plugin_key.rsplit("@", 1)
            return parts[0], parts[1]
        return plugin_key, ""

    def _get_installed_plugin_info(
        self, plugin_name: str, marketplace: str | None = None
    ) -> dict[str, Any] | None:
        """Get installed plugin information.

        Args:
            plugin_name: Name of the plugin
            marketplace: Optional marketplace name to filter by

        Returns:
            Plugin installation info or None if not installed
        """
        # Try exact key match first
        if marketplace:
            key = self._get_plugin_key(plugin_name, marketplace)
            if key in self.installed_plugins:
                installs = self.installed_plugins[key]
                if installs:
                    return installs[0]

        # Search all installed plugins
        for key, installs in self.installed_plugins.items():
            name, _ = self._parse_plugin_key(key)
            if name == plugin_name:
                if installs:
                    return installs[0]

        return None

    def _is_plugin_enabled(
        self, plugin_name: str, marketplace: str | None = None
    ) -> bool:
        """Check if a plugin is enabled.

        Args:
            plugin_name: Name of the plugin
            marketplace: Optional marketplace name

        Returns:
            True if the plugin is enabled
        """
        if marketplace:
            key = self._get_plugin_key(plugin_name, marketplace)
            return self.enabled_plugins.get(key, False)

        # Search by name
        for key, enabled in self.enabled_plugins.items():
            name, _ = self._parse_plugin_key(key)
            if name == plugin_name and enabled:
                return True

        return False

    def _load_extends_plugin(self, install_path: str) -> dict[str, Any] | None:
        """Load extends-plugin.json from a plugin's install path."""
        extends_path = Path(install_path) / ".claude-plugin" / "extends-plugin.json"
        if extends_path.exists():
            try:
                return json.loads(extends_path.read_text())
            except (json.JSONDecodeError, OSError):
                pass
        return None

    def _check_system_command(self, command: str) -> tuple[bool, str | None]:
        """Check if a system command is available and get its version.

        Returns:
            Tuple of (is_available, version_string or None)
        """
        # Check if command exists
        if not shutil.which(command):
            return False, None

        # Try to get version
        version_flags = ["--version", "-version", "-v", "version"]
        for flag in version_flags:
            try:
                result = subprocess.run(
                    [command, flag],
                    capture_output=True,
                    text=True,
                    timeout=5,
                )
                output = result.stdout or result.stderr
                if output:
                    # Try to extract version number from output
                    # Common patterns: "X.Y.Z", "vX.Y.Z", "version X.Y.Z"
                    version_match = re.search(
                        r"(?:version\s*)?v?(\d+\.\d+(?:\.\d+)?(?:-[a-zA-Z0-9.-]+)?)",
                        output,
                        re.IGNORECASE,
                    )
                    if version_match:
                        return True, version_match.group(1)
                    # If command ran successfully but no version found, return True
                    if result.returncode == 0:
                        return True, None
            except (subprocess.TimeoutExpired, subprocess.SubprocessError, OSError):
                continue

        # Command exists but couldn't get version
        return True, None

    def _check_plugin_dependency(
        self,
        dep_plugin: str,
        dep_marketplace: str | None,
        required_version: str,
        dependent: str,
    ) -> DependencyResult:
        """Check a single plugin dependency."""
        result = DependencyResult(
            plugin=dep_plugin,
            marketplace=dep_marketplace,
            dependent=dependent,
            required_version=required_version,
        )

        # Find installed plugin
        info = self._get_installed_plugin_info(dep_plugin, dep_marketplace)

        if info:
            result.installed = True
            result.installed_version = info.get("version")
            result.enabled = self._is_plugin_enabled(dep_plugin, dep_marketplace)

            # Check version constraint
            if result.installed_version:
                result.valid = version_satisfies(
                    result.installed_version, required_version
                )
            else:
                result.valid = True  # No version to check, assume valid

            if not result.valid:
                result.help = (
                    f"Installed version {result.installed_version} does not satisfy "
                    f"required version {required_version}"
                )
            elif not result.enabled:
                result.help = f"Plugin {dep_plugin} is installed but not enabled"
        else:
            result.valid = False
            if dep_marketplace:
                result.help = (
                    f"Plugin {dep_plugin} from {dep_marketplace} is not installed. "
                    f"Install with: claude plugin install {dep_plugin}"
                )
            else:
                result.help = (
                    f"Plugin {dep_plugin} is not installed. "
                    f"Install with: claude plugin install {dep_plugin}"
                )

        return result

    def _check_system_dependency(
        self,
        command: str,
        required_version: str,
        dependent: str,
    ) -> DependencyResult:
        """Check a single system dependency."""
        result = DependencyResult(
            command=command,
            dependent=dependent,
            required_version=required_version,
        )

        is_available, version = self._check_system_command(command)
        result.installed = is_available
        result.installed_version = version
        result.enabled = is_available  # System commands are "enabled" if installed

        if is_available:
            if version and required_version and required_version != "*":
                result.valid = version_satisfies(version, required_version)
                if not result.valid:
                    result.help = (
                        f"Installed version {version} does not satisfy "
                        f"required version {required_version}"
                    )
            else:
                result.valid = True
        else:
            result.valid = False
            result.help = (
                f"Command '{command}' is not installed or not in PATH. "
                f"Please install {command} to use this plugin."
            )

        return result

    def _get_plugins_to_check(
        self,
        scope: Literal["enabled", "installed", "all"],
        specific_plugin: str | None = None,
    ) -> list[tuple[str, str, str]]:
        """Get list of plugins to check based on scope.

        Returns:
            List of tuples: (plugin_key, install_path, marketplace)
        """
        plugins_to_check: list[tuple[str, str, str]] = []

        if specific_plugin:
            # Check specific plugin
            name, marketplace = self._parse_plugin_key(specific_plugin)
            if marketplace:
                info = self._get_installed_plugin_info(name, marketplace)
                if info:
                    plugins_to_check.append(
                        (specific_plugin, info.get("installPath", ""), marketplace)
                    )
            else:
                # Search by name
                for key, installs in self.installed_plugins.items():
                    pname, pmkt = self._parse_plugin_key(key)
                    if pname == name and installs:
                        plugins_to_check.append(
                            (key, installs[0].get("installPath", ""), pmkt)
                        )
                        break
        elif scope == "enabled":
            # Check only enabled plugins
            for plugin_key, enabled in self.enabled_plugins.items():
                if enabled:
                    name, marketplace = self._parse_plugin_key(plugin_key)
                    info = self._get_installed_plugin_info(name, marketplace)
                    if info:
                        plugins_to_check.append(
                            (plugin_key, info.get("installPath", ""), marketplace)
                        )
        elif scope == "installed":
            # Check all installed plugins
            for plugin_key, installs in self.installed_plugins.items():
                if installs:
                    _, marketplace = self._parse_plugin_key(plugin_key)
                    plugins_to_check.append(
                        (plugin_key, installs[0].get("installPath", ""), marketplace)
                    )
        elif scope == "all":
            # Check all plugins in known marketplaces
            # First add installed plugins
            installed_keys = set()
            for plugin_key, installs in self.installed_plugins.items():
                if installs:
                    _, marketplace = self._parse_plugin_key(plugin_key)
                    plugins_to_check.append(
                        (plugin_key, installs[0].get("installPath", ""), marketplace)
                    )
                    installed_keys.add(plugin_key)

            # Then scan marketplaces for uninstalled plugins
            for mkt_name, mkt_info in self.known_marketplaces.items():
                install_location = mkt_info.get("installLocation", "")
                if not install_location:
                    continue

                mkt_path = Path(install_location)
                if not mkt_path.exists():
                    continue

                # Look for plugins in the marketplace
                plugins_dir = mkt_path / "plugins"
                if plugins_dir.exists():
                    for plugin_dir in plugins_dir.iterdir():
                        if plugin_dir.is_dir():
                            claude_plugin = plugin_dir / ".claude-plugin"
                            if claude_plugin.exists():
                                plugin_key = f"{plugin_dir.name}@{mkt_name}"
                                if plugin_key not in installed_keys:
                                    plugins_to_check.append(
                                        (plugin_key, str(plugin_dir), mkt_name)
                                    )

        return plugins_to_check

    def check_dependencies(
        self,
        scope: Literal["enabled", "installed", "all"] = "enabled",
        specific_plugin: str | None = None,
    ) -> CheckResult:
        """Check dependencies for plugins based on scope.

        Args:
            scope: Which plugins to check
            specific_plugin: Specific plugin to check (overrides scope)

        Returns:
            CheckResult with all dependency check results
        """
        result = CheckResult(
            checked_scope=scope,
            checked_plugin=specific_plugin,
        )

        plugins_to_check = self._get_plugins_to_check(scope, specific_plugin)

        for plugin_key, install_path, marketplace in plugins_to_check:
            if not install_path:
                continue

            extends = self._load_extends_plugin(install_path)
            if not extends:
                continue

            # Check regular dependencies
            dependencies = extends.get("dependencies", {})
            for dep_name, dep_version in dependencies.items():
                dep_plugin, dep_mkt = self._parse_plugin_key(dep_name)
                dep_result = self._check_plugin_dependency(
                    dep_plugin,
                    dep_mkt or None,
                    dep_version,
                    plugin_key,
                )
                result.dependencies.append(dep_result)

            # Check optional dependencies
            optional_deps = extends.get("optionalDependencies", {})
            for dep_name, dep_version in optional_deps.items():
                dep_plugin, dep_mkt = self._parse_plugin_key(dep_name)
                dep_result = self._check_plugin_dependency(
                    dep_plugin,
                    dep_mkt or None,
                    dep_version,
                    plugin_key,
                )
                result.optional_dependencies.append(dep_result)

            # Check system dependencies
            sys_deps = extends.get("systemDependencies", {})
            for cmd, version in sys_deps.items():
                sys_result = self._check_system_dependency(cmd, version, plugin_key)
                result.system_dependencies.append(sys_result)

            # Check optional system dependencies
            opt_sys_deps = extends.get("optionalSystemDependencies", {})
            for cmd, version in opt_sys_deps.items():
                sys_result = self._check_system_dependency(cmd, version, plugin_key)
                result.optional_system_dependencies.append(sys_result)

        return result


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Check Claude plugin dependencies",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                           Check enabled plugins only
  %(prog)s --installed               Check all installed plugins
  %(prog)s --all                     Check all plugins in known marketplaces
  %(prog)s --plugin devs@my-market   Check specific plugin

Output is JSON with structure:
  {
    "checkedScope": "enabled|installed|all",
    "checkedPlugin": null or "plugin-name",
    "dependencies": [...],
    "optionalDependencies": [...],
    "systemDependencies": [...],
    "optionalSystemDependencies": [...]
  }
""",
    )

    scope_group = parser.add_mutually_exclusive_group()
    scope_group.add_argument(
        "--installed",
        action="store_true",
        help="Check all installed plugins (default: only enabled)",
    )
    scope_group.add_argument(
        "--all",
        action="store_true",
        help="Check all plugins in known marketplaces",
    )
    scope_group.add_argument(
        "--plugin",
        metavar="NAME",
        help="Check specific plugin (format: plugin-name or plugin-name@marketplace)",
    )

    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print JSON output",
    )

    return parser.parse_args()


def main() -> int:
    """Main entry point."""
    args = parse_args()

    # Determine scope
    scope: Literal["enabled", "installed", "all"] = "enabled"
    specific_plugin: str | None = None

    if args.plugin:
        specific_plugin = args.plugin
    elif args.installed:
        scope = "installed"
    elif args.all:
        scope = "all"

    # Run dependency check
    checker = DependencyChecker()
    result = checker.check_dependencies(scope, specific_plugin)

    # Output JSON
    output = result.to_dict()
    if args.pretty:
        print(json.dumps(output, indent=2))
    else:
        print(json.dumps(output))

    # Return non-zero if any required dependencies are invalid
    has_invalid = any(not d.valid for d in result.dependencies)
    has_invalid_sys = any(not d.valid for d in result.system_dependencies)

    return 1 if (has_invalid or has_invalid_sys) else 0


if __name__ == "__main__":
    sys.exit(main())
