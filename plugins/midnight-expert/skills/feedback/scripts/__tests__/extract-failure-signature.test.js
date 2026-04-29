import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const { extractFailureSignature } = await import(join(__dirname, '..', 'extract-failure-signature.js'));

// Helpers to build raw-JSONL-shaped entries
function userPrompt(uuid, content, parentUuid = null) {
  return {
    type: 'user',
    uuid,
    parentUuid,
    isMeta: false,
    message: { role: 'user', content },
    timestamp: '2026-04-29T10:00:00Z',
  };
}
function assistantToolUse(uuid, parentUuid, toolName, toolUseId, input) {
  return {
    type: 'assistant',
    uuid,
    parentUuid,
    message: {
      role: 'assistant',
      content: [{ type: 'tool_use', id: toolUseId, name: toolName, input }],
    },
    timestamp: '2026-04-29T10:00:01Z',
  };
}
function toolResult(uuid, parentUuid, toolUseId, text, isError = false) {
  return {
    type: 'user',
    uuid,
    parentUuid,
    message: {
      role: 'user',
      content: [
        {
          type: 'tool_result',
          tool_use_id: toolUseId,
          content: [{ type: 'text', text }],
          is_error: isError,
        },
      ],
    },
    timestamp: '2026-04-29T10:00:02Z',
  };
}

describe('extractFailureSignature', () => {
  it('returns empty signature for entries with no errors', () => {
    const sig = extractFailureSignature([
      userPrompt('u1', 'hello'),
      {
        type: 'assistant',
        uuid: 'a1',
        parentUuid: 'u1',
        message: { role: 'assistant', content: [{ type: 'text', text: 'hi' }] },
        timestamp: '2026-04-29T10:00:01Z',
      },
    ]);
    assert.deepEqual(sig.events, []);
    assert.deepEqual(sig.counts, { 'tool-error': 0, 'nonzero-exit': 0 });
  });

  it('detects a tool-error event from is_error=true', () => {
    const entries = [
      userPrompt('u1', 'compile it'),
      assistantToolUse('a1', 'u1', 'Bash', 'tu1', { command: 'compact compile' }),
      toolResult('u2', 'a1', 'tu1', 'bash: compact: command not found', true),
    ];
    const sig = extractFailureSignature(entries);
    assert.equal(sig.events.length, 1);
    assert.equal(sig.events[0].kind, 'tool-error');
    assert.equal(sig.events[0].tool, 'Bash');
    assert.equal(sig.counts['tool-error'], 1);
  });

  it('detects nonzero-exit from text patterns when is_error is not set', () => {
    const entries = [
      userPrompt('u1', 'run it'),
      assistantToolUse('a1', 'u1', 'Bash', 'tu1', { command: 'false' }),
      toolResult('u2', 'a1', 'tu1', 'Command exited with status 1', false),
    ];
    const sig = extractFailureSignature(entries);
    assert.equal(sig.counts['nonzero-exit'], 1);
    assert.equal(sig.events[0].kind, 'nonzero-exit');
  });

  it('extracts plugin namespace from Skill tool calls', () => {
    const entries = [
      userPrompt('u1', 'use it'),
      assistantToolUse('a1', 'u1', 'Skill', 'tu1', { skill: 'compact-core:basic-start' }),
      toolResult('u2', 'a1', 'tu1', 'failed', true),
    ];
    const sig = extractFailureSignature(entries);
    assert.equal(sig.events[0].plugin, 'compact-core');
  });

  it('plugin is null for Bash tool calls without a recognizable namespace', () => {
    const entries = [
      userPrompt('u1', 'run it'),
      assistantToolUse('a1', 'u1', 'Bash', 'tu1', { command: 'echo hi' }),
      toolResult('u2', 'a1', 'tu1', 'failed', true),
    ];
    const sig = extractFailureSignature(entries);
    assert.equal(sig.events[0].plugin, null);
  });

  it('messageIndex points to the tool_result entry, previousUserPromptIndex to the prior user prompt', () => {
    const entries = [
      userPrompt('u1', 'first prompt'),                                                   // 0
      {                                                                                   // 1
        type: 'assistant',
        uuid: 'a1',
        parentUuid: 'u1',
        message: { role: 'assistant', content: [{ type: 'text', text: 'ok' }] },
        timestamp: 't',
      },
      userPrompt('u2', 'second prompt'),                                                  // 2
      assistantToolUse('a2', 'u2', 'Bash', 'tu1', { command: 'x' }),                      // 3
      toolResult('u3', 'a2', 'tu1', 'fail', true),                                        // 4
    ];
    const sig = extractFailureSignature(entries);
    assert.equal(sig.events.length, 1);
    assert.equal(sig.events[0].messageIndex, 4);
    assert.equal(sig.events[0].previousUserPromptIndex, 2);
  });

  it('summary truncates long error content', () => {
    const longErr = 'x'.repeat(500);
    const entries = [
      userPrompt('u1', 'go'),
      assistantToolUse('a1', 'u1', 'Bash', 'tu1', { command: 'fail' }),
      toolResult('u2', 'a1', 'tu1', longErr, true),
    ];
    const sig = extractFailureSignature(entries);
    assert.ok(sig.events[0].summary.length <= 200);
  });

  it('handles tool_result content as a plain string (variant schema)', () => {
    const entries = [
      userPrompt('u1', 'go'),
      assistantToolUse('a1', 'u1', 'Bash', 'tu1', { command: 'fail' }),
      {
        type: 'user',
        uuid: 'u2',
        parentUuid: 'a1',
        message: {
          role: 'user',
          content: [
            { type: 'tool_result', tool_use_id: 'tu1', content: 'plain string error', is_error: true },
          ],
        },
        timestamp: 't',
      },
    ];
    const sig = extractFailureSignature(entries);
    assert.equal(sig.events.length, 1);
    assert.equal(sig.events[0].kind, 'tool-error');
    assert.ok(sig.events[0].summary.includes('plain string error'));
  });

  it('skips isMeta user prompts when tracking previousUserPromptIndex', () => {
    const entries = [
      { ...userPrompt('u1', 'system caveat'), isMeta: true },        // 0 (isMeta)
      userPrompt('u2', 'real prompt'),                                // 1
      assistantToolUse('a1', 'u2', 'Bash', 'tu1', { command: 'x' }), // 2
      toolResult('u3', 'a1', 'tu1', 'fail', true),                    // 3
    ];
    const sig = extractFailureSignature(entries);
    assert.equal(sig.events[0].previousUserPromptIndex, 1);
  });
});
