import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const {
  redact,
  redactPII,
  redactSecrets,
  relativizePaths,
  stripCodeBlocks,
  PRESETS
} = await import(join(__dirname, '..', 'redactor.js'));

describe('redactor', () => {
  describe('redactPII', () => {
    it('redacts email addresses', () => {
      const result = redactPII('Contact john@example.com for help');
      assert.ok(!result.includes('john@example.com'));
      assert.ok(result.includes('[REDACTED-EMAIL]'));
    });

    it('redacts known git user name', () => {
      const result = redactPII('Author: Aaron Bassett committed this', {
        gitUserName: 'Aaron Bassett'
      });
      assert.ok(!result.includes('Aaron Bassett'));
      assert.ok(result.includes('[REDACTED-NAME]'));
    });

    it('redacts phone numbers', () => {
      const result = redactPII('Call +1-555-123-4567 or 555.123.4567');
      assert.ok(!result.includes('555-123-4567'));
    });

    it('redacts IP addresses', () => {
      const result = redactPII('Server at 192.168.1.100:3000');
      assert.ok(!result.includes('192.168.1.'));
      assert.ok(result.includes('[REDACTED-IP]'));
    });
  });

  describe('redactSecrets', () => {
    it('redacts OpenAI API keys', () => {
      const result = redactSecrets('Key: sk-proj-abc123def456ghi789jkl012mno345pqr678');
      assert.ok(!result.includes('sk-proj-'));
      assert.ok(result.includes('[REDACTED-SECRET]'));
    });

    it('redacts GitHub tokens', () => {
      const result = redactSecrets('Token: ghp_1234567890abcdefghijklmnopqrstuvwxyz');
      assert.ok(!result.includes('ghp_'));
      assert.ok(result.includes('[REDACTED-SECRET]'));
    });

    it('redacts Bearer tokens', () => {
      const result = redactSecrets('Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abc');
      assert.ok(!result.includes('eyJ'));
      assert.ok(result.includes('[REDACTED-SECRET]'));
    });

    it('redacts AWS access keys', () => {
      const result = redactSecrets('AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE');
      assert.ok(!result.includes('AKIAIOSFODNN7EXAMPLE'));
      assert.ok(result.includes('[REDACTED-SECRET]'));
    });

    it('redacts BIP-39 seed phrases (12 words)', () => {
      const seed = 'abandon ability able about above absent absorb abstract absurd abuse access accident';
      const result = redactSecrets(`My seed: ${seed}`);
      assert.ok(!result.includes('abandon ability'));
      assert.ok(result.includes('[REDACTED-SEED-PHRASE]'));
    });

    it('redacts hex private keys', () => {
      const hexKey = '0x' + 'a'.repeat(64);
      const result = redactSecrets(`Private key: ${hexKey}`);
      assert.ok(!result.includes(hexKey));
      assert.ok(result.includes('[REDACTED-PRIVATE-KEY]'));
    });

    it('redacts .env style values', () => {
      const result = redactSecrets('DATABASE_URL=postgres://user:pass@host:5432/db');
      assert.ok(!result.includes('postgres://'));
      assert.ok(result.includes('[REDACTED-SECRET]'));
    });
  });

  describe('relativizePaths', () => {
    it('replaces project root with ./', () => {
      const result = relativizePaths(
        'File at /Users/testuser/Projects/myproject/src/foo.js',
        { homeDir: '/Users/testuser', projectRoot: '/Users/testuser/Projects/myproject' }
      );
      assert.ok(result.includes('./src/foo.js'));
    });

    it('replaces non-project home paths with ~/', () => {
      const result = relativizePaths(
        'Config at /Users/testuser/.config/settings.json',
        { homeDir: '/Users/testuser', projectRoot: '/Users/testuser/Projects/myproject' }
      );
      assert.ok(result.includes('~/.config/settings.json'));
    });
  });

  describe('stripCodeBlocks', () => {
    it('replaces fenced code blocks', () => {
      const input = 'Here is code:\n```js\nconst x = 1;\nconsole.log(x);\n```\nAnd more text.';
      const result = stripCodeBlocks(input);
      assert.ok(!result.includes('const x = 1'));
      assert.ok(result.includes('[code block removed]'));
      assert.ok(result.includes('And more text'));
    });
  });

  describe('PRESETS', () => {
    it('defines all five preset tiers', () => {
      assert.ok(PRESETS.none);
      assert.ok(PRESETS.light);
      assert.ok(PRESETS.medium);
      assert.ok(PRESETS.heavy);
      assert.ok(PRESETS['conversation-only']);
    });

    it('none preset disables all transforms', () => {
      const p = PRESETS.none;
      assert.equal(p.pii, false);
      assert.equal(p.secrets, false);
      assert.equal(p.paths, false);
      assert.equal(p.hookNoise, false);
      assert.equal(p.toolInputs, 'keep');
      assert.equal(p.toolOutputs, 'keep');
      assert.equal(p.codeBlocks, false);
    });

    it('conversation-only strips everything', () => {
      const p = PRESETS['conversation-only'];
      assert.equal(p.pii, true);
      assert.equal(p.secrets, true);
      assert.equal(p.paths, 'strip');
      assert.equal(p.hookNoise, true);
      assert.equal(p.toolInputs, 'strip');
      assert.equal(p.toolOutputs, 'strip');
      assert.equal(p.codeBlocks, true);
    });
  });

  describe('redact (full pipeline)', () => {
    it('applies medium preset to an IR object', () => {
      const ir = {
        metadata: { sessionId: 's1', project: '/Users/testuser/Projects/myproject' },
        sections: [{
          index: 0, included: true,
          messages: [
            {
              id: 'u1', type: 'user',
              content: 'Fix /Users/testuser/Projects/myproject/src/auth.js and email me at john@example.com',
              timestamp: '2026-01-01T00:00:00Z'
            },
            {
              id: 'a1', type: 'assistant',
              textContent: 'I see the file at /Users/testuser/Projects/myproject/src/auth.js',
              toolCalls: [{
                id: 't1', name: 'Read',
                input: { file_path: '/Users/testuser/Projects/myproject/src/auth.js' },
                result: 'const secret = "sk-proj-abc123";'
              }],
              timestamp: '2026-01-01T00:01:00Z'
            }
          ]
        }],
        subagents: []
      };

      const result = redact(ir, {
        preset: 'medium',
        homeDir: '/Users/testuser',
        projectRoot: '/Users/testuser/Projects/myproject'
      });

      // PII redacted
      assert.ok(!result.sections[0].messages[0].content.includes('john@example.com'));
      // Secrets redacted
      assert.ok(!result.sections[0].messages[1].toolCalls[0].result.includes('sk-proj-'));
      // Paths relativized
      assert.ok(result.sections[0].messages[1].textContent.includes('./src/auth.js'));
      // Original IR not mutated
      assert.ok(ir.sections[0].messages[0].content.includes('john@example.com'));
    });
  });
});
