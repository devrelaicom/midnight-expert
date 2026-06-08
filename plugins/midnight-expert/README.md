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
| [fix-table.md](skills/doctor/references/fix-table.md) | Maps diagnostic output to actionable fixes, including auto-fix classification for silent vs prompted resolution | When interpreting doctor results and determining how to resolve detected issues |

## Hooks

### UserPromptSubmit

On every user prompt, drains the top-level `on_next_user_prompt` array in `~/.midnight-expert/settings.local.json` and surfaces its formatted contents as additional context for that turn. Each entry is an object with a `type` discriminator; the hook formats known types and silently skips unknown ones (forward-compat).

Currently consumed: `compact-not-compiled` entries written by the `compact-core` Stop hook when it detected unchecked Compact contracts but couldn't block (Stop reattempt, or cooldown still active). The format names the contract paths and asks the agent to compile / verify them before treating any related claim as confirmed.

The hook always exits 0; it never blocks prompt submission.
