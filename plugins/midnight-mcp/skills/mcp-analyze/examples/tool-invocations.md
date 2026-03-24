# Analysis Tool Invocations

## midnight-analyze-contract

**Request:**

```json
{
  "tool": "midnight-analyze-contract",
  "arguments": {
    "source": "export ledger {\n  balance: Counter\n}\n\nexport circuit deposit(amount: Uint<64>): [] {\n  balance.increment(amount);\n}\n\nexport circuit withdraw(amount: Uint<64>): [] {\n  assert balance.value() >= amount;\n  balance.decrement(amount);\n}",
    "mode": "fast",
    "include": ["summary", "findings"]
  }
}
```

**Response (abbreviated):**

```json
{
  "summary": {
    "contractName": "inferred",
    "ledgerFields": 1,
    "circuits": 2,
    "exports": 2,
    "patterns": ["counter-based balance"]
  },
  "findings": [
    {
      "severity": "warning",
      "category": "access-control",
      "message": "withdraw circuit has no access control guard — any caller can withdraw",
      "location": "circuit withdraw",
      "suggestion": "Add a witness-based ownership check before allowing withdrawals"
    }
  ]
}
```

For compilation tool invocations (`midnight-compile-contract`, `midnight-compile-archive`), see the `mcp-compile` skill.
