# Analysis and Compilation Tool Invocations

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

## midnight-compile-contract

**Request:**

```json
{
  "tool": "midnight-compile-contract",
  "arguments": {
    "source": "export ledger {\n  balance: Counter\n}\n\nexport circuit deposit(amount: Uint<64>): [] {\n  balance.increment(amount);\n}",
    "skipZk": true
  }
}
```

**Response (abbreviated):**

```json
{
  "success": true,
  "compilationMode": "skipZk",
  "diagnostics": [],
  "exports": ["deposit"],
  "ledgerFields": [
    { "name": "balance", "type": "Counter" }
  ],
  "note": "Syntax and type checking passed. ZK circuit generation was skipped."
}
```

## midnight-compile-archive

**Request:**

```json
{
  "tool": "midnight-compile-archive",
  "arguments": {
    "files": {
      "src/lib.compact": "export ledger {\n  owner: Bytes<32>\n}\n\nexport circuit get_owner(): Bytes<32> {\n  return owner;\n}",
      "src/main.compact": "import { get_owner } from './lib.compact';\n\nexport ledger {\n  value: Counter\n}\n\nexport circuit increment(): [] {\n  value.increment(1);\n}"
    },
    "entryPoint": "src/main.compact"
  }
}
```

**Response (abbreviated):**

```json
{
  "success": true,
  "compilationMode": "default",
  "filesCompiled": ["src/lib.compact", "src/main.compact"],
  "entryPoint": "src/main.compact",
  "exports": ["increment"],
  "diagnostics": []
}
```
