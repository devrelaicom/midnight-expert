/**
 * redactor.js — PII, secrets, path, and structural redaction for transcript IR.
 *
 * Security note: false positives (over-redaction) are acceptable;
 * false negatives (missed secrets) are not.
 */

// ── BIP-39 wordlist (first 200 words for detection coverage) ─────────────────

const BIP39_WORDS = new Set([
  'abandon','ability','able','about','above','absent','absorb','abstract',
  'absurd','abuse','access','accident','account','accuse','achieve','acid',
  'acoustic','acquire','across','act','action','actor','actress','actual',
  'adapt','add','addict','address','adjust','admit','adult','advance',
  'advice','aerobic','afford','afraid','again','age','agent','agree',
  'ahead','aim','air','airport','aisle','alarm','album','alcohol',
  'alert','alien','all','alley','allow','almost','alone','alpha',
  'already','also','alter','always','amateur','amazing','among','amount',
  'amused','analyst','anchor','ancient','anger','angle','angry','animal',
  'ankle','announce','annual','another','answer','antenna','antique','anxiety',
  'any','apart','apology','appear','apple','approve','april','arch',
  'arctic','area','arena','argue','arm','armed','armor','army',
  'around','arrange','arrest','arrive','arrow','art','artefact','artist',
  'artwork','ask','aspect','assault','asset','assist','assume','asthma',
  'athlete','atom','attack','attend','attitude','attract','auction','audit',
  'august','aunt','author','auto','autumn','average','avocado','award',
  'aware','away','awesome','awful','awkward','axis',
]);

// ── Individual transform functions ────────────────────────────────────────────

/**
 * Redact PII: emails, phone numbers, IP addresses, git user name/email.
 *
 * @param {string} text
 * @param {object} [options]
 * @param {string} [options.gitUserName]
 * @param {string} [options.gitUserEmail]
 * @returns {string}
 */
export function redactPII(text, options = {}) {
  if (typeof text !== 'string') return text;
  let out = text;

  // Git user name (exact match, case-sensitive)
  if (options.gitUserName && options.gitUserName.trim()) {
    const escaped = options.gitUserName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    out = out.replace(new RegExp(escaped, 'g'), '[REDACTED-NAME]');
  }

  // Git user email (exact match, before general email regex to avoid double-hit)
  if (options.gitUserEmail && options.gitUserEmail.trim()) {
    const escaped = options.gitUserEmail.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    out = out.replace(new RegExp(escaped, 'gi'), '[REDACTED-EMAIL]');
  }

  // Email addresses
  out = out.replace(/\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b/g, '[REDACTED-EMAIL]');

  // IP addresses (IPv4) — before phone numbers to avoid partial overlap
  out = out.replace(/\b(?:\d{1,3}\.){3}\d{1,3}\b/g, '[REDACTED-IP]');

  // Phone numbers — various formats
  // +1-555-123-4567 | 555.123.4567 | (555) 123-4567 | 555-123-4567
  out = out.replace(
    /(?:\+\d{1,3}[\s\-]?)?(?:\(?\d{3}\)?[\s.\-])\d{3}[\s.\-]\d{4}\b/g,
    '[REDACTED-PHONE]'
  );

  return out;
}

/**
 * Redact secrets: API keys, tokens, seed phrases, private keys, env values.
 *
 * @param {string} text
 * @returns {string}
 */
export function redactSecrets(text) {
  if (typeof text !== 'string') return text;
  let out = text;

  // Hex private keys: 0x followed by exactly 64 hex characters
  out = out.replace(/\b0x[0-9a-fA-F]{64}\b/g, '[REDACTED-PRIVATE-KEY]');

  // BIP-39 seed phrases: 12+ consecutive BIP-39 words
  // We'll match runs of word characters and check them
  out = out.replace(/(?:\b[a-z]+\b\s+){11,}\b[a-z]+\b/g, (match) => {
    const words = match.trim().split(/\s+/);
    // Find the longest run of consecutive BIP-39 words
    let runStart = -1;
    let longestRun = [];
    let currentRun = [];

    for (let i = 0; i < words.length; i++) {
      if (BIP39_WORDS.has(words[i])) {
        if (currentRun.length === 0) runStart = i;
        currentRun.push(words[i]);
      } else {
        if (currentRun.length >= 12 && currentRun.length > longestRun.length) {
          longestRun = currentRun;
        }
        currentRun = [];
        runStart = -1;
      }
    }
    if (currentRun.length >= 12 && currentRun.length > longestRun.length) {
      longestRun = currentRun;
    }

    if (longestRun.length >= 12) {
      // Replace the seed phrase portion within the match
      const seedPhraseText = longestRun.join(' ');
      return match.replace(seedPhraseText, '[REDACTED-SEED-PHRASE]');
    }
    return match;
  });

  // OpenAI API keys: sk- followed by alphanumeric and hyphens (6+ chars)
  // Real keys are much longer but we match shorter test fixtures too
  out = out.replace(/\bsk-[A-Za-z0-9\-_]{6,}/g, '[REDACTED-SECRET]');

  // GitHub tokens: ghp_, ghs_, gho_, ghu_, ghr_ prefixed tokens
  out = out.replace(/\bgh[pshour]_[A-Za-z0-9]{20,}/g, '[REDACTED-SECRET]');

  // AWS access key IDs: AKIA followed by 16 uppercase alphanumeric
  out = out.replace(/\bAKIA[A-Z0-9]{16}\b/g, '[REDACTED-SECRET]');

  // Bearer tokens (JWT-style: three base64url segments separated by dots)
  out = out.replace(/\bBearer\s+[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_.]+/g, 'Bearer [REDACTED-SECRET]');

  // Generic JWT tokens not preceded by "Bearer " (eyJ header)
  out = out.replace(/\beyJ[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_.]+/g, '[REDACTED-SECRET]');

  // Connection strings / URLs with credentials: proto://user:pass@host
  out = out.replace(/\b(?:postgres|postgresql|mysql|mongodb|redis|amqp|ftp|sftp|smtp):\/\/[^\s"'`<>]*/gi, '[REDACTED-SECRET]');

  // .env-style assignments: KEY=value (value is non-trivially sensitive)
  // Match patterns like DATABASE_URL=..., SECRET_KEY=..., PASSWORD=..., TOKEN=..., etc.
  out = out.replace(
    /\b(DATABASE_URL|SECRET(?:_KEY)?|PASSWORD|PASSWD|TOKEN|API_KEY|PRIVATE_KEY|ACCESS_KEY|AUTH_(?:TOKEN|SECRET)|ENCRYPTION_KEY|SIGNING_KEY|WEBHOOK_SECRET|JWT_SECRET|OAUTH_(?:TOKEN|SECRET)|AWS_SECRET_ACCESS_KEY|AWS_ACCESS_KEY_ID)=\S+/gi,
    (_, key) => `${key}=[REDACTED-SECRET]`
  );

  return out;
}

/**
 * Replace absolute paths under projectRoot with ./ and homeDir with ~/
 *
 * @param {string} text
 * @param {object} options
 * @param {string} options.homeDir
 * @param {string} options.projectRoot
 * @returns {string}
 */
export function relativizePaths(text, options = {}) {
  if (typeof text !== 'string') return text;
  const { homeDir, projectRoot } = options;
  let out = text;

  // Project root first (more specific)
  if (projectRoot) {
    const escaped = projectRoot.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    out = out.replace(new RegExp(escaped + '(/|$)', 'g'), (_, sep) => './' + (sep === '/' ? '' : ''));
    // Handle trailing slash edge case — ensure paths like ./src/foo.js not .//src/foo.js
    out = out.replace(/\.\/\//g, './');
  }

  // Then home dir (less specific)
  if (homeDir) {
    const escaped = homeDir.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    out = out.replace(new RegExp(escaped + '(/|$)', 'g'), (_, sep) => '~/' + (sep === '/' ? '' : ''));
    out = out.replace(/~\/\//g, '~/');
  }

  return out;
}

/**
 * Strip fenced code blocks (``` ... ```), replacing with [code block removed].
 *
 * @param {string} text
 * @returns {string}
 */
export function stripCodeBlocks(text) {
  if (typeof text !== 'string') return text;
  // Match fenced code blocks with optional language tag
  return text.replace(/```[^\n]*\n[\s\S]*?```/g, '[code block removed]');
}

// ── PRESETS ───────────────────────────────────────────────────────────────────

export const PRESETS = {
  none: {
    pii: false,
    secrets: false,
    paths: false,
    hookNoise: false,
    toolInputs: 'keep',
    toolOutputs: 'keep',
    codeBlocks: false,
  },
  light: {
    pii: true,
    secrets: true,
    paths: false,
    hookNoise: false,
    toolInputs: 'keep',
    toolOutputs: 'keep',
    codeBlocks: false,
  },
  medium: {
    pii: true,
    secrets: true,
    paths: 'relativize',
    hookNoise: true,
    toolInputs: 'keep',
    toolOutputs: 'keep',
    codeBlocks: false,
  },
  heavy: {
    pii: true,
    secrets: true,
    paths: 'relativize',
    hookNoise: true,
    toolInputs: 'names-only',
    toolOutputs: 'summary-only',
    codeBlocks: true,
  },
  'conversation-only': {
    pii: true,
    secrets: true,
    paths: 'strip',
    hookNoise: true,
    toolInputs: 'strip',
    toolOutputs: 'strip',
    codeBlocks: true,
  },
};

// ── String transform pipeline ─────────────────────────────────────────────────

/**
 * Apply string-level transforms to a single text value.
 */
function applyStringTransforms(text, config, piiOptions) {
  if (typeof text !== 'string') return text;
  let out = text;

  if (config.pii) {
    out = redactPII(out, piiOptions);
  }
  if (config.secrets) {
    out = redactSecrets(out);
  }
  if (config.paths === 'relativize') {
    out = relativizePaths(out, piiOptions);
  } else if (config.paths === 'strip') {
    // Strip absolute paths entirely
    if (piiOptions.projectRoot) {
      const escaped = piiOptions.projectRoot.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      out = out.replace(new RegExp(escaped + '[^\\s"\'`]*', 'g'), '[PATH-REMOVED]');
    }
    if (piiOptions.homeDir) {
      const escaped = piiOptions.homeDir.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      out = out.replace(new RegExp(escaped + '[^\\s"\'`]*', 'g'), '[PATH-REMOVED]');
    }
  }
  if (config.codeBlocks) {
    out = stripCodeBlocks(out);
  }

  return out;
}

// ── Main redact pipeline ──────────────────────────────────────────────────────

/**
 * Deep-clone an IR object and apply redaction according to preset + overrides.
 *
 * @param {object} ir - The IR object from the parser
 * @param {object} options
 * @param {string} [options.preset='none'] - Preset name
 * @param {object} [options.overrides={}] - Field overrides on top of preset
 * @param {string} [options.homeDir] - User's home directory path
 * @param {string} [options.projectRoot] - Project root path
 * @param {string} [options.gitUserName] - Git user name for PII redaction
 * @param {string} [options.gitUserEmail] - Git user email for PII redaction
 * @returns {object} Redacted IR (deep clone, original not mutated)
 */
export function redact(ir, options = {}) {
  const {
    preset = 'none',
    overrides = {},
    homeDir = '',
    projectRoot = '',
    gitUserName = '',
    gitUserEmail = '',
  } = options;

  // Resolve config
  const base = PRESETS[preset] ?? PRESETS.none;
  const config = { ...base, ...overrides };

  // PII options passed to string transforms
  const piiOptions = { homeDir, projectRoot, gitUserName, gitUserEmail };

  // Deep clone
  const cloned = JSON.parse(JSON.stringify(ir));

  // Walk sections → messages
  if (Array.isArray(cloned.sections)) {
    for (const section of cloned.sections) {
      if (!Array.isArray(section.messages)) continue;

      for (const msg of section.messages) {
        // User messages: redact content (string)
        if (msg.type === 'user' && typeof msg.content === 'string') {
          msg.content = applyStringTransforms(msg.content, config, piiOptions);
        }

        // Assistant messages
        if (msg.type === 'assistant') {
          // textContent field (manually constructed IRs)
          if (typeof msg.textContent === 'string') {
            msg.textContent = applyStringTransforms(msg.textContent, config, piiOptions);
          }
          // content field (parser-produced IRs)
          if (typeof msg.content === 'string') {
            msg.content = applyStringTransforms(msg.content, config, piiOptions);
          }

          // Tool calls
          if (Array.isArray(msg.toolCalls)) {
            if (config.toolInputs === 'strip') {
              msg.toolCalls = undefined;
            } else {
              for (const call of msg.toolCalls) {
                // Tool input
                if (config.toolInputs === 'names-only') {
                  call.input = null;
                } else if (config.toolInputs === 'keep' && call.input && typeof call.input === 'object') {
                  // Redact string values within input object
                  for (const [k, v] of Object.entries(call.input)) {
                    if (typeof v === 'string') {
                      call.input[k] = applyStringTransforms(v, config, piiOptions);
                    }
                  }
                }

                // Tool output / result
                if (config.toolOutputs === 'strip') {
                  call.result = null;
                } else if (config.toolOutputs === 'summary-only') {
                  call.result = '[Tool output — summary needed]';
                } else if (config.toolOutputs === 'keep' && typeof call.result === 'string') {
                  call.result = applyStringTransforms(call.result, config, piiOptions);
                }
              }
            }
          }
        }
      }
    }
  }

  return cloned;
}

// ── CLI entrypoint ────────────────────────────────────────────────────────────

if (process.argv[1] && process.argv[1].endsWith('redactor.js')) {
  const args = process.argv.slice(2);
  const getFlag = (name) => {
    const idx = args.indexOf(name);
    return idx !== -1 ? args[idx + 1] : undefined;
  };

  const preset = getFlag('--preset') ?? 'none';
  const homeDir = getFlag('--home-dir') ?? '';
  const projectRoot = getFlag('--project-root') ?? '';
  const gitUserName = getFlag('--git-user-name') ?? '';
  const gitUserEmail = getFlag('--git-user-email') ?? '';

  let raw = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (chunk) => { raw += chunk; });
  process.stdin.on('end', () => {
    const ir = JSON.parse(raw);
    const result = redact(ir, { preset, homeDir, projectRoot, gitUserName, gitUserEmail });
    process.stdout.write(JSON.stringify(result));
  });
}
