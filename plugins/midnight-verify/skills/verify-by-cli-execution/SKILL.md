---
name: midnight-verify:verify-by-cli-execution
description: >-
  Verification by running Compact CLI commands and observing output. Checks
  CLI availability, runs commands, captures stdout/stderr/exit code, inspects
  filesystem changes, and interprets results. Covers flag existence, flag
  behavior, output structure, error messages, exit codes, version info,
  and CLI-vs-compactc comparisons. Loaded by the cli-tester agent.
version: 0.1.0
---

# Verify by CLI Execution

You are verifying a Compact CLI claim by running the actual command and observing what happens. Follow these steps in order.

## Critical Rule

**CLI output is primary evidence.** The command ran and produced this output — that's definitive for behavioral claims. Source code is secondary evidence for internal claims that can't be observed via CLI.

## Using midnight-tooling Skills as Hints

You may load the `midnight-tooling:compact-cli` skill to understand what flags exist and how the CLI works. This is a **hint only** — the CLI output is your evidence, not the skill content.

## Step 1: Check CLI Availability

```bash
compact --version 2>&1
compactc --version 2>&1
```

If **both** commands fail (command not found), report **Inconclusive (cli unavailable)** and stop:

```
The Compact CLI is not installed or not on PATH. Install it via
Load the `midnight-tooling:install-cli` skill for installation instructions and retry.
```

If only one is available, note which one and proceed — some claims are about `compact` specifically vs `compactc`.

## Step 2: Determine the Test Approach

Based on the claim, choose the appropriate test:

### Flag Existence

Check if a flag appears in help output:

```bash
compact compile --help 2>&1 | grep -i '<flag-name>'
```

If found → flag exists. If not found → flag does not exist.

### Flag Behavior

Compile a minimal contract with and without the flag, compare results:

```bash
# Get language version
LANG_VER=$(compact compile --language-version 2>&1)

# Create job directory
JOB_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
mkdir -p .midnight-expert/verify/compact-workspace/jobs/$JOB_ID

# Write minimal contract
cat > .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/test.compact << COMPACT_EOF
pragma language_version $LANG_VER;
import CompactStandardLibrary;

export circuit test(): Field {
  0
}
COMPACT_EOF

# Compile WITHOUT the flag
compact compile .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/test.compact \
  > .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/stdout-without.txt 2>&1
ls -R .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/test/build/ \
  > .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/listing-without.txt 2>&1

# Clean compiled output
rm -rf .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/test/

# Compile WITH the flag
compact compile --skip-zk .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/test.compact \
  > .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/stdout-with.txt 2>&1
ls -R .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/test/build/ \
  > .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/listing-with.txt 2>&1
```

Compare the two directory listings to identify what the flag changed.

### Output Structure

Compile a minimal contract and inspect the build directory:

```bash
# After compilation
find .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/test/build/ -type f | sort
```

Compare the actual file tree against the claimed structure.

### Error Messages

Feed invalid input and capture stderr:

```bash
# Write intentionally invalid contract
cat > .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/bad.compact << 'COMPACT_EOF'
<intentionally invalid code targeting the claimed error>
COMPACT_EOF

compact compile .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/bad.compact 2>&1
echo "Exit code: $?"
```

Check that stderr contains the claimed error message (or doesn't, if refuting).

### Exit Codes

Run the command and capture the exit code:

```bash
compact compile <args> 2>&1
echo "Exit code: $?"
```

### Version Info

```bash
compact --version 2>&1
compact compile --language-version 2>&1
compactc --version 2>&1
```

Parse and compare against the claim.

### CLI vs compactc

Run both and compare behavior:

```bash
# Via wrapper
compact compile <args> > stdout-compact.txt 2>&1
echo "compact exit: $?"

# Via compactc directly
compactc <args> > stdout-compactc.txt 2>&1
echo "compactc exit: $?"

# Compare
diff stdout-compact.txt stdout-compactc.txt
```

## Step 3: Interpret and Report

Compare the actual output against the claim.

**Report format:**

```
### CLI Execution Report

**Claim:** [verbatim]

**Command(s) run:**
\`\`\`bash
[exact commands with arguments]
\`\`\`

**Exit code:** [0 / non-zero value]

**stdout:**
\`\`\`
[captured output — full, not truncated]
\`\`\`

**stderr:**
\`\`\`
[captured output — full, not truncated]
\`\`\`

**Filesystem changes:** [new files/directories created, or "N/A" if not relevant]

**Interpretation:** [Confirmed / Refuted / Inconclusive] — [explanation of how the output matches or contradicts the claim]
```

## Step 4: Clean Up

Remove the job directory if one was created:

```bash
rm -rf .midnight-expert/verify/compact-workspace/jobs/$JOB_ID
```

Do NOT remove the base compact-workspace — it is shared across jobs.
