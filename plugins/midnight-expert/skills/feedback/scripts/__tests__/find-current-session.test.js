import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, mkdirSync, rmSync, utimesSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCRIPT = join(__dirname, '..', 'find-current-session.sh');

describe('find-current-session.sh', () => {
  let tmpHome;
  let projectsDir;

  before(() => {
    tmpHome = mkdtempSync(join(tmpdir(), 'find-session-test-'));
    projectsDir = join(tmpHome, '.claude', 'projects', '-fake-project');
    mkdirSync(projectsDir, { recursive: true });

    const oldPath = join(projectsDir, 'older.jsonl');
    const newPath = join(projectsDir, 'newer.jsonl');
    writeFileSync(oldPath, 'a\n');
    writeFileSync(newPath, 'b\n');
    // Make older older by 100 seconds.
    const now = Date.now() / 1000;
    utimesSync(oldPath, now - 100, now - 100);
    utimesSync(newPath, now, now);
  });

  after(() => {
    rmSync(tmpHome, { recursive: true, force: true });
  });

  it('prints the path to the newest jsonl in the resolved project dir', () => {
    const result = spawnSync('bash', [SCRIPT, '/fake/project'], {
      encoding: 'utf8',
      env: { ...process.env, HOME: tmpHome },
    });
    assert.equal(result.status, 0);
    assert.ok(result.stdout.trim().endsWith('newer.jsonl'));
  });

  it('prints empty string and exits 0 when sessions dir does not exist', () => {
    const result = spawnSync('bash', [SCRIPT, '/no/such/project'], {
      encoding: 'utf8',
      env: { ...process.env, HOME: tmpHome },
    });
    assert.equal(result.status, 0);
    assert.equal(result.stdout, '');
  });

  it('prints empty string when sessions dir exists but has no jsonl', () => {
    const emptyProject = '-empty-project';
    mkdirSync(join(tmpHome, '.claude', 'projects', emptyProject), { recursive: true });
    const result = spawnSync('bash', [SCRIPT, '/empty/project'], {
      encoding: 'utf8',
      env: { ...process.env, HOME: tmpHome },
    });
    assert.equal(result.status, 0);
    assert.equal(result.stdout, '');
  });
});
