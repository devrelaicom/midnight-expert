# Utils Plugin

Utility skills for plugin management and diagnostics including dependency checking, scanning, and plugin root resolution.

## Skills

### find-claude-plugin-root

Resolves the root directory of a Claude plugin by traversing up the directory tree to find the `.claude-plugin` folder.

**Use cases:**
- Determine the plugin root from any nested directory
- Validate that a directory is within a valid plugin structure
- Get the path to plugin configuration files

### dependency-checker

Validates that all declared plugin dependencies are satisfied and installed.

**Use cases:**
- Verify a plugin's dependencies are available before use
- Check for missing or incompatible plugin versions
- Debug dependency resolution issues

### dependency-scanner

Scans plugin files for patterns indicating dependencies on other plugins or system tools, then builds an `extends-plugin.json` manifest through interactive confirmation.

**Use cases:**
- Generate an `extends-plugin.json` manifest for a plugin
- Audit what external skills, plugins, and CLI tools a plugin references
- Discover undeclared dependencies before distribution

## Plugin Dependencies Format

Plugins can declare dependencies on other plugins using an `extends-plugin.json` file in their `.claude-plugin` directory.

### extends-plugin.json

```json
{
  "dependencies": {
    "plugin-name": ">=1.0.0",
    "another-plugin": "^2.0.0"
  }
}
```

### Version Constraints

The following version constraint formats are supported:

- **Exact version**: `"1.0.0"` - Requires exactly version 1.0.0
- **Greater than or equal**: `">=1.0.0"` - Requires version 1.0.0 or higher
- **Caret range**: `"^1.0.0"` - Requires version compatible with 1.0.0 (same major version)
- **Tilde range**: `"~1.0.0"` - Requires version reasonably close to 1.0.0 (same major.minor version)
- **Any version**: `"*"` - Accepts any version

## Installation

This plugin is part of the aaronbassett-marketplace. Install it via:

```bash
claude plugin install utils
```

## License

MIT
