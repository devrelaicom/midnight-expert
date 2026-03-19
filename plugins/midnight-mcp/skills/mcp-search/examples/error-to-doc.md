# Error-to-Doc Search Examples

## When to Apply

When the user provides a compiler error, runtime error, or stack trace.

## Examples

### Compact Compiler Type Mismatch

**Before:**
```
Error: "Type mismatch: expected Bytes<32>, got Field"
Search: "Type mismatch: expected Bytes<32>, got Field" (full error message)
→ No exact match in the index
```

**After:**
```
Extracted key terms: Bytes, Field, type conversion
Search: "Bytes Field type conversion cast Compact" on midnight-search-compact
→ Results showing how to convert between Bytes and Field types
```

**Why:** The full error message including "expected" and "got" is compiler-specific text that will not appear in documentation or examples. The key terms (the types involved and the concept of conversion) are what matches indexed content.

### TypeScript Module Import Error

**Before:**
```
Error: "Cannot find module '@midnight-ntwrk/midnight-js-contracts'"
Search: "Cannot find module" on midnight-search-compact
→ No results — wrong tool and wrong search terms
```

**After:**
```
Extracted key terms: @midnight-ntwrk/midnight-js-contracts, module, import, installation
Search: "midnight-js-contracts import module installation" on midnight-search-typescript
Also: "midnight-js-contracts setup installation" on midnight-search-docs
→ Results showing correct installation and import patterns
```

**Why:** This is a JavaScript/Node.js error about a TypeScript package. Route to TypeScript search and documentation, not Compact search. Strip the generic "Cannot find module" prefix and search for the package name and setup terms.

### Node.js Directory Import Error

**Before:**
```
Error: "ERR_UNSUPPORTED_DIR_IMPORT"
Stack trace: at node:internal/modules/esm/resolve:283
Search: full stack trace pasted
→ No results
```

**After:**
```
Extracted key terms: ERR_UNSUPPORTED_DIR_IMPORT, module resolution
Search: "ERR_UNSUPPORTED_DIR_IMPORT module resolution" on midnight-search-docs
→ Results from troubleshooting guides about ESM module resolution
```

**Why:** Stack trace details (line numbers, internal Node.js paths) are not indexed. The error code itself (`ERR_UNSUPPORTED_DIR_IMPORT`) is the distinctive searchable term, combined with the concept ("module resolution").

### Compact Undeclared Identifier

**Before:**
```
Error: "Undeclared identifier: myFunction at line 42 in contract.compact"
Search: "Undeclared identifier: myFunction"
→ No results — "myFunction" is user-specific
```

**After:**
```
Extracted key terms: undeclared identifier, import, module (stripped user-specific name)
Search: "undeclared identifier import module Compact" on midnight-search-compact
Also: "Compact import module declaration" on midnight-search-docs
→ Results showing how to properly import and declare identifiers
```

**Why:** The specific identifier name `myFunction` is user-specific and will not appear in any indexed content. The pattern "undeclared identifier" combined with "import" and "module" matches documentation about import resolution.

## Anti-Patterns

### Searching for the Full Error Message with Line Numbers

**Wrong:**
```
Search: "Type mismatch: expected Bytes<32>, got Field at line 42 in /Users/dev/project/contract.compact"
```

**Problem:** Line numbers and file paths are unique to the user's project. No indexed content will match these details. The search engine tries to match the entire string and finds nothing.

**Instead:** Strip file paths, line numbers, and user-specific identifiers. Keep only the error type, involved types, and concept terms.

### Searching for Just the Error Code Without Context

**Wrong:**
```
Search: "ERR_UNSUPPORTED_DIR_IMPORT"
→ Maybe 1 result, not enough context to be useful
```

**Problem:** Error codes alone are too narrow. They may appear in one troubleshooting page but miss related guidance about the underlying issue (module resolution configuration).

**Instead:** Combine the error code with concept terms: `ERR_UNSUPPORTED_DIR_IMPORT module resolution ESM configuration`.

### Using midnight-search-compact for Runtime JavaScript Errors

**Wrong:**
```
JavaScript runtime error about module imports
→ Search midnight-search-compact
```

**Problem:** Compact code search indexes Compact source code, not JavaScript/TypeScript runtime behavior. Runtime import errors are JavaScript ecosystem issues.

**Instead:** Use `midnight-search-typescript` for SDK-related errors and `midnight-search-docs` for setup/configuration errors.
