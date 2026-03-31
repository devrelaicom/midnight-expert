# Vite Configuration

The Midnight SDK was designed for Node.js and requires significant Vite
configuration to work in the browser. This reference documents every required
plugin, polyfill, and configuration option.

## Full Annotated vite.config.ts

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import wasm from 'vite-plugin-wasm';
import topLevelAwait from 'vite-plugin-top-level-await';
import { nodePolyfills } from 'vite-plugin-node-polyfills';
import commonjs from '@originjs/vite-plugin-commonjs';
import path from 'path';

export default defineConfig({
  plugins: [
    // React Fast Refresh and JSX transform
    react(),

    // Tailwind v4 — CSS-based configuration, no tailwind.config.js needed
    tailwindcss(),

    // WASM support — Midnight SDK uses WebAssembly for ZK circuit execution
    wasm(),

    // Top-level await — required by some SDK modules that await at module scope
    topLevelAwait(),

    // Node.js polyfills — SDK packages depend on Node.js built-in modules
    nodePolyfills({
      include: ['buffer', 'process', 'util', 'crypto', 'stream'],
      globals: {
        Buffer: true,
        process: true,
      },
    }),

    // CommonJS interop — some SDK packages are not ESM-compatible
    commonjs(),
  ],

  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },

  build: {
    target: 'esnext',
    minify: false, // Disable in development for readable stack traces
  },

  optimizeDeps: {
    exclude: ['@midnight-ntwrk/*'],
  },
});
```

## Plugin Explanations

### @vitejs/plugin-react

Standard React plugin providing Fast Refresh (hot module replacement) and
JSX transform. No special configuration needed for Midnight.

### @tailwindcss/vite

Tailwind v4 uses a Vite plugin instead of PostCSS. This is a breaking change
from Tailwind v3. With this plugin:

- No `tailwind.config.js` is needed
- No `postcss.config.js` is needed
- Configuration is done in CSS using `@theme` directives

### vite-plugin-wasm

Midnight SDK uses WebAssembly for zero-knowledge circuit execution. The WASM
modules are loaded at runtime in the browser. Without this plugin, Vite
cannot process `.wasm` imports and the SDK fails to initialize.

The plugin configures Vite to handle WASM modules as ES module imports,
enabling the SDK's cryptographic operations to run in the browser.

### vite-plugin-top-level-await

Some SDK modules use top-level `await` to initialize WASM modules and
cryptographic primitives. Standard Vite builds do not support top-level
await in all output formats. This plugin transforms top-level await
statements to be compatible with the build target.

### vite-plugin-node-polyfills

The Midnight SDK was built for Node.js and uses built-in modules that do not
exist in the browser. This plugin provides browser-compatible polyfills for:

- **buffer** — Binary data handling used by the SDK's serialization layer
- **process** — Environment detection and `process.env` references
- **util** — Utility functions (TextEncoder, TextDecoder, inspect)
- **crypto** — Cryptographic operations (hashing, random bytes)
- **stream** — Stream processing used by some SDK internals

The `globals` option ensures `Buffer` and `process` are available globally,
matching Node.js behavior that the SDK expects.

### @originjs/vite-plugin-commonjs

Some Midnight SDK packages are published as CommonJS modules rather than
ES modules. Vite's native CommonJS handling does not cover all edge cases
in the SDK's dependency tree. This plugin provides more robust CommonJS-to-ESM
conversion, resolving `require()` calls and `module.exports` patterns that
the SDK uses.

## Tailwind v4 CSS Setup

Tailwind v4 moves configuration from JavaScript to CSS. The main stylesheet
needs only:

```css
@import "tailwindcss";
```

This single import replaces the v3 `@tailwind base`, `@tailwind components`,
and `@tailwind utilities` directives.

### Theme Customization

Customize the theme using `@theme` in CSS:

```css
@import "tailwindcss";

@theme {
  --color-midnight: #1a1a2e;
  --color-accent: #e94560;
  --font-sans: "Inter", sans-serif;
}
```

### shadcn components.json

For shadcn with Tailwind v4, the components.json configuration uses the
CSS variable approach:

```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "default",
  "rsc": false,
  "tsx": true,
  "tailwind": {
    "config": "",
    "css": "src/index.css",
    "baseColor": "neutral",
    "cssVariables": true
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils",
    "ui": "@/components/ui",
    "lib": "@/lib",
    "hooks": "@/hooks"
  },
  "iconLibrary": "lucide"
}
```

Note `"config": ""` — Tailwind v4 does not use a config file, so this is
left empty. The `css` field points to the stylesheet containing
`@import "tailwindcss"`.

## Path Alias Configuration

The `@` alias maps to `./src` for clean imports. This must be configured in
both Vite and TypeScript:

**vite.config.ts:**
```typescript
resolve: {
  alias: {
    '@': path.resolve(__dirname, './src'),
  },
},
```

**tsconfig.json (or tsconfig.app.json):**
```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}
```

Both configurations must agree. If they diverge, Vite resolves imports
correctly at runtime but TypeScript reports errors in the editor.

## Build Target

The `esnext` build target enables all modern JavaScript features including
top-level await, private class fields, and logical assignment operators.
Midnight DApps target Chrome (required for the Lace extension), so there
is no need for transpilation to older standards.

Minification is disabled (`minify: false`) in development to preserve
readable stack traces. In production builds, set `minify: true` or remove
the option to enable Vite's default minification.

## optimizeDeps

The `optimizeDeps.exclude` array tells Vite's dependency pre-bundling to
skip Midnight SDK packages. Pre-bundling can interfere with the SDK's WASM
loading and internal module resolution. Excluding `@midnight-ntwrk/*`
prevents these issues.

## vitest.config.ts

Tests need a separate configuration because the test environment differs
significantly from the build environment:

```typescript
import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
    include: ['src/**/*.test.{ts,tsx}'],
    css: false,
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
```

Key differences from vite.config.ts:

- **No Tailwind plugin** — Tests do not need CSS processing
- **No WASM plugin** — SDK modules are mocked in tests
- **No CommonJS plugin** — Test dependencies are ESM-compatible
- **No node polyfills** — jsdom provides its own Node.js globals
- **jsdom environment** — Provides DOM APIs for component testing
- **css: false** — Avoids parsing CSS imports in test files

The path alias must be duplicated here because Vitest uses its own module
resolution pipeline.

## Common Issues

### WASM Loading Failures

**Symptom:** `CompileError: WebAssembly.instantiate()` or
`TypeError: Failed to fetch` when loading SDK modules.

**Cause:** Missing `vite-plugin-wasm` or incorrect `optimizeDeps` configuration.

**Fix:** Ensure `wasm()` is in the plugins array and `@midnight-ntwrk/*` is
in `optimizeDeps.exclude`.

### Missing Polyfills

**Symptom:** `ReferenceError: Buffer is not defined` or
`ReferenceError: process is not defined`.

**Cause:** SDK code references Node.js globals that are not available in the
browser.

**Fix:** Verify `nodePolyfills` includes all required modules and that
`globals.Buffer` and `globals.process` are set to `true`.

### CommonJS Interop Errors

**Symptom:** `SyntaxError: Named export 'X' not found` or
`Error: require is not defined`.

**Cause:** SDK package uses `module.exports` or `require()` and Vite's
default CJS handling does not convert it correctly.

**Fix:** Ensure `commonjs()` plugin is included. If specific packages still
fail, add them to `optimizeDeps.include` to force pre-bundling with CJS
conversion.

### Tailwind v4 Styles Not Applied

**Symptom:** Components render without any styling.

**Cause:** Using v3-style `@tailwind` directives or a `tailwind.config.js`
instead of the v4 CSS-based approach.

**Fix:** Replace all `@tailwind` directives with `@import "tailwindcss"` in
your main CSS file. Remove `tailwind.config.js` and `postcss.config.js` if
they exist. Ensure `@tailwindcss/vite` is in the plugins array.
