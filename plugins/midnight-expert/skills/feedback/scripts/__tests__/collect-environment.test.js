import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCRIPT = join(__dirname, '..', 'collect-environment.sh');

describe('collect-environment.sh', () => {
  it('outputs valid JSON with required top-level keys', () => {
    const result = spawnSync('bash', [SCRIPT], { encoding: 'utf8' });
    assert.equal(result.status, 0, `script exited ${result.status}: ${result.stderr}`);
    const parsed = JSON.parse(result.stdout);
    for (const key of ['marketplaceVersion', 'claudeCodeVersion', 'model', 'effort', 'os', 'plugins', 'tools']) {
      assert.ok(key in parsed, `missing key: ${key}`);
    }
  });

  it('os field is a non-empty string', () => {
    const result = spawnSync('bash', [SCRIPT], { encoding: 'utf8' });
    const parsed = JSON.parse(result.stdout);
    assert.equal(typeof parsed.os, 'string');
    assert.ok(parsed.os.length > 0);
  });

  it('tools.gh is a string when gh is installed, else null', () => {
    const result = spawnSync('bash', [SCRIPT], { encoding: 'utf8' });
    const parsed = JSON.parse(result.stdout);
    const ghInstalled = spawnSync('gh', ['--version'], { encoding: 'utf8' }).status === 0;
    if (ghInstalled) {
      assert.equal(typeof parsed.tools.gh, 'string');
    } else {
      assert.equal(parsed.tools.gh, null);
    }
  });

  it('tools.compact is a string when compact is installed, else null', () => {
    const result = spawnSync('bash', [SCRIPT], { encoding: 'utf8' });
    const parsed = JSON.parse(result.stdout);
    const compactInstalled = spawnSync('compact', ['--version'], { encoding: 'utf8' }).status === 0;
    if (compactInstalled) {
      assert.equal(typeof parsed.tools.compact, 'string');
    } else {
      assert.equal(parsed.tools.compact, null);
    }
  });

  it('model and effort are null (filled in by SKILL.md from session metadata)', () => {
    const result = spawnSync('bash', [SCRIPT], { encoding: 'utf8' });
    const parsed = JSON.parse(result.stdout);
    assert.equal(parsed.model, null);
    assert.equal(parsed.effort, null);
  });

  it('plugins is an object (possibly empty)', () => {
    const result = spawnSync('bash', [SCRIPT], { encoding: 'utf8' });
    const parsed = JSON.parse(result.stdout);
    assert.equal(typeof parsed.plugins, 'object');
    assert.ok(parsed.plugins !== null);
    assert.ok(!Array.isArray(parsed.plugins));
  });
});
