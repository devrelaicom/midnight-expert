#!/usr/bin/env tsx
// Dev mode — uses ts-node for live reloading
import { execute } from "@oclif/core";

await execute({ development: true, dir: import.meta.url });
