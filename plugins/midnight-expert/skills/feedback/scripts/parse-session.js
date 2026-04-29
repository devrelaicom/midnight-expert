import { readFileSync } from 'node:fs';

/**
 * Parse a JSONL transcript file into an Intermediate Representation (IR).
 *
 * @param {string} filePath - Absolute path to the .jsonl file
 * @returns {object} IR object with metadata, sections, and subagents
 */
export function parseJSONL(filePath) {
  const raw = readFileSync(filePath, 'utf8');
  const lines = raw.split('\n');

  const entries = [];
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    try {
      entries.push(JSON.parse(trimmed));
    } catch {
      process.stderr.write(`[parser] Warning: skipping malformed line: ${trimmed.slice(0, 80)}\n`);
    }
  }

  // ── Build metadata ──────────────────────────────────────────────────────────

  const metadata = {
    sessionId: null,
    sessionName: null,
    startTime: null,
    endTime: null,
    project: null,
    gitBranch: null,
    claudeVersion: null,
    model: null,
    totalUserMessages: 0,
    totalAssistantMessages: 0,
  };

  let startMs = Infinity;
  let endMs = -Infinity;

  for (const entry of entries) {
    // Session ID — grab from any entry
    if (!metadata.sessionId && entry.sessionId) {
      metadata.sessionId = entry.sessionId;
    }

    // Custom title (session name)
    if (entry.type === 'custom-title' && entry.customTitle) {
      metadata.sessionName = entry.customTitle;
    }

    // Timestamps — track earliest and latest across all entries
    if (entry.timestamp) {
      const ms = new Date(entry.timestamp).getTime();
      if (ms < startMs) {
        startMs = ms;
        metadata.startTime = entry.timestamp;
      }
      if (ms > endMs) {
        endMs = ms;
        metadata.endTime = entry.timestamp;
      }
    }

    // Project path (cwd) — first entry that has it
    if (!metadata.project && entry.cwd) {
      metadata.project = entry.cwd;
    }

    // Git branch — first entry that has it
    if (!metadata.gitBranch && entry.gitBranch) {
      metadata.gitBranch = entry.gitBranch;
    }

    // Claude version — first entry that has it
    if (!metadata.claudeVersion && entry.version) {
      metadata.claudeVersion = entry.version;
    }

    // Model — first assistant message
    if (!metadata.model && entry.type === 'assistant' && entry.message?.model) {
      metadata.model = entry.message.model;
    }

    // Message counts
    if (entry.type === 'user') {
      metadata.totalUserMessages++;
    } else if (entry.type === 'assistant') {
      metadata.totalAssistantMessages++;
    }
  }

  // ── Filter to user/assistant entries only ────────────────────────────────────

  const conversationEntries = entries.filter(
    e => e.type === 'user' || e.type === 'assistant'
  );

  // ── Build a lookup map: parentUuid → entry (for O(1) tool result pairing) ────

  const byParentUuid = {};
  for (const entry of conversationEntries) {
    if (entry.parentUuid) byParentUuid[entry.parentUuid] = entry;
  }

  // ── Process assistant messages: extract text, tool calls, and tool results ───

  /**
   * Given an assistant entry, find the next user entry (by parentUuid chain)
   * that contains tool results, and return a map of tool_use_id → result text.
   */
  function getToolResults(asstEntry) {
    const resultMap = {};
    // The next user message should have parentUuid === asstEntry.uuid
    const nextUser = byParentUuid[asstEntry.uuid];
    if (!nextUser) return resultMap;
    const content = nextUser.message?.content;
    if (!Array.isArray(content)) return resultMap;
    for (const item of content) {
      if (item.type === 'tool_result') {
        // Collect all text from the tool result content array
        let text = '';
        if (Array.isArray(item.content)) {
          text = item.content
            .filter(c => c.type === 'text')
            .map(c => c.text)
            .join('\n');
        } else if (typeof item.content === 'string') {
          text = item.content;
        }
        resultMap[item.tool_use_id] = text;
      }
    }
    return resultMap;
  }

  /**
   * Extract the subagent ID from a tool result text.
   * Looks for pattern "agentId: <id>"
   */
  function extractSubagentId(resultText) {
    if (!resultText) return null;
    const match = resultText.match(/agentId:\s*(\S+?)[\s.,;)]*(?:\s|$)/);
    return match ? match[1] : null;
  }

  /**
   * Process an assistant entry into a structured message object.
   */
  function processAssistantEntry(entry) {
    const content = entry.message?.content ?? [];
    const textContent = Array.isArray(content)
      ? content.filter(c => c.type === 'text').map(c => c.text).join('\n')
      : (typeof content === 'string' ? content : '');

    const toolResultMap = getToolResults(entry);

    const toolCalls = [];
    if (Array.isArray(content)) {
      for (const item of content) {
        if (item.type !== 'tool_use') continue;
        const result = toolResultMap[item.id] ?? null;
        const call = {
          id: item.id,
          name: item.name,
          input: item.input ?? {},
          result,
        };
        if (item.name === 'Agent') {
          call.subagentId = extractSubagentId(result);
        }
        toolCalls.push(call);
      }
    }

    return {
      id: entry.uuid,
      type: 'assistant',
      content: textContent,
      toolCalls: toolCalls.length > 0 ? toolCalls : undefined,
      timestamp: entry.timestamp,
    };
  }

  /**
   * Process a user entry (string content only — tool result user messages are
   * handled implicitly through tool result pairing on assistant messages).
   */
  function processUserEntry(entry) {
    const raw = entry.message?.content ?? '';
    return {
      id: entry.uuid,
      type: 'user',
      content: typeof raw === 'string' ? raw : '',
      timestamp: entry.timestamp,
    };
  }

  // ── Group into sections ──────────────────────────────────────────────────────

  const sections = [];
  let currentSection = null;

  for (const entry of conversationEntries) {
    if (entry.type === 'user') {
      const msgContent = entry.message?.content;
      const isStringContent = typeof msgContent === 'string';

      if (isStringContent) {
        // New section starts
        if (currentSection) sections.push(currentSection);
        currentSection = {
          index: sections.length,
          included: true,
          messages: [processUserEntry(entry)],
        };
      }
      // Array content (tool results) — skip; already paired with assistant tool calls
    } else if (entry.type === 'assistant') {
      if (!currentSection) {
        // Edge case: assistant before any user string — start a section
        currentSection = {
          index: sections.length,
          included: true,
          messages: [],
        };
      }
      currentSection.messages.push(processAssistantEntry(entry));
    }
  }

  // Push the last section
  if (currentSection) sections.push(currentSection);

  // ── Build subagents array ────────────────────────────────────────────────────

  const subagents = [];
  for (const section of sections) {
    for (const msg of section.messages) {
      if (msg.type !== 'assistant' || !msg.toolCalls) continue;
      for (const call of msg.toolCalls) {
        if (call.name !== 'Agent') continue;
        subagents.push({
          id: call.subagentId,
          calledFrom: msg.id,
          description: call.input?.description ?? null,
          handling: null,
        });
      }
    }
  }

  return { metadata, sections, subagents };
}

// ── CLI entrypoint ────────────────────────────────────────────────────────────

if (process.argv[1] && process.argv[1].endsWith('parser.js') && process.argv[2]) {
  const ir = parseJSONL(process.argv[2]);
  process.stdout.write(JSON.stringify(ir));
}
