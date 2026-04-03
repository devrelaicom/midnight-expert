# midnight-expert

<p align="center">
  <img src="assets/mascot.png" alt="midnight-expert mascot" width="200" />
</p>

Meta-plugin for the midnight-expert marketplace. Provides comprehensive diagnostics and health reporting for the entire midnight-expert ecosystem -- plugin installation, MCP server connectivity, external CLI tools, cross-plugin references, and NPM registry access.

## Skills

### midnight-expert:doctor

Runs comprehensive diagnostics across the midnight-expert ecosystem. Launches five parallel diagnostic agents (plugin health, MCP servers, external tools, cross-plugin references, NPM registry) and produces a consolidated health report with actionable fixes. Supports `--auto-fix` mode to silently install missing dependencies. The skill directory contains diagnostic scripts that are executed by the sub-agents.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| fix-table.md | Maps diagnostic output to actionable fixes, including auto-fix classification for silent vs prompted resolution | When interpreting doctor results and determining how to resolve detected issues |
