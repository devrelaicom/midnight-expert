import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SCRIPT = join(__dirname, '..', 'list-recent-sessions.sh');

function makeFakeJsonl(sessionId, startTs, endTs, branch, firstPrompt) {
  return [
    JSON.stringify({ sessionId, type: 'user', content: firstPrompt, timestamp: startTs, gitBranch: branch }),
    JSON.stringify({ sessionId, type: 'assistant', content: [{ type: 'text', text: 'ok' }], timestamp: endTs }),
  ].join('\n') + '\n';
}

describe('list-recent-sessions.sh', () => {
  let tmpHome;
  let projectsDir;
  let projectKey;

  before(() => {
    tmpHome = mkdtempSync(join(tmpdir(), 'feedback-test-'));
    projectKey = '-fake-project-path';
    projectsDir = join(tmpHome, '.claude', 'projects', projectKey);
    mkdirSync(projectsDir, { recursive: true });

    writeFileSync(
      join(projectsDir, 'aaa.jsonl'),
      makeFakeJsonl('aaa', '2026-04-28T10:00:00Z', '2026-04-28T10:05:00Z', 'main', 'first session')
    );
    writeFileSync(
      join(projectsDir, 'bbb.jsonl'),
      makeFakeJsonl('bbb', '2026-04-29T11:00:00Z', '2026-04-29T11:30:00Z', 'feature', 'newer session prompt')
    );
  });

  after(() => {
    rmSync(tmpHome, { recursive: true, force: true });
  });

  it('lists sessions for the resolved project key in newest-first order', () => {
    const result = spawnSync('bash', [SCRIPT, '/fake/project/path'], {
      encoding: 'utf8',
      env: { ...process.env, HOME: tmpHome },
    });
    assert.equal(result.status, 0, `script exited ${result.status}: ${result.stderr}`);
    const sessions = JSON.parse(result.stdout);
    assert.ok(Array.isArray(sessions));
    assert.equal(sessions.length, 2);
    assert.equal(sessions[0].sessionId, 'bbb');
    assert.equal(sessions[1].sessionId, 'aaa');
  });

  it('returns an empty array when the project has no sessions', () => {
    const result = spawnSync('bash', [SCRIPT, '/no/such/project'], {
      encoding: 'utf8',
      env: { ...process.env, HOME: tmpHome },
    });
    assert.equal(result.status, 0);
    assert.deepEqual(JSON.parse(result.stdout), []);
  });

  it('each session has the required fields', () => {
    const result = spawnSync('bash', [SCRIPT, '/fake/project/path'], {
      encoding: 'utf8',
      env: { ...process.env, HOME: tmpHome },
    });
    const sessions = JSON.parse(result.stdout);
    for (const s of sessions) {
      for (const k of ['sessionId', 'startedAt', 'endedAt', 'gitBranch', 'firstUserPrompt']) {
        assert.ok(k in s, `session missing key ${k}`);
      }
    }
  });

  it('trims firstUserPrompt to <= 200 chars', () => {
    const longPrompt = 'a'.repeat(500);
    writeFileSync(
      join(projectsDir, 'ccc.jsonl'),
      makeFakeJsonl('ccc', '2026-04-29T12:00:00Z', '2026-04-29T12:05:00Z', 'main', longPrompt)
    );
    const result = spawnSync('bash', [SCRIPT, '/fake/project/path'], {
      encoding: 'utf8',
      env: { ...process.env, HOME: tmpHome },
    });
    const sessions = JSON.parse(result.stdout);
    const ccc = sessions.find(s => s.sessionId === 'ccc');
    assert.ok(ccc.firstUserPrompt.length <= 200);
  });
});
