# Biome Configuration Reference

## The Biome-Only Rule

Midnight projects use Biome as the single tool for linting, formatting, and import sorting. Never install ESLint or Prettier alongside Biome. If either tool is detected in a project, migrate its configuration to Biome and remove it completely before proceeding.

This is non-negotiable. Two formatters will fight. Two linters will disagree. One tool, one config, zero drift.

## Migration Procedure

If ESLint or Prettier already exists in the project, migrate before scaffolding.

### Step 1 -- Run the Biome migration CLI

```bash
# Migrate ESLint rules (includes "inspired" rules that approximate ESLint behavior)
npx @biomejs/biome migrate eslint --write --include-inspired

# Migrate Prettier formatting settings
npx @biomejs/biome migrate prettier --write
```

### Step 2 -- Delete legacy config files

Remove every file matching these patterns:

- `.eslintrc` / `.eslintrc.js` / `.eslintrc.cjs` / `.eslintrc.json` / `.eslintrc.yaml` / `.eslintrc.yml`
- `eslint.config.js` / `eslint.config.mjs` / `eslint.config.cjs` (flat config)
- `.eslintignore`
- `.prettierrc` / `.prettierrc.js` / `.prettierrc.cjs` / `.prettierrc.json` / `.prettierrc.yaml` / `.prettierrc.yml`
- `.prettierignore`

### Step 3 -- Remove packages

Uninstall all of these from `package.json` (both `dependencies` and `devDependencies`):

- `eslint` and every `eslint-*` package (`eslint-plugin-*`, `eslint-config-*`)
- `@typescript-eslint/eslint-plugin`, `@typescript-eslint/parser`, and any other `@typescript-eslint/*` packages
- `prettier` and every `prettier-plugin-*` / `prettier*` package

### Step 4 -- Remove scripts

Delete any `package.json` scripts that reference `eslint` or `prettier`. Replace them with Biome equivalents:

```jsonc
{
  "scripts": {
    "fmt-and-lint": "biome check . --changed",
    "fmt-and-lint:fix": "biome check . --changed --write",
    "fmt-and-lint:ci": "biome ci . --changed --no-errors-on-unmatched"
  }
}
```

### Migration Limitations

| Limitation | What to do |
|------------|------------|
| YAML ESLint configs (`.eslintrc.yaml`, `.eslintrc.yml`) | The Biome CLI cannot parse YAML. Convert the YAML to JSON manually first, then run the migration. |
| Some ESLint rule options do not map 1:1 | Review the migrated `biome.json` and close gaps with code review. Log any rules that could not be migrated. |
| `eslint-disable` comments in source | Convert to `biome-ignore` format or remove if the rule no longer applies after migration. |
| Prettier `overrides` per file glob | Reproduce manually in the Biome `overrides` array. |

## Complete Midnight biome.json

This is the ready-to-use Biome config for Midnight projects. It is based on the OpenZeppelin compact-contracts reference implementation.

```jsonc
{
  "$schema": "https://biomejs.dev/schemas/2.3.8/schema.json",

  // --- VCS integration ---
  "vcs": {
    "enabled": true,
    "clientKind": "git",
    "useIgnoreFile": true,
    "defaultBranch": "main"
  },

  // --- File handling ---
  "files": {
    "ignoreUnknown": true,
    "includes": [
      "**",
      "!**/tsconfig*.json",     // TypeScript config files have trailing commas biome flags
      "!**/*.compact",           // Compact source files are not JS/TS
      "!**/artifacts/**/*",      // Compact compiler output
      "!**/test-artifacts/**/*", // Test-specific compiler output
      "!**/coverage/**/*",       // Test coverage reports
      "!**/dist/**/*",           // Build output
      "!**/reports/**/*"         // CI/test reports
    ]
  },

  // --- Formatter ---
  "formatter": {
    "enabled": true,
    "indentStyle": "space",
    "includes": ["**"]
  },

  // --- Import sorting ---
  "assist": {
    "actions": {
      "source": {
        "organizeImports": "on"  // Auto-sort imports on format
      }
    }
  },

  // --- Linter ---
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true,

      "correctness": {
        // Dead code: unused variables indicate logic errors or incomplete refactors
        "noUnusedVariables": "error",
        // Dead imports: unused imports bloat bundles and confuse readers
        "noUnusedImports": "error"
      },

      "performance": {
        // Barrel files re-export everything, defeating tree-shaking
        "noBarrelFile": "error",
        // Wildcard re-exports have the same tree-shaking problem
        "noReExportAll": "error"
      },

      "style": {
        // Reassigning parameters hides mutations and breaks caller expectations
        "noParameterAssign": "error",
        // `as const` is safer than manual literal types
        "useAsConstAssertion": "error",
        // Default params at the end so callers can omit them naturally
        "useDefaultParameterLast": "error",
        // Self-closing tags are shorter and signal "no children"
        "useSelfClosingElements": "error",
        // One declaration per statement prevents comma-separated var confusion
        "useSingleVarDeclarator": "error",
        // Template literals without expressions should be plain strings
        "noUnusedTemplateLiteral": "error",
        // Use Number.parseInt/Number.isNaN over globals for clarity
        "useNumberNamespace": "error",
        // Explicit types that match the initializer are noise
        "noInferrableTypes": "error",
        // Else after return/throw/continue is dead code
        "noUselessElse": "error",
        // Consistent array types: prefer T[] shorthand over Array<T>
        "useConsistentArrayType": {
          "level": "error",
          "options": {
            "syntax": "shorthand"
          }
        }
      },

      "suspicious": {
        // Every Error/throw must include a message for debuggability
        "useErrorMessage": "error",
        // Ban console methods except console.log (allow intentional output)
        "noConsole": {
          "level": "error",
          "options": {
            "allow": ["log"]
          }
        }
      }
    }
  },

  // --- JavaScript/TypeScript formatter ---
  "javascript": {
    "formatter": {
      "quoteStyle": "single",      // Single quotes everywhere
      "semicolons": "always",      // Explicit semicolons prevent ASI surprises
      "indentStyle": "space",      // Spaces, not tabs
      "lineWidth": 100             // 100 chars per line
    }
  }
}
```

## Biome Overrides

Use the `overrides` array when certain file contexts need different rules. Add this inside the top-level `biome.json` object:

```jsonc
{
  "overrides": [
    {
      // Test files may legitimately use console for debugging and have unused vars in setup
      "includes": ["**/*.test.ts", "**/*.spec.ts", "**/test/**"],
      "linter": {
        "rules": {
          "suspicious": {
            "noConsole": "off"
          }
        }
      }
    },
    {
      // Config files often use default exports and CommonJS patterns
      "includes": ["*.config.ts", "*.config.js", "*.config.mjs"],
      "linter": {
        "rules": {
          "performance": {
            "noBarrelFile": "off",
            "noReExportAll": "off"
          }
        }
      }
    },
    {
      // Script files may need console output
      "includes": ["scripts/**"],
      "linter": {
        "rules": {
          "suspicious": {
            "noConsole": "off"
          }
        }
      }
    }
  ]
}
```

Not every project needs overrides. Start without them and add overrides only when a specific file context genuinely requires different rules.

## .editorconfig

Place this at the project root so editors that do not integrate with Biome still produce consistent formatting.

```ini
root = true

[*]
charset = utf-8
indent_style = space
indent_size = 2
end_of_line = lf
trim_trailing_whitespace = true
insert_final_newline = true

# Trailing spaces in markdown indicate line breaks (two-space word wrap)
[*.md]
trim_trailing_whitespace = false
max_line_length = 80

[*.ts]
max_line_length = 100
```
