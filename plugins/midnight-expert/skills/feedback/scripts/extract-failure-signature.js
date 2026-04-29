import { readFileSync } from 'node:fs';

/**
 * Walk an array of raw Claude Code JSONL entries and return a failure signature.
 *
 * @param {object[]} entries - Parsed JSONL entries (one object per line).
 * @returns {{ events: object[], counts: object }}
 */
export function extractFailureSignature(entries) {
  // Only kinds we currently detect. hook-event and exception will be added when
  // we have concrete patterns; emitting them as 0 today is a false promise.
  const counts = { 'tool-error': 0, 'nonzero-exit': 0 };
  const events = [];

  // Map tool_use_id -> { messageIndex, tool, plugin }
  const toolUseMeta = new Map();
  let lastUserPromptIdx = null;

  for (let i = 0; i < entries.length; i++) {
    const entry = entries[i];
    if (!entry || typeof entry !== 'object') continue;

    // Track the most recent non-meta user prompt with string content.
    if (entry.type === 'user' && entry.isMeta !== true) {
      const c = entry.message?.content;
      if (typeof c === 'string') {
        lastUserPromptIdx = i;
        continue;
      }
    }

    // Record tool_use blocks emitted by assistant.
    if (entry.type === 'assistant' && Array.isArray(entry.message?.content)) {
      for (const block of entry.message.content) {
        if (block.type === 'tool_use') {
          toolUseMeta.set(block.id, {
            messageIndex: i,
            tool: block.name,
            plugin: pluginFromBlock(block),
          });
        }
      }
      continue;
    }

    // Inspect tool_result blocks in user-content arrays.
    if (entry.type === 'user' && Array.isArray(entry.message?.content)) {
      for (const block of entry.message.content) {
        if (block.type !== 'tool_result') continue;

        const text = extractToolResultText(block.content);
        let kind = null;

        if (block.is_error === true) {
          kind = 'tool-error';
        } else if (looksLikeNonzeroExit(text)) {
          kind = 'nonzero-exit';
        }

        if (!kind) continue;

        const meta = toolUseMeta.get(block.tool_use_id) || { tool: null, plugin: null };

        events.push({
          kind,
          timestamp: entry.timestamp || null,
          tool: meta.tool,
          plugin: meta.plugin,
          summary: truncate(stripNoise(text), 200),
          messageIndex: i,
          previousUserPromptIndex: lastUserPromptIdx,
        });
        counts[kind]++;
      }
    }
  }

  return { events, counts };
}

function pluginFromBlock(block) {
  if (block.name === 'Skill' && block.input && typeof block.input.skill === 'string') {
    const colon = block.input.skill.indexOf(':');
    if (colon > 0) return block.input.skill.slice(0, colon);
  }
  if (block.input && typeof block.input.command === 'string') {
    const m = block.input.command.match(/^\/([a-z0-9_-]+):/i);
    if (m) return m[1];
  }
  return null;
}

function extractToolResultText(content) {
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) {
    return content
      .filter(c => c && typeof c === 'object' && c.type === 'text' && typeof c.text === 'string')
      .map(c => c.text)
      .join('\n');
  }
  return '';
}

function looksLikeNonzeroExit(text) {
  if (typeof text !== 'string') return false;
  if (/exit\s+code\s+[1-9]/i.test(text)) return true;
  if (/\bexited?\s+with\s+(non-?zero|status\s+[1-9])/i.test(text)) return true;
  return false;
}

function stripNoise(text) {
  if (typeof text !== 'string') return '';
  return text.replace(/\s+/g, ' ').trim();
}

function truncate(s, n) {
  if (s.length <= n) return s;
  return s.slice(0, n - 1) + '…';
}

// CLI: takes a path to a JSONL file (or reads stdin if no arg), parses each line,
// and writes the signature JSON to stdout.
if (import.meta.url === `file://${process.argv[1]}`) {
  const path = process.argv[2];
  const raw = path ? readFileSync(path, 'utf8') : readFileSync(0, 'utf8');
  const entries = [];
  for (const line of raw.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    try {
      entries.push(JSON.parse(trimmed));
    } catch {
      // skip malformed
    }
  }
  const sig = extractFailureSignature(entries);
  process.stdout.write(JSON.stringify(sig) + '\n');
}
