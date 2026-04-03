# midnight-plugin-utils

Audits and resolves Claude plugin dependencies -- validates installed plugins against extends-plugin.json declarations, scans plugin files for undeclared dependencies, and resolves installation paths with fuzzy matching.

## Skills

### midnight-plugin-utils:find-claude-plugin-root

Generates a Python resolver script at /tmp/cpr.py that locates a plugin's installation path by reading installed_plugins.json. Works around the known issue where `${CLAUDE_PLUGIN_ROOT}` does not expand in markdown files.

#### References

None. This skill is self-contained.

### midnight-plugin-utils:dependency-checker

Validates dependencies declared in extends-plugin.json files against the current environment. Checks whether required plugins are installed and enabled, whether system tools are available, and whether version constraints are satisfied. Companion scripts render ASCII tables and generate resolution steps.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| checker-output-schema.md | JSON schema for the dependency-checker.py output covering all four dependency categories | When parsing or interpreting checker output programmatically |
| extends-plugin-format.md | Format specification for extends-plugin.json from a validation perspective | When understanding how the checker reads and validates dependency declarations |

### midnight-plugin-utils:dependency-scanner

Scans plugin files for regex patterns indicating dependencies on other plugins or system tools, then builds an extends-plugin.json manifest through interactive confirmation. Outputs raw matches as JSON for LLM interpretation and user review.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| extends-plugin-schema.md | Schema for the extends-plugin.json file produced by the scanner workflow | When understanding the output format of the scanning process |
| scanner-output-format.md | JSON schema for each pattern match element in the scanner output array | When parsing or interpreting raw scanner output |
