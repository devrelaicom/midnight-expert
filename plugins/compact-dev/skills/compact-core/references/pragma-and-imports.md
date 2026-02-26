---
title: Pragma Declaration and Import System
type: concept
description: Every Compact file must begin with a pragma version declaration, followed by imports that bring the standard library and other modules into scope.
links:
  - contract-file-layout
  - standard-library-functions
  - maybe-and-either-types
  - disclosure-model
  - export-and-visibility
---

# Pragma Declaration and Import System

The first line of every Compact file must be a pragma declaration. This is not optional — omitting it causes a compiler error. The pragma establishes which version of the Compact language the file targets, ensuring forward compatibility as the language evolves.

## Pragma Syntax

```compact
pragma language_version >= 0.18.0;
```

Use `>=` to accept the specified version and any compatible newer version. The current latest version is `0.18.0`. Using an exact version or an older format like `pragma language_version 0.16;` triggers a static analysis warning, and the [[contract-file-layout]] requires the pragma to be the very first statement.

## Import System

After the pragma, import statements bring external code into scope:

```compact
import CompactStandardLibrary;
```

This single import provides everything described in [[standard-library-functions]]: hashing functions, commitment primitives, [[maybe-and-either-types]], elliptic curve operations, and blockchain time functions. Almost every contract needs it because even basic operations like `disclose()` from the [[disclosure-model]] require it.

### Module Imports

Import from other Compact files to share code:

```compact
import "./shared-types.compact";
import "./utils.compact";
```

Imports bring named exports into scope. The imported file must have its own pragma declaration and can export circuits, types, and constants as described in [[export-and-visibility]].

### Include Files

The `include` directive performs textual substitution — it literally inserts the file's contents at the include point:

```compact
include "common-types.compact";
```

Include files differ from imports: they don't have their own scope, don't need a pragma, and can't selectively export. Use imports for modular code with clear boundaries; use includes for shared type definitions that multiple files need verbatim. The choice between the two affects how the [[contract-file-layout]] organizes multi-file projects.

## COMPACT_PATH Resolution

The compiler resolves imports using the `COMPACT_PATH` environment variable, which lists directories to search. This is relevant when a project has library dependencies or shared modules across multiple contracts. The path resolution order matters when two files have the same name in different directories.
