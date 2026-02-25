# extends-plugin.json Schema

The scanner workflow produces an `extends-plugin.json` file that declares a plugin's dependencies on other plugins and system tools.

## File Location

```
<plugin-root>/.claude-plugin/extends-plugin.json
```

## Full Schema

```json
{
  "dependencies": {
    "<plugin-name>": "<version-constraint>",
    "<plugin-name>@<marketplace>": "<version-constraint>"
  },
  "optionalDependencies": {
    "<plugin-name>": "<version-constraint>"
  },
  "systemDependencies": {
    "<command>": "<version-constraint>"
  },
  "optionalSystemDependencies": {
    "<command>": "<version-constraint>"
  }
}
```

## Sections

| Section | Purpose | Failure Behavior |
|---------|---------|------------------|
| `dependencies` | Plugins that must be installed and enabled | Checker exits with code 1 if unsatisfied |
| `optionalDependencies` | Plugins that enhance functionality but are not required | Checker reports but exits with code 0 |
| `systemDependencies` | CLI tools that must be available in `$PATH` | Checker exits with code 1 if unsatisfied |
| `optionalSystemDependencies` | CLI tools that enhance functionality but are not required | Checker reports but exits with code 0 |

## Version Constraint Syntax

| Format | Syntax | Meaning |
|--------|--------|---------|
| Exact | `"1.0.0"` | Requires exactly version 1.0.0 |
| Caret | `"^1.2.0"` | Compatible with 1.x.x (same major, >= specified) |
| Tilde | `"~1.2.0"` | Compatible with 1.2.x (same major.minor, >= specified) |
| Greater-or-equal | `">=1.0.0"` | Version 1.0.0 or higher |
| Less-than | `"<2.0.0"` | Any version below 2.0.0 |
| Wildcard | `"*"` | Any version |

## Plugin Name Formats

- **Simple name**: `"utils"` - matches any plugin named "utils" regardless of marketplace
- **Qualified name**: `"utils@my-marketplace"` - matches only the "utils" plugin from "my-marketplace"

Use qualified names when multiple marketplaces provide plugins with the same name.

## Complete Example

```json
{
  "dependencies": {
    "midnight-plugin-utils@aaronbassett-marketplace": "^0.1.0",
    "devs@aaronbassett-marketplace": ">=0.1.0"
  },
  "optionalDependencies": {
    "superpowers@aaronbassett-marketplace": "*"
  },
  "systemDependencies": {
    "gh": ">=2.0.0",
    "git": ">=2.30.0"
  },
  "optionalSystemDependencies": {
    "jq": "*"
  }
}
```

This example declares:
- Required plugins: `midnight-plugin-utils` (caret ^0.1.0) and `devs` (>= 0.1.0)
- Optional plugin: `superpowers` (any version)
- Required system tools: `gh` (>= 2.0.0) and `git` (>= 2.30.0)
- Optional system tool: `jq` (any version)
