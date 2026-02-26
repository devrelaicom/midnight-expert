---
title: WitnessContext Object
type: concept
description: The WitnessContext parameter in TypeScript witness implementations — provides ledger state access, contract address, and transaction context during proof generation.
links:
  - witness-functions
  - compact-to-typescript-types
  - circuit-witness-boundary
---

# WitnessContext Object

Every witness function's TypeScript implementation receives a `WitnessContext` as its first parameter. This object is the bridge between the off-chain witness code and the contract's on-chain state — it allows witnesses to read current ledger values and access contract metadata during proof generation.

## Import and Basic Usage

```typescript
import { WitnessContext } from '@midnight-ntwrk/compact-runtime';

export const witnesses = {
  getOwner: async (context: WitnessContext): Promise<Uint8Array> => {
    const state = context.ledger;
    return state.owner;
  }
};
```

The `WitnessContext` is always the **first parameter** of every witness implementation, regardless of whether the Compact declaration has parameters. This is a TypeScript-side requirement — the Compact declaration does not mention `WitnessContext` because it is injected automatically by the runtime.

## Key Properties

### `context.ledger` — Ledger State Access

The `ledger` property provides read access to the contract's current on-chain state:

```typescript
getCaller: async (context: WitnessContext): Promise<bigint> => {
  // Read the current owner from ledger state
  const currentOwner = context.ledger.owner;
  return currentOwner;
}
```

The ledger object's shape matches the contract's exported ledger fields, with types mapped according to [[compact-to-typescript-types]]. Counter values appear as `bigint`, Cell values appear as their mapped type, and Map fields provide lookup methods.

### `context.contractAddress` — Contract Identity

Returns the deployed contract's address, useful when witnesses need to identify which contract instance they are serving:

```typescript
getContractInfo: async (context: WitnessContext): Promise<Uint8Array> => {
  const addr = context.contractAddress;
  // Use address to fetch contract-specific data from an external service
  return await externalService.getData(addr);
}
```

## Parameter Ordering

When a Compact witness declares parameters, they appear **after** `WitnessContext` in the TypeScript implementation:

```compact
// Compact declaration
witness fetchBalance(account: Field): Uint<0..1000000>;
```

```typescript
// TypeScript implementation — context is FIRST, then Compact params
fetchBalance: async (
  context: WitnessContext,
  account: bigint           // Field → bigint
): Promise<bigint> => {
  const balance = await api.getBalance(account.toString());
  return BigInt(balance);
}
```

Forgetting `WitnessContext` as the first parameter is one of the most common [[witness-functions]] mistakes — it causes a runtime error during proof generation, not a compile-time error.

## Async Patterns

All witness implementations should be `async` functions returning a `Promise`. This allows witnesses to perform asynchronous operations during proof generation:

```typescript
getUserInput: async (context: WitnessContext): Promise<boolean> => {
  // Can await user interaction, API calls, database queries
  const response = await promptUser('Approve transaction?');
  return response === 'yes';
},

fetchExternalData: async (
  context: WitnessContext,
  key: bigint
): Promise<bigint> => {
  // Can fetch from external services
  const data = await fetch(`https://api.example.com/data/${key}`);
  const result = await data.json();
  return BigInt(result.value);
}
```

The proof generation process awaits each witness call, so expensive operations (network requests, user prompts) are acceptable but will delay proof creation.

## Trust Boundary

The `WitnessContext` operates on the user's machine during proof generation. The values it provides are not verified by the ZK proof — the proof only verifies that the circuit constraints were satisfied given whatever values the witnesses returned. This is the fundamental trust boundary described in [[circuit-witness-boundary]]: circuits must validate witness outputs with `assert` statements rather than trusting them implicitly.
