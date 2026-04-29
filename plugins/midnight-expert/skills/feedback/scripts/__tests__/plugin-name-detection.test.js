import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const { detectPluginCandidates } = await import(join(__dirname, '..', 'plugin-name-detection.js'));

const knownPlugins = [
  'compact-core',
  'compact-examples',
  'core-concepts',
  'midnight-tooling',
  'midnight-verify',
  'midnight-cq',
  'midnight-wallet',
  'midnight-fact-check',
  'midnight-expert',
];

function assistantToolUse(uuid, parentUuid, toolName, toolUseId, input) {
  return {
    type: 'assistant',
    uuid,
    parentUuid,
    message: {
      role: 'assistant',
      content: [{ type: 'tool_use', id: toolUseId, name: toolName, input }],
    },
    timestamp: 't',
  };
}

function toolResult(uuid, parentUuid, toolUseId, isError) {
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
          content: [{ type: 'text', text: 'result text' }],
          is_error: isError,
        },
      ],
    },
    timestamp: 't',
  };
}

describe('detectPluginCandidates', () => {
  it('extracts plugin slug mentioned by name in prose', () => {
    const r = detectPluginCandidates({
      prose: 'The compact-core skill keeps misfiring on me.',
      entries: [],
      knownPlugins,
    });
    assert.deepEqual(r.fromProse, ['compact-core']);
  });

  it('extracts plugin slug from a slash-command mention in prose', () => {
    const r = detectPluginCandidates({
      prose: 'I ran /midnight-tooling:devnet and it hung.',
      entries: [],
      knownPlugins,
    });
    assert.deepEqual(r.fromProse, ['midnight-tooling']);
  });

  it('returns empty fromProse when no known plugin appears in prose', () => {
    const r = detectPluginCandidates({
      prose: 'something is broken somewhere',
      entries: [],
      knownPlugins,
    });
    assert.deepEqual(r.fromProse, []);
  });

  it('extracts plugin from failing Skill tool calls', () => {
    const r = detectPluginCandidates({
      prose: '',
      entries: [
        assistantToolUse('a1', null, 'Skill', 'tu1', { skill: 'midnight-verify:verify' }),
        toolResult('u1', 'a1', 'tu1', true),
      ],
      knownPlugins,
    });
    assert.deepEqual(r.fromFailingTools, ['midnight-verify']);
  });

  it('returns activeInSession from ALL Skill tool calls, not just failing', () => {
    const r = detectPluginCandidates({
      prose: '',
      entries: [
        {
          type: 'assistant',
          uuid: 'a1',
          parentUuid: null,
          message: {
            role: 'assistant',
            content: [
              { type: 'tool_use', id: 'tu1', name: 'Skill', input: { skill: 'midnight-tooling:devnet' } },
              { type: 'tool_use', id: 'tu2', name: 'Skill', input: { skill: 'compact-core:basic-start' } },
            ],
          },
          timestamp: 't',
        },
        {
          type: 'user',
          uuid: 'u1',
          parentUuid: 'a1',
          message: {
            role: 'user',
            content: [
              { type: 'tool_result', tool_use_id: 'tu1', content: [{ type: 'text', text: 'ok' }], is_error: false },
              { type: 'tool_result', tool_use_id: 'tu2', content: [{ type: 'text', text: 'also ok' }], is_error: false },
            ],
          },
          timestamp: 't',
        },
      ],
      knownPlugins,
    });
    assert.ok(r.activeInSession.includes('midnight-tooling'));
    assert.ok(r.activeInSession.includes('compact-core'));
    assert.deepEqual(r.fromFailingTools, []);
  });

  it('deduplicates candidates within each list', () => {
    const r = detectPluginCandidates({
      prose: 'compact-core keeps failing in compact-core',
      entries: [],
      knownPlugins,
    });
    assert.deepEqual(r.fromProse, ['compact-core']);
  });

  it('ignores prose-mentioned strings that are not in knownPlugins', () => {
    const r = detectPluginCandidates({
      prose: 'imaginary-plugin is broken',
      entries: [],
      knownPlugins,
    });
    assert.deepEqual(r.fromProse, []);
  });

  it('case-insensitive prose match', () => {
    const r = detectPluginCandidates({
      prose: 'Compact-Core blew up',
      entries: [],
      knownPlugins,
    });
    assert.deepEqual(r.fromProse, ['compact-core']);
  });
});
