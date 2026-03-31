# Archive Compilation Workflow

## When to Use

Compiling multi-file Compact projects where source files import from each other, or when linking OpenZeppelin library modules.

## The `files` Parameter

A Record mapping relative file paths to source code. The directory structure in the keys is preserved so that import resolution works correctly.

## Example — Multi-File Project

```
Call: midnight-compile-archive({
  files: {
    "src/main.compact": "pragma language_version >= 0.22;\nimport \"./lib/token.compact\";\n...",
    "src/lib/token.compact": "pragma language_version >= 0.22;\nimport CompactStandardLibrary;\n..."
  },
  options: { skipZk: true }
})
```

## OpenZeppelin Library Linking

To use OZ Compact modules, pass them via `options.libraries`:

```
Call: midnight-compile-archive({
  files: {
    "src/main.compact": "pragma language_version >= 0.22;\nimport \"access/Ownable\";\n..."
  },
  options: {
    skipZk: true,
    libraries: ["access/Ownable"]
  }
})
```

### Available OZ Domains and Modules

| Domain | Example Modules |
|--------|----------------|
| `access` | `Ownable`, `AccessControl` |
| `security` | `Initializable`, `Pausable` |
| `token` | `FungibleToken`, `Transferable` |
| `utils` | `Utils` |

Format: `"domain/ModuleName"`. Max 20 libraries per request. Transitive cross-domain dependencies are resolved automatically — if `Ownable` imports from `utils`, the `utils` domain is linked automatically.

## When to Use Archive vs Single-File

- Use `midnight-compile-archive` when: your code has `import "./other.compact"` statements, you're using OZ modules, or the project is split across multiple files
- Use `midnight-compile-contract` when: it's a single self-contained file or snippet with no external imports (stdlib import is handled by auto-wrapping)

## Rate Limit

10 requests per 60 seconds (stricter than single-file compile at 20/60s). Budget accordingly.

## Multi-Version Support

Archive compilation also supports `version` and `versions` parameters. Same behavior as single-file: `"detect"` resolves from pragma, `"latest"` uses newest compiler, or specify a version string.
