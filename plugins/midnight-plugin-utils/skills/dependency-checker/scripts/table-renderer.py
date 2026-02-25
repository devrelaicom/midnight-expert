#!/usr/bin/env python3
"""
Table Renderer for Dependency Check Results

This script renders ASCII tables from the JSON output of dependency-checker.py.
It displays dependency check results in a human-readable format using box-drawing
characters.

Usage:
    dependency-checker.py | table-renderer.py          # Read from stdin
    table-renderer.py results.json                     # Read from file
    dependency-checker.py --pretty | table-renderer.py # Pretty JSON also works
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


# Box-drawing characters
BOX_TOP_LEFT = "┌"
BOX_TOP_RIGHT = "┐"
BOX_BOTTOM_LEFT = "└"
BOX_BOTTOM_RIGHT = "┘"
BOX_HORIZONTAL = "─"
BOX_VERTICAL = "│"
BOX_T_DOWN = "┬"
BOX_T_UP = "┴"
BOX_T_RIGHT = "├"
BOX_T_LEFT = "┤"
BOX_CROSS = "┼"

# Status symbols
CHECK_MARK = "✓"
X_MARK = "✗"


@dataclass
class Column:
    """Represents a table column."""

    header: str
    key: str
    min_width: int = 0
    is_boolean: bool = False


def bool_to_symbol(value: bool) -> str:
    """Convert boolean to checkmark or X mark."""
    return CHECK_MARK if value else X_MARK


def get_notes(entry: dict[str, Any], is_system: bool = False) -> str:
    """Generate notes based on the entry status."""
    notes: list[str] = []

    if not entry.get("installed", False):
        notes.append("not installed")
    elif not entry.get("enabled", False) and not is_system:
        notes.append("disabled")
    elif not entry.get("valid", False):
        required = entry.get("requiredVersion", "")
        installed = entry.get("installedVersion", "")
        if required and installed:
            notes.append(f"version mismatch ({installed} vs {required})")
        else:
            notes.append("version mismatch")

    return ", ".join(notes)


def truncate_str(s: str, max_width: int) -> str:
    """Truncate string to max width, adding ellipsis if needed."""
    if len(s) <= max_width:
        return s
    return s[: max_width - 1] + "…"


def calculate_column_widths(
    columns: list[Column], rows: list[dict[str, Any]]
) -> list[int]:
    """Calculate the width needed for each column."""
    widths = [max(len(col.header), col.min_width) for col in columns]

    for row in rows:
        for i, col in enumerate(columns):
            value = row.get(col.key, "")
            if col.is_boolean:
                value_str = bool_to_symbol(bool(value))
            elif value is None:
                value_str = ""
            else:
                value_str = str(value)
            widths[i] = max(widths[i], len(value_str))

    return widths


def render_table(
    title: str,
    columns: list[Column],
    rows: list[dict[str, Any]],
    max_width: int = 120,
) -> str:
    """Render a table with box-drawing characters."""
    if not rows:
        return ""

    # Calculate column widths
    widths = calculate_column_widths(columns, rows)

    # Adjust widths if total exceeds max_width
    total_width = sum(widths) + len(widths) * 3 + 1  # Padding and borders
    if total_width > max_width:
        # Reduce notes column first (usually last)
        excess = total_width - max_width
        notes_idx = len(widths) - 1
        widths[notes_idx] = max(widths[notes_idx] - excess, 10)

    lines: list[str] = []

    # Add title
    lines.append(f"\n{title}")
    lines.append("")

    # Build separator lines
    def make_separator(left: str, mid: str, right: str) -> str:
        parts = [left]
        for i, w in enumerate(widths):
            parts.append(BOX_HORIZONTAL * (w + 2))
            if i < len(widths) - 1:
                parts.append(mid)
        parts.append(right)
        return "".join(parts)

    top_border = make_separator(BOX_TOP_LEFT, BOX_T_DOWN, BOX_TOP_RIGHT)
    header_separator = make_separator(BOX_T_RIGHT, BOX_CROSS, BOX_T_LEFT)
    bottom_border = make_separator(BOX_BOTTOM_LEFT, BOX_T_UP, BOX_BOTTOM_RIGHT)

    # Build row
    def make_row(values: list[str]) -> str:
        parts = [BOX_VERTICAL]
        for i, (value, width) in enumerate(zip(values, widths)):
            cell = truncate_str(value, width).ljust(width)
            parts.append(f" {cell} ")
            parts.append(BOX_VERTICAL)
        return "".join(parts)

    # Add top border
    lines.append(top_border)

    # Add header
    header_values = [col.header for col in columns]
    lines.append(make_row(header_values))
    lines.append(header_separator)

    # Add data rows
    for row in rows:
        values: list[str] = []
        for col in columns:
            value = row.get(col.key, "")
            if col.is_boolean:
                values.append(bool_to_symbol(bool(value)))
            elif value is None:
                values.append("")
            else:
                values.append(str(value))
        lines.append(make_row(values))

    # Add bottom border
    lines.append(bottom_border)

    return "\n".join(lines)


def render_plugin_dependency_table(
    title: str, dependencies: list[dict[str, Any]]
) -> str:
    """Render a table for plugin dependencies."""
    if not dependencies:
        return ""

    columns = [
        Column(header="plugin", key="plugin", min_width=8),
        Column(header="marketplace", key="marketplace", min_width=11),
        Column(header="dependent", key="dependent", min_width=9),
        Column(header="version", key="requiredVersion", min_width=7),
        Column(header="installed", key="installed", min_width=9, is_boolean=True),
        Column(header="enabled", key="enabled", min_width=7, is_boolean=True),
        Column(header="version", key="installedVersion", min_width=7),
        Column(header="valid", key="valid", min_width=5, is_boolean=True),
        Column(header="notes", key="notes", min_width=5),
    ]

    # Add notes to each row
    rows = []
    for dep in dependencies:
        row = dict(dep)
        row["notes"] = get_notes(dep, is_system=False)
        rows.append(row)

    return render_table(title, columns, rows)


def render_system_dependency_table(
    title: str, dependencies: list[dict[str, Any]]
) -> str:
    """Render a table for system dependencies."""
    if not dependencies:
        return ""

    columns = [
        Column(header="command", key="command", min_width=8),
        Column(header="dependent", key="dependent", min_width=9),
        Column(header="version", key="requiredVersion", min_width=7),
        Column(header="installed", key="installed", min_width=9, is_boolean=True),
        Column(header="version", key="installedVersion", min_width=7),
        Column(header="valid", key="valid", min_width=5, is_boolean=True),
        Column(header="notes", key="notes", min_width=5),
    ]

    # Add notes to each row
    rows = []
    for dep in dependencies:
        row = dict(dep)
        row["notes"] = get_notes(dep, is_system=True)
        rows.append(row)

    return render_table(title, columns, rows)


def render_dependency_results(data: dict[str, Any]) -> str:
    """Render all dependency check results as tables."""
    output_parts: list[str] = []

    # Render scope header
    scope = data.get("checkedScope", "unknown")
    checked_plugin = data.get("checkedPlugin")
    if checked_plugin:
        output_parts.append(f"Dependency check for plugin: {checked_plugin}")
    else:
        output_parts.append(f"Dependency check scope: {scope}")

    # Render plugin dependencies
    deps = data.get("dependencies", [])
    if deps:
        table = render_plugin_dependency_table("Required Plugin Dependencies", deps)
        if table:
            output_parts.append(table)

    # Render optional plugin dependencies
    opt_deps = data.get("optionalDependencies", [])
    if opt_deps:
        table = render_plugin_dependency_table("Optional Plugin Dependencies", opt_deps)
        if table:
            output_parts.append(table)

    # Render system dependencies
    sys_deps = data.get("systemDependencies", [])
    if sys_deps:
        table = render_system_dependency_table("Required System Dependencies", sys_deps)
        if table:
            output_parts.append(table)

    # Render optional system dependencies
    opt_sys_deps = data.get("optionalSystemDependencies", [])
    if opt_sys_deps:
        table = render_system_dependency_table(
            "Optional System Dependencies", opt_sys_deps
        )
        if table:
            output_parts.append(table)

    # If no tables rendered, show a message
    if len(output_parts) == 1:
        output_parts.append("\nNo dependencies found for checked plugins.")

    return "\n".join(output_parts)


def read_input(file_path: str | None = None) -> dict[str, Any]:
    """Read JSON input from file or stdin."""
    if file_path:
        path = Path(file_path)
        if not path.exists():
            print(f"Error: File not found: {file_path}", file=sys.stderr)
            sys.exit(1)
        content = path.read_text()
    else:
        # Read from stdin
        if sys.stdin.isatty():
            print("Error: No input provided. Pipe JSON or provide a file path.", file=sys.stderr)
            print("Usage: dependency-checker.py | table-renderer.py", file=sys.stderr)
            print("       table-renderer.py <file.json>", file=sys.stderr)
            sys.exit(1)
        content = sys.stdin.read()

    try:
        return json.loads(content)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)


def main() -> int:
    """Main entry point."""
    # Check for file argument
    file_path: str | None = None
    if len(sys.argv) > 1:
        arg = sys.argv[1]
        if arg in ("-h", "--help"):
            print(__doc__)
            return 0
        file_path = arg

    # Read and parse input
    data = read_input(file_path)

    # Render and print tables
    output = render_dependency_results(data)
    print(output)

    return 0


if __name__ == "__main__":
    sys.exit(main())
