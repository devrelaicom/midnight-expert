# Environmental Grounding Examples

## When to Apply

When the user is working within a project that has Midnight dependencies or Compact source files, and the search would benefit from knowing the project's version context.

## Examples

### SDK Version from package.json

**Before:**
```
package.json: "@midnight-ntwrk/compact": "^0.28.0"
User query: "how to declare a ledger"
Search: "ledger declaration Compact"
```

**After:**
```
Search: "ledger declaration Compact language_version 0.28"
→ Bias results toward Compact 0.28.x syntax patterns
```

**Why:** Compact syntax can change between major versions. The `^0.28.0` dependency tells us the project uses 0.28.x, so results from other versions may show outdated or incompatible syntax.

### Language Version from Compact Pragma

**Before:**
```
*.compact file contains: pragma language_version 0.2.0;
User query: "how to use disclose"
Search: "disclose Compact"
```

**After:**
```
Search: "disclose Compact language_version 0.2.0"
→ Deprioritize results showing pre-0.2.0 disclose syntax
```

**Why:** The `pragma language_version` declaration is the most reliable version signal. The `disclose` construct behavior may differ between language versions.

### Local Development Network Context

**Before:**
```
Config file has endpoint: http://localhost:9944
User query: "how to connect to the network"
Search: "network connection provider"
```

**After:**
```
Search: "devnet local network provider localhost configuration"
→ Bias toward local development and devnet setup guides
```

**Why:** The `localhost:9944` endpoint indicates local development. The user needs devnet configuration, not testnet or mainnet deployment guides.

### Detecting OpenZeppelin Dependencies

**Before:**
```
package.json: "@openzeppelin/compact-contracts": "^1.0.0" and "@midnight-ntwrk/midnight-js-contracts": "^2.0.0"
User query: "how to add ownership to my contract"
Search: "ownership contract Compact"
```

**After:**
```
Search: "Ownable OpenZeppelin ownership contract access control"
→ Include OpenZeppelin patterns since the project already uses their libraries
```

**Why:** The project has OpenZeppelin as a dependency. The user likely wants to use `Ownable` from `@openzeppelin/compact-contracts` rather than implementing ownership from scratch.

## Anti-Patterns

### Reading package.json on Every Search

**Wrong:**
```
Every search call triggers: Read package.json → parse dependencies → extract versions
```

**Problem:** Reading `package.json` costs tokens and adds latency. The file rarely changes during a conversation session.

**Instead:** Read project context once at the start of the session or when the user mentions version concerns. Cache the result mentally for subsequent searches.

### Treating Version Ranges as Exact Versions

**Wrong:**
```
package.json: "@midnight-ntwrk/compact": "^0.28.0"
→ Restrict search to exactly version 0.28.0
```

**Problem:** `^0.28.0` means any 0.28.x version. Restricting to exactly 0.28.0 may miss results from 0.28.1 or 0.28.3 that are equally compatible.

**Instead:** Treat `^0.28.0` as "0.28.x family." Include results from the entire 0.28.x range.

### Ignoring Explicit User Version Context

**Wrong:**
```
package.json shows SDK v2.0.0
User asks: "how did this work in SDK v1?"
→ Filter results to v2.0.0 based on environmental context
```

**Problem:** The user is explicitly asking about v1, overriding the environmental context. Applying the v2 filter excludes exactly the results the user needs.

**Instead:** Environmental context is a default. When the user explicitly asks about a different version, their request takes priority.
