import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCRIPT = join(__dirname, '..', 'redact-string.js');

function run(input, env = {}) {
  return spawnSync('node', [SCRIPT], {
    input,
    encoding: 'utf8',
    env: { ...process.env, ...env },
  });
}

describe('redact-string.js', () => {
  it('redacts an AKIA-shaped AWS access key', () => {
    const result = run('My access key is AKIA1234567890ABCDEF in the config.');
    assert.equal(result.status, 0, result.stderr);
    assert.ok(!result.stdout.includes('AKIA1234567890ABCDEF'));
    assert.ok(result.stdout.includes('[REDACTED-SECRET]'));
  });

  it('redacts an email address', () => {
    const result = run('Contact alice@example.com for help');
    assert.equal(result.status, 0);
    assert.ok(!result.stdout.includes('alice@example.com'));
    assert.ok(result.stdout.includes('[REDACTED-EMAIL]'));
  });

  it('does not perform shell expansion on stdin content', () => {
    // Critical: $HOME inside the input must NOT be expanded to /Users/<name>
    const input = 'Path: $HOME/secret/.env';
    const result = run(input, { HOME: '/Users/test' });
    assert.equal(result.status, 0);
    // The literal $HOME should still appear (or be redacted) but never expanded
    assert.ok(!result.stdout.includes('/Users/test/secret/.env'));
  });

  it('relativizes paths under project root', () => {
    const result = run('/repo/src/foo.js was changed', {
      PROJECT_ROOT: '/repo',
    });
    assert.equal(result.status, 0);
    assert.ok(result.stdout.includes('./src/foo.js'));
  });
});
