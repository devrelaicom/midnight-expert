#!/usr/bin/env node
// Read text from stdin, apply string-level redaction, write to stdout.
// Used by issue-flow.md Step 5 to redact evidence card content safely
// (without shell variable expansion mid-pipe).

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const { redactPII, redactSecrets, relativizePaths } = await import(join(__dirname, 'redactor.js'));

const stdin = readFileSync(0, 'utf8');

let out = redactPII(stdin, {
  gitUserName: process.env.GIT_USER_NAME || '',
  gitUserEmail: process.env.GIT_USER_EMAIL || '',
});
out = redactSecrets(out);
out = relativizePaths(out, {
  homeDir: process.env.HOME || '',
  projectRoot: process.env.PROJECT_ROOT || process.cwd(),
});

process.stdout.write(out);
