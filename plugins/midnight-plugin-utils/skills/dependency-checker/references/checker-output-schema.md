# Checker Output Schema

The `dependency-checker.py` script outputs a JSON object containing results for all four dependency categories.

## Top-Level Schema

| Field | Type | Description |
|-------|------|-------------|
| `checkedScope` | string | One of `"enabled"`, `"installed"`, or `"all"` |
| `checkedPlugin` | string or null | Plugin name if `--plugin` was used, otherwise `null` |
| `dependencies` | array | Required plugin dependency results |
| `optionalDependencies` | array | Optional plugin dependency results |
| `systemDependencies` | array | Required system dependency results |
| `optionalSystemDependencies` | array | Optional system dependency results |

## Plugin Dependency Entry Schema

Each entry in `dependencies` and `optionalDependencies`:

| Field | Type | Description |
|-------|------|-------------|
| `plugin` | string | Name of the required plugin |
| `marketplace` | string or null | Marketplace the plugin belongs to |
| `dependent` | string | Plugin that declared this dependency (format: `name@marketplace`) |
| `requiredVersion` | string | Version constraint from `extends-plugin.json` |
| `installed` | boolean | Whether the plugin is installed |
| `enabled` | boolean | Whether the plugin is enabled in settings |
| `installedVersion` | string or null | Installed version, or `null` if not installed |
| `valid` | boolean | Whether the dependency is fully satisfied |
| `help` | string | Human-readable guidance when `valid` is `false`, empty when `true` |

## System Dependency Entry Schema

Each entry in `systemDependencies` and `optionalSystemDependencies`:

| Field | Type | Description |
|-------|------|-------------|
| `command` | string | CLI command name (e.g., `gh`, `git`) |
| `dependent` | string | Plugin that declared this dependency |
| `requiredVersion` | string | Version constraint from `extends-plugin.json` |
| `installed` | boolean | Whether the command exists in `$PATH` |
| `enabled` | boolean | Same as `installed` (system commands have no enable/disable) |
| `installedVersion` | string or null | Detected version, or `null` if version detection failed |
| `valid` | boolean | Whether the dependency is fully satisfied |
| `help` | string | Human-readable guidance when `valid` is `false`, empty when `true` |

Note: System dependency entries use `command` instead of `plugin` and never include `marketplace`.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All required dependencies satisfied (optional failures do not affect exit code) |
| 1 | One or more required `dependencies` or `systemDependencies` entries have `valid: false` |

## Example Output

```json
{
  "checkedScope": "enabled",
  "checkedPlugin": null,
  "dependencies": [
    {
      "plugin": "midnight-plugin-utils",
      "marketplace": "aaronbassett-marketplace",
      "dependent": "my-plugin@aaronbassett-marketplace",
      "requiredVersion": "^0.1.0",
      "installed": true,
      "enabled": true,
      "installedVersion": "0.1.0",
      "valid": true,
      "help": ""
    },
    {
      "plugin": "missing-plugin",
      "marketplace": null,
      "dependent": "my-plugin@aaronbassett-marketplace",
      "requiredVersion": ">=1.0.0",
      "installed": false,
      "enabled": false,
      "installedVersion": null,
      "valid": false,
      "help": "Plugin missing-plugin is not installed. Install with: claude plugin install missing-plugin"
    }
  ],
  "optionalDependencies": [],
  "systemDependencies": [
    {
      "command": "gh",
      "dependent": "my-plugin@aaronbassett-marketplace",
      "requiredVersion": ">=2.0.0",
      "installed": true,
      "enabled": true,
      "installedVersion": "2.45.0",
      "valid": true,
      "help": ""
    }
  ],
  "optionalSystemDependencies": []
}
```
