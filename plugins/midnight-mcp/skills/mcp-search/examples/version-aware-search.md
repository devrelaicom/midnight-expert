# Version-Aware Search Examples

## When to Apply

When the user's project targets a specific Compact language version or SDK version, and results from other versions could be misleading or incorrect.

## Examples

### Compact Language Version from Pragma

**Before:**
```
Project has: pragma language_version 0.2.0;
User asks: "how to declare a witness"
Search: "witness declaration Compact"
→ Returns results from multiple language versions, some with outdated syntax
```

**After:**
```
Search: "witness declaration Compact language_version 0.2.0"
→ Bias toward results matching 0.2.0 syntax
After retrieval: deprioritize results showing pre-0.2.0 witness syntax
```

**Why:** Witness declaration syntax may have changed between language versions. Including the version in the query and filtering results by version prevents the user from seeing outdated syntax.

### SDK Version from package.json

**Before:**
```
package.json: "@midnight-ntwrk/midnight-js-contracts": "^2.0.0"
User asks: "how to deploy a contract"
Search: "deploy contract provider" on midnight-search-typescript
→ Returns results mixing SDK v1 and v2 patterns
```

**After:**
```
Search: "deploy contract provider v2" on midnight-search-typescript
After retrieval: deprioritize results with v1 import paths
  v1: import from "@midnight-ntwrk/compact-runtime" → deprioritize
  v2: import from "@midnight-ntwrk/midnight-js-contracts" → boost
```

**Why:** SDK v1 and v2 have different import paths and API patterns. Showing v1 patterns to a v2 user leads to import errors and API mismatches.

### Feature Availability by Version

**Before:**
```
User asks: "does Compact support generics"
Search: "generics Compact type parameters"
→ Results from mixed versions, unclear which version added the feature
```

**After:**
```
Search: "generics Compact type parameters language_version"
After retrieval: check version context of each result
→ Note to user: "Generic support depends on the Compact language version. Results show generics in language_version 0.2.0+. Check your pragma language_version to confirm availability."
```

**Why:** Feature availability is version-dependent. Without version context, the user might try to use a feature not available in their project's language version.

## Anti-Patterns

### Ignoring Version Context

**Wrong:**
```
Project uses Compact 0.28.x and SDK v2
→ Search without any version context
→ Present v1 patterns alongside v2 patterns
```

**Problem:** Mixing version results is confusing and may lead to incompatible code. Import paths, API signatures, and syntax change between major versions.

**Instead:** Always check environmental context for version information. Include version terms in queries and filter results by version compatibility.

### Being Overly Strict About Versions

**Wrong:**
```
Project uses Compact 0.28.0
→ Reject all results from 0.27.x and 0.28.1+
```

**Problem:** Minor version differences rarely change core patterns. A Counter usage pattern from 0.27.0 is almost certainly valid in 0.28.0. Being too strict eliminates useful results.

**Instead:** Be strict about major version differences (v1 vs v2 SDK, 0.1.x vs 0.2.x language). Be lenient about patch versions within the same minor version.

### Not Checking Environmental Context

**Wrong:**
```
User asks about version-sensitive syntax
→ Search without checking package.json or pragma language_version
→ Present results from all versions
```

**Problem:** Without environmental context, you cannot filter results by version. The user may implement patterns from the wrong version.

**Instead:** When version matters, check environmental context first. Read `package.json` and `*.compact` pragmas to determine the target version before searching.
