import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const FIXTURE_PATH = join(__dirname, 'fixtures', 'sample-session.jsonl');

const { parseJSONL } = await import(join(__dirname, '..', 'parse-session.js'));

describe('parser', () => {
  const ir = parseJSONL(FIXTURE_PATH);

  describe('metadata extraction', () => {
    it('extracts session ID', () => {
      assert.equal(ir.metadata.sessionId, 'test-session-001');
    });

    it('extracts session name from custom-title', () => {
      assert.equal(ir.metadata.sessionName, 'fix-auth-and-rate-limit');
    });

    it('extracts start and end timestamps', () => {
      assert.equal(ir.metadata.startTime, '2026-04-10T09:00:00.000Z');
      assert.equal(ir.metadata.endTime, '2026-04-10T09:11:31.000Z');
    });

    it('extracts project path from cwd', () => {
      assert.equal(ir.metadata.project, '/Users/testuser/Projects/myproject');
    });

    it('extracts initial git branch', () => {
      assert.equal(ir.metadata.gitBranch, 'main');
    });

    it('extracts Claude version', () => {
      assert.equal(ir.metadata.claudeVersion, '2.1.100');
    });

    it('extracts model name from first assistant message', () => {
      assert.equal(ir.metadata.model, 'claude-sonnet-4-20250514');
    });

    it('counts user and assistant messages correctly', () => {
      assert.equal(ir.metadata.totalUserMessages, 5);
      assert.equal(ir.metadata.totalAssistantMessages, 5);
    });
  });

  describe('section grouping', () => {
    it('groups messages into sections by user-turn + responses', () => {
      assert.equal(ir.sections.length, 2);
    });

    it('marks all sections as included by default', () => {
      assert.ok(ir.sections.every(s => s.included === true));
    });

    it('assigns sequential indices', () => {
      assert.deepEqual(ir.sections.map(s => s.index), [0, 1]);
    });

    it('first section starts with user prompt about auth', () => {
      const firstMsg = ir.sections[0].messages[0];
      assert.equal(firstMsg.type, 'user');
      assert.ok(firstMsg.content.includes('authentication bug'));
    });

    it('second section starts with user prompt about rate limiting', () => {
      const firstMsg = ir.sections[1].messages[0];
      assert.equal(firstMsg.type, 'user');
      assert.ok(firstMsg.content.includes('rate limiting'));
    });
  });

  describe('tool call extraction', () => {
    it('extracts tool calls from assistant messages', () => {
      const asst1 = ir.sections[0].messages.find(
        m => m.type === 'assistant' && m.toolCalls?.some(t => t.name === 'Read')
      );
      assert.ok(asst1, 'Should find assistant message with Read tool call');
      assert.equal(asst1.toolCalls[0].name, 'Read');
      assert.equal(asst1.toolCalls[0].input.file_path,
        '/Users/testuser/Projects/myproject/src/login.js');
    });

    it('pairs tool calls with their results', () => {
      const asst1 = ir.sections[0].messages.find(
        m => m.type === 'assistant' && m.toolCalls?.some(t => t.name === 'Read')
      );
      const readCall = asst1.toolCalls.find(t => t.name === 'Read');
      assert.ok(readCall.result, 'Read tool call should have a result');
      assert.ok(readCall.result.includes('const login'));
    });

    it('identifies Agent tool calls as subagent references', () => {
      const agentMsg = ir.sections[1].messages.find(
        m => m.type === 'assistant' && m.toolCalls?.some(t => t.name === 'Agent')
      );
      const agentCall = agentMsg.toolCalls.find(t => t.name === 'Agent');
      assert.equal(agentCall.name, 'Agent');
      assert.equal(agentCall.subagentId, 'subagent-001');
    });
  });

  describe('subagent tracking', () => {
    it('collects subagents at top level', () => {
      assert.equal(ir.subagents.length, 1);
      assert.equal(ir.subagents[0].id, 'subagent-001');
    });

    it('links subagent to calling message', () => {
      assert.equal(ir.subagents[0].calledFrom, 'asst-004');
    });

    it('captures subagent description', () => {
      assert.equal(ir.subagents[0].description, 'Research rate limiting patterns');
    });

    it('defaults subagent handling to null', () => {
      assert.equal(ir.subagents[0].handling, null);
    });
  });

  describe('attachment and noise filtering', () => {
    it('does not include raw attachment entries in sections', () => {
      const allMessages = ir.sections.flatMap(s => s.messages);
      assert.ok(allMessages.every(m => m.type !== 'attachment'));
    });

    it('does not include system entries in sections', () => {
      const allMessages = ir.sections.flatMap(s => s.messages);
      assert.ok(allMessages.every(m => m.type !== 'system'));
    });

    it('does not include file-history-snapshot in sections', () => {
      const allMessages = ir.sections.flatMap(s => s.messages);
      assert.ok(allMessages.every(m => m.type !== 'file-history-snapshot'));
    });
  });

  describe('robustness', () => {
    it('handles malformed trailing line gracefully', async () => {
      const { writeFileSync, unlinkSync } = await import('node:fs');
      const { tmpdir } = await import('node:os');
      const tmpFile = join(tmpdir(), `parser-test-${Date.now()}.jsonl`);
      const validLine = '{"type":"user","uuid":"u1","parentUuid":null,"isSidechain":false,"message":{"role":"user","content":"hello"},"timestamp":"2026-01-01T00:00:00.000Z","sessionId":"s1","cwd":"/tmp","version":"2.1.100","gitBranch":"main","userType":"external","entrypoint":"cli"}';
      writeFileSync(tmpFile, validLine + '\n' + '{"broken json');
      try {
        const result = parseJSONL(tmpFile);
        assert.equal(result.metadata.sessionId, 's1');
      } finally {
        unlinkSync(tmpFile);
      }
    });
  });
});
