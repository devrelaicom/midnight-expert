# NixOS Installation

Resolve installation issues when running Midnight Compact tools on NixOS.

## Fetch Current Guide

Fetch the latest NixOS installation guide from the Midnight docs repository:

```
githubGetFileContent(
  owner: "midnightntwrk",
  repo: "midnight-docs",
  path: "docs/troubleshoot/install-midnight-compact-tools-on-nixos.mdx",
  fullContent: true
)
```

Parse the fetched MDX content by stripping frontmatter, JSX imports, and component wrappers. Present the remaining markdown instructions to the user.

## Quick Fixes (if fetch is unavailable)

If the MCP tool is unavailable, try these common resolutions:

- Use `nix-shell` or `nix develop` to create an environment with the required dependencies (glibc, libstdc++, zlib)
- Use `patchelf --set-interpreter` to fix the dynamic linker path on the Compact CLI binary
- Add the Compact CLI binary location to your Nix shell's `buildInputs` or `packages`
- Check `ldd $(which compact)` to identify missing shared libraries

## Common NixOS-Specific Issues

- **Dynamic linking failures** - NixOS does not use the standard `/lib` or `/usr/lib` paths. Binaries that expect glibc at standard locations will fail. The guide covers patching or wrapping binaries with `patchelf` or using `nix-shell` / `nix develop` environments.
- **Missing shared libraries** - Tools compiled for standard Linux distributions may reference shared objects not present on NixOS. The guide documents which Nix packages provide the required libraries.
- **PATH and environment isolation** - NixOS shell environments may not inherit expected paths. Ensure the Compact CLI binary is accessible within the Nix environment being used.

## If the Guide Does Not Resolve the Issue

1. Search for NixOS-related open issues: `gh search issues "NixOS org:midnightntwrk" --state=open --limit=20 --sort=updated --json "title,url,updatedAt,commentsCount"`
2. Check if the Compact CLI version has known NixOS issues via `references/checking-release-notes.md`
