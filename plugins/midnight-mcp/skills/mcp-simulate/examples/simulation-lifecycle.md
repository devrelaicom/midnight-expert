# Simulation Lifecycle -- Worked Example

End-to-end walkthrough deploying a minimal counter contract, calling circuits, inspecting state, and cleaning up.

## Contract Source

A simple counter with `increment`, `decrement`, and `getCount` circuits:

```compact
pragma language_version 0.21;
import CompactStandardLibrary;

export ledger count: Counter;

export circuit increment(): [] {
  count.increment(1);
}

export circuit decrement(): [] {
  count.increment(-1 as Uint<16>);
}

export circuit incrementBy(amount: Uint<64>): [] {
  assert(amount > 0, "Amount must be positive");
  assert(amount <= 65535, "Amount exceeds Uint<16> maximum");
  count.increment(disclose(amount) as Uint<16>);
}

export circuit getCount(): Uint<64> {
  return count.read();
}
```

## Step 1: Deploy

Use `midnight-simulate-deploy` to create a session.

**Tool call:**

```json
{
  "tool": "midnight-simulate-deploy",
  "parameters": {
    "source": "pragma language_version 0.21;\nimport CompactStandardLibrary;\n\nexport ledger count: Counter;\n\nexport circuit increment(): [] {\n  count.increment(1);\n}\n\nexport circuit decrement(): [] {\n  count.increment(-1 as Uint<16>);\n}\n\nexport circuit incrementBy(amount: Uint<64>): [] {\n  assert(amount > 0, \"Amount must be positive\");\n  assert(amount <= 65535, \"Amount exceeds Uint<16> maximum\");\n  count.increment(disclose(amount) as Uint<16>);\n}\n\nexport circuit getCount(): Uint<64> {\n  return count.read();\n}"
  }
}
```

No `constructorArgs` needed -- this contract has no constructor.

**Representative response:**

```json
{
  "sessionId": "sim_a1b2c3d4e5f6",
  "status": "deployed",
  "ledger": {
    "count": 0
  },
  "circuits": [
    { "name": "increment", "parameters": [] },
    { "name": "decrement", "parameters": [] },
    {
      "name": "incrementBy",
      "parameters": [
        { "name": "amount", "type": "Uint<64>" }
      ]
    },
    {
      "name": "getCount",
      "parameters": [],
      "returnType": "Uint<64>"
    }
  ]
}
```

Save the `sessionId` -- it is required for every subsequent operation.

## Step 2: Call a Circuit (increment)

Use `midnight-simulate-call` to execute a circuit with no arguments.

**Tool call:**

```json
{
  "tool": "midnight-simulate-call",
  "parameters": {
    "sessionId": "sim_a1b2c3d4e5f6",
    "circuit": "increment"
  }
}
```

No `arguments` needed -- `increment` takes no parameters.

**Representative response:**

```json
{
  "status": "success",
  "returnValue": null,
  "ledger": {
    "count": 1
  }
}
```

## Step 3: Call a Circuit with Arguments (incrementBy)

Use `midnight-simulate-call` with positional arguments.

**Tool call:**

```json
{
  "tool": "midnight-simulate-call",
  "parameters": {
    "sessionId": "sim_a1b2c3d4e5f6",
    "circuit": "incrementBy",
    "arguments": [5]
  }
}
```

The `arguments` array is positional -- values correspond to the circuit's parameter list in declaration order. Here `5` maps to the `amount: Uint<64>` parameter.

**Representative response:**

```json
{
  "status": "success",
  "returnValue": null,
  "ledger": {
    "count": 6
  }
}
```

## Step 4: Inspect State

Use `midnight-simulate-state` to read the full session state.

**Tool call:**

```json
{
  "tool": "midnight-simulate-state",
  "parameters": {
    "sessionId": "sim_a1b2c3d4e5f6"
  }
}
```

**Representative response:**

```json
{
  "sessionId": "sim_a1b2c3d4e5f6",
  "ledger": {
    "count": 6
  },
  "circuits": [
    { "name": "increment", "parameters": [] },
    { "name": "decrement", "parameters": [] },
    {
      "name": "incrementBy",
      "parameters": [
        { "name": "amount", "type": "Uint<64>" }
      ]
    },
    {
      "name": "getCount",
      "parameters": [],
      "returnType": "Uint<64>"
    }
  ],
  "callHistory": [
    {
      "circuit": "increment",
      "arguments": [],
      "status": "success",
      "returnValue": null
    },
    {
      "circuit": "incrementBy",
      "arguments": [5],
      "status": "success",
      "returnValue": null
    }
  ]
}
```

Use `callHistory` to audit every mutation in the session. Use `circuits` to discover available entry points and their parameter signatures before making a call.

## Step 5: Call a Circuit with a Return Value (getCount)

**Tool call:**

```json
{
  "tool": "midnight-simulate-call",
  "parameters": {
    "sessionId": "sim_a1b2c3d4e5f6",
    "circuit": "getCount"
  }
}
```

**Representative response:**

```json
{
  "status": "success",
  "returnValue": 6,
  "ledger": {
    "count": 6
  }
}
```

The `returnValue` field contains the circuit's return value. Circuits with return type `[]` return `null`.

## Step 6: Delete the Session

Use `midnight-simulate-delete` to free server resources.

**Tool call:**

```json
{
  "tool": "midnight-simulate-delete",
  "parameters": {
    "sessionId": "sim_a1b2c3d4e5f6"
  }
}
```

**Representative response:**

```json
{
  "status": "deleted",
  "sessionId": "sim_a1b2c3d4e5f6"
}
```

After deletion, any call referencing this `sessionId` returns a session-not-found error. Deploy a new session to continue testing.

## Summary

| Step | Tool | Key parameter |
|------|------|---------------|
| Deploy | `midnight-simulate-deploy` | `source` (Compact source code) |
| Call (no args) | `midnight-simulate-call` | `sessionId`, `circuit` |
| Call (with args) | `midnight-simulate-call` | `sessionId`, `circuit`, `arguments` |
| Inspect state | `midnight-simulate-state` | `sessionId` |
| Read return value | `midnight-simulate-call` | Check `returnValue` in response |
| Clean up | `midnight-simulate-delete` | `sessionId` |
