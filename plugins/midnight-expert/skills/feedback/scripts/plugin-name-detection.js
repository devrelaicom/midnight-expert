import { readFileSync } from 'node:fs';

/**
 * Detect plugin candidates from the user's opening prose and raw JSONL entries.
 *
 * @param {object} opts
 * @param {string} opts.prose - User's opening message text.
 * @param {object[]} opts.entries - Parsed JSONL entries (raw schema).
 * @param {string[]} opts.knownPlugins - Slugs of plugins in the marketplace.
 * @returns {{ fromProse: string[], fromFailingTools: string[], activeInSession: string[] }}
 */
export function detectPluginCandidates({ prose, entries, knownPlugins }) {
  const known = new Set(knownPlugins);
  const fromProse = new Set();
  const fromFailingTools = new Set();
  const activeInSession = new Set();

  // Prose: whole-word, case-insensitive
  if (typeof prose === 'string' && prose.length > 0) {
    for (const slug of known) {
      const re = new RegExp(`\\b${escapeRegex(slug)}\\b`, 'i');
      if (re.test(prose)) fromProse.add(slug);
    }
  }

  // Entries: gather active + failing
  const toolPluginMap = new Map(); // tool_use_id -> slug
  const failingIds = new Set();

  for (const entry of entries || []) {
    if (!entry || typeof entry !== 'object') continue;

    if (entry.type === 'assistant' && Array.isArray(entry.message?.content)) {
      for (const block of entry.message.content) {
        if (block.type !== 'tool_use') continue;
        const slug = pluginFromBlock(block);
        if (slug && known.has(slug)) {
          activeInSession.add(slug);
          toolPluginMap.set(block.id, slug);
        }
      }
      continue;
    }

    if (entry.type === 'user' && Array.isArray(entry.message?.content)) {
      for (const block of entry.message.content) {
        if (block.type === 'tool_result' && block.is_error === true) {
          failingIds.add(block.tool_use_id);
        }
      }
    }
  }

  for (const id of failingIds) {
    const slug = toolPluginMap.get(id);
    if (slug) fromFailingTools.add(slug);
  }

  return {
    fromProse: [...fromProse],
    fromFailingTools: [...fromFailingTools],
    activeInSession: [...activeInSession],
  };
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

function escapeRegex(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// CLI: --prose-file <p> --jsonl-file <p> --plugins <comma>
if (import.meta.url === `file://${process.argv[1]}`) {
  const args = parseArgs(process.argv.slice(2));
  const prose = args['prose-file'] ? readFileSync(args['prose-file'], 'utf8') : '';
  const entries = args['jsonl-file']
    ? parseJsonlFile(args['jsonl-file'])
    : [];
  const knownPlugins = (args['plugins'] || '').split(',').filter(Boolean);
  const result = detectPluginCandidates({ prose, entries, knownPlugins });
  process.stdout.write(JSON.stringify(result) + '\n');
}

function parseJsonlFile(path) {
  const raw = readFileSync(path, 'utf8');
  const out = [];
  for (const line of raw.split('\n')) {
    const t = line.trim();
    if (!t) continue;
    try {
      out.push(JSON.parse(t));
    } catch {}
  }
  return out;
}

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith('--')) {
      out[argv[i].slice(2)] = argv[i + 1];
      i++;
    }
  }
  return out;
}
