#!/usr/bin/env python3
"""
Resolution Steps Generator for Claude Plugin Dependencies

This script reads JSON output from dependency-checker.py and generates
human-readable resolution steps for any unsatisfied dependencies.

Usage:
    resolution-steps.py                     # Read from stdin
    resolution-steps.py <file>              # Read from file
    dependency-checker.py | resolution-steps.py  # Pipe from checker

Output:
    - If all dependencies satisfied: "All dependencies satisfied."
    - Otherwise: Numbered list of resolution steps
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass
class ResolutionStep:
    """Represents a single resolution step for an unsatisfied dependency."""

    dep_type: str  # "Required", "Optional", "Required System", "Optional System"
    name: str  # Plugin name or command name
    dependent: str  # Plugin that requires this dependency
    marketplace: str | None  # Marketplace for plugin dependencies
    issue: str  # Description of the issue
    resolution: str  # Resolution command or help text
    help_text: str  # Additional help text if available


def parse_dependent(dependent: str) -> str:
    """Format the dependent string for display."""
    return dependent if dependent else "unknown"


def get_plugin_resolution(
    dep: dict[str, Any],
    is_optional: bool = False,
) -> ResolutionStep | None:
    """Generate resolution step for a plugin dependency.

    Args:
        dep: Dependency dict from dependency-checker.py output
        is_optional: Whether this is an optional dependency

    Returns:
        ResolutionStep if dependency is invalid, None otherwise
    """
    if dep.get("valid", True):
        return None

    plugin_name = dep.get("plugin", "unknown")
    marketplace = dep.get("marketplace")
    dependent = parse_dependent(dep.get("dependent", ""))
    installed = dep.get("installed", False)
    enabled = dep.get("enabled", False)
    installed_version = dep.get("installedVersion")
    required_version = dep.get("requiredVersion", "*")
    help_text = dep.get("help", "")

    dep_type = "Optional" if is_optional else "Required"

    if not installed:
        # Plugin not installed
        if help_text and not help_text.startswith("Plugin"):
            # Custom help text provided
            resolution = help_text
        elif marketplace:
            resolution = f"/plugin install {plugin_name}@{marketplace}"
        else:
            resolution = f"/plugin install {plugin_name}"
        issue = "Not installed"
    elif not enabled:
        # Plugin installed but not enabled
        resolution = "Enable via /plugin TUI"
        issue = "Installed but not enabled"
    else:
        # Wrong version
        issue = f"Version mismatch: {installed_version} does not satisfy {required_version}"
        if marketplace:
            resolution = f"/plugin update {plugin_name}@{marketplace}"
        else:
            resolution = f"/plugin update {plugin_name}"
        # Don't use the generic help text for version mismatches, use the update command
        help_text = ""

    return ResolutionStep(
        dep_type=dep_type,
        name=plugin_name,
        dependent=dependent,
        marketplace=marketplace,
        issue=issue,
        resolution=resolution,
        help_text=help_text if help_text and not help_text.startswith("Plugin") else "",
    )


def get_system_resolution(
    dep: dict[str, Any],
    is_optional: bool = False,
) -> ResolutionStep | None:
    """Generate resolution step for a system dependency.

    Args:
        dep: Dependency dict from dependency-checker.py output
        is_optional: Whether this is an optional dependency

    Returns:
        ResolutionStep if dependency is invalid, None otherwise
    """
    if dep.get("valid", True):
        return None

    command = dep.get("command", "unknown")
    dependent = parse_dependent(dep.get("dependent", ""))
    installed = dep.get("installed", False)
    installed_version = dep.get("installedVersion")
    required_version = dep.get("requiredVersion", "*")
    help_text = dep.get("help", "")

    dep_type = "Optional System" if is_optional else "Required System"

    if not installed:
        # Command not installed
        if help_text and not help_text.startswith("Command"):
            # Custom help text provided
            resolution = help_text
        else:
            resolution = f"Install {command}"
        issue = "Not installed"
    else:
        # Wrong version
        issue = f"Version mismatch: {installed_version} does not satisfy {required_version}"
        if help_text and not help_text.startswith("Installed version"):
            resolution = help_text
        else:
            resolution = f"Update {command} to satisfy version {required_version}"

    return ResolutionStep(
        dep_type=dep_type,
        name=command,
        dependent=dependent,
        marketplace=None,
        issue=issue,
        resolution=resolution,
        help_text=help_text if help_text and not help_text.startswith(("Command", "Installed version")) else "",
    )


def format_resolution_steps(steps: list[ResolutionStep]) -> str:
    """Format resolution steps for output.

    Args:
        steps: List of ResolutionStep objects

    Returns:
        Formatted string output
    """
    if not steps:
        return "All dependencies satisfied."

    lines = [f"## Resolution Steps ({len(steps)} issue{'s' if len(steps) != 1 else ''})"]
    lines.append("")

    for i, step in enumerate(steps, 1):
        # Format the header line
        lines.append(f"{i}. [{step.dep_type}] {step.name} (required by {step.dependent})")

        # Add the resolution command or help text
        if step.help_text:
            lines.append(f"   {step.help_text}")
        else:
            lines.append(f"   {step.resolution}")

        lines.append("")

    return "\n".join(lines).rstrip()


def generate_resolution_steps(data: dict[str, Any]) -> list[ResolutionStep]:
    """Generate resolution steps from dependency checker output.

    Args:
        data: Parsed JSON from dependency-checker.py

    Returns:
        List of ResolutionStep objects for unsatisfied dependencies
    """
    steps: list[ResolutionStep] = []

    # Process required plugin dependencies
    for dep in data.get("dependencies", []):
        step = get_plugin_resolution(dep, is_optional=False)
        if step:
            steps.append(step)

    # Process optional plugin dependencies
    for dep in data.get("optionalDependencies", []):
        step = get_plugin_resolution(dep, is_optional=True)
        if step:
            steps.append(step)

    # Process required system dependencies
    for dep in data.get("systemDependencies", []):
        step = get_system_resolution(dep, is_optional=False)
        if step:
            steps.append(step)

    # Process optional system dependencies
    for dep in data.get("optionalSystemDependencies", []):
        step = get_system_resolution(dep, is_optional=True)
        if step:
            steps.append(step)

    return steps


def read_input(file_path: str | None = None) -> str:
    """Read JSON input from file or stdin.

    Args:
        file_path: Optional path to JSON file

    Returns:
        JSON string content
    """
    if file_path:
        path = Path(file_path)
        if not path.exists():
            print(f"Error: File not found: {file_path}", file=sys.stderr)
            sys.exit(1)
        return path.read_text()
    else:
        # Read from stdin
        if sys.stdin.isatty():
            print("Error: No input provided. Pipe JSON or provide file path.", file=sys.stderr)
            print("Usage: resolution-steps.py [file]", file=sys.stderr)
            print("       dependency-checker.py | resolution-steps.py", file=sys.stderr)
            sys.exit(1)
        return sys.stdin.read()


def main() -> int:
    """Main entry point."""
    # Get file path from arguments if provided
    file_path: str | None = None
    if len(sys.argv) > 1:
        if sys.argv[1] in ("-h", "--help"):
            print(__doc__)
            return 0
        file_path = sys.argv[1]

    # Read input
    try:
        content = read_input(file_path)
    except OSError as e:
        print(f"Error reading input: {e}", file=sys.stderr)
        return 1

    # Parse JSON
    try:
        data = json.loads(content)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON: {e}", file=sys.stderr)
        return 1

    # Generate resolution steps
    steps = generate_resolution_steps(data)

    # Output formatted steps
    output = format_resolution_steps(steps)
    print(output)

    # Return non-zero if there are required issues
    required_issues = sum(
        1 for step in steps
        if step.dep_type in ("Required", "Required System")
    )
    return 1 if required_issues > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
