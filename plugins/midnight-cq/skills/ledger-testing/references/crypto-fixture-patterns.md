# Crypto Fixture Patterns

Patterns for generating test fixtures and testing cryptographic functions
from `@midnight-ntwrk/ledger-v8`.

## Why sample* Functions Exist

Many ledger types are hex-encoded strings with specific lengths and internal
structure. Arbitrary strings like `'0xdeadbeef'` or `'test-key'` will fail
validation at runtime — even if TypeScript accepts them as `string`.

The `sample*` functions generate valid, well-formed test data. Use them
everywhere you need a fixture of a specific type.

---

## Using sample* Functions

```typescript
import {
  sampleCoinPublicKey,
  sampleContractAddress,
  sampleSigningKey,
  sampleEncryptionPublicKey,
  sampleIntentHash,
  sampleUserAddress,
  sampleDustSecretKey,
} from '@midnight-ntwrk/ledger-v8';

// GOOD: Use sample functions for valid test data
const pk = sampleCoinPublicKey();
const contractAddr = sampleContractAddress();
const signingKey = sampleSigningKey();
const encPk = sampleEncryptionPublicKey();
const intentHash = sampleIntentHash();
const userAddr = sampleUserAddress();
const dustSk = sampleDustSecretKey();

// BAD: Arbitrary strings fail validation at runtime
// const pk = '0xdeadbeef';           // Wrong length
// const contractAddr = 'my-contract'; // Not a valid hex string
// const rawType = '000000';           // Wrong length
```

There is no `sampleCoinSecretKey` export. A `CoinSecretKey` is obtained from
`ZswapSecretKeys` (`ZswapSecretKeys.fromSeed(seed).coinSecretKey`):

```typescript
import { ZswapSecretKeys } from '@midnight-ntwrk/ledger-v8';

const secretKeys = ZswapSecretKeys.fromSeed(new Uint8Array(32).fill(1));
const coinSk = secretKeys.coinSecretKey; // CoinSecretKey
const coinPk = secretKeys.coinPublicKey; // CoinPublicKey
```

### Deterministic Fixtures

`sample*` functions return the same value every time — they are deterministic
stubs, not random generators. Use them freely in test setup.

```typescript
beforeEach(() => {
  pk = sampleCoinPublicKey();
  contractAddr = sampleContractAddress();
});
```

---

## Testing coinCommitment and coinNullifier

### coinCommitment

A coin commitment is a deterministic function of `(CoinInfo, CoinPublicKey)`.
The same inputs always produce the same output.

```typescript
import { coinCommitment, sampleCoinPublicKey } from '@midnight-ntwrk/ledger-v8';

it('should produce deterministic commitment', () => {
  const coin = createShieldedCoinInfo(tokenType, value);
  const pk = sampleCoinPublicKey();

  const commitment1 = coinCommitment(coin, pk);
  const commitment2 = coinCommitment(coin, pk);

  expect(commitment1).toBe(commitment2);          // Deterministic
  expect(typeof commitment1).toBe('string');       // Hex string
  expect(commitment1.length).toBe(64);             // 32 bytes = 64 hex chars
});

it('should produce different commitments for different keys', () => {
  const coin = createShieldedCoinInfo(tokenType, value);
  const pk1 = sampleCoinPublicKey();
  const pk2 = sampleCoinPublicKey(); // different sample (incremented)

  const c1 = coinCommitment(coin, pk1);
  const c2 = coinCommitment(coin, pk2);

  expect(c1).not.toBe(c2);
});
```

### coinNullifier

A coin nullifier is a deterministic function of `(CoinInfo, CoinSecretKey)`.
Once a nullifier appears on-chain, the coin is spent.

`coinNullifier(coin, coinSecretKey)` takes a `CoinSecretKey` obtained from
`ZswapSecretKeys` (there is no `sampleCoinSecretKey`).

```typescript
import { coinNullifier, ZswapSecretKeys } from '@midnight-ntwrk/ledger-v8';

it('should produce deterministic nullifier', () => {
  const coin = createShieldedCoinInfo(tokenType, value);
  const sk = ZswapSecretKeys.fromSeed(new Uint8Array(32).fill(1)).coinSecretKey;

  const nullifier1 = coinNullifier(coin, sk);
  const nullifier2 = coinNullifier(coin, sk);

  expect(nullifier1).toBe(nullifier2);          // Deterministic
  expect(typeof nullifier1).toBe('string');     // Hex string
  expect(nullifier1.length).toBe(64);           // 32 bytes = 64 hex chars
});

it('commitment and nullifier should be different', () => {
  const coin = createShieldedCoinInfo(tokenType, value);
  const secretKeys = ZswapSecretKeys.fromSeed(new Uint8Array(32).fill(1));

  const commitment = coinCommitment(coin, secretKeys.coinPublicKey);
  const nullifier = coinNullifier(coin, secretKeys.coinSecretKey);

  expect(commitment).not.toBe(nullifier);
});
```

---

## Testing Token Type Functions

`@midnight-ntwrk/ledger-v8` exports helper functions that construct token
types: `nativeToken()` (the native NIGHT `UnshieldedTokenType`), `feeToken()`
(the Dust fee `DustTokenType`), and the default-for-testing `shieldedToken()`
(`ShieldedTokenType`) / `unshieldedToken()` (`UnshieldedTokenType`). These take
NO arguments. To derive a token type for a custom contract domain, use
`rawTokenType(domainSeparator, contractAddress)`.

```typescript
import {
  nativeToken,
  feeToken,
  shieldedToken,
  unshieldedToken,
} from '@midnight-ntwrk/ledger-v8';

it('should have the correct discriminant tags', () => {
  // Each call returns a fresh object — use .tag to identify the token kind.
  expect(nativeToken().tag).toBe('unshielded');   // NIGHT — UnshieldedTokenType
  expect(feeToken().tag).toBe('dust');             // DUST  — DustTokenType
  expect(shieldedToken().tag).toBe('shielded');    // default ShieldedTokenType
  expect(unshieldedToken().tag).toBe('unshielded'); // default UnshieldedTokenType
});

it('nativeToken should return the same value across calls', () => {
  // Use toStrictEqual (deep equality) — each call returns a fresh object,
  // so toBe (reference equality) would fail.
  expect(nativeToken()).toStrictEqual(nativeToken());
});

it('should distinguish token kinds by tag', () => {
  // Compare across DIFFERENT token kinds using .tag.
  // Note: nativeToken() and unshieldedToken() are deep-equal — both have
  // tag 'unshielded' with an all-zeros raw value — so don't assert they differ.
  expect(shieldedToken().tag).not.toBe(nativeToken().tag);
  expect(feeToken().tag).not.toBe(nativeToken().tag);
  expect(feeToken().tag).not.toBe(shieldedToken().tag);
});
```

---

## Encode/Decode Round-Trip Testing

Many ledger types have `encode*` / `decode*` function pairs. Round-trip tests
verify that encoding and decoding are inverse operations.

### CoinPublicKey

```typescript
import {
  encodeCoinPublicKey,
  decodeCoinPublicKey,
  sampleCoinPublicKey,
} from '@midnight-ntwrk/ledger-v8';

it('should round-trip CoinPublicKey encoding', () => {
  const pk = sampleCoinPublicKey();
  const encoded = encodeCoinPublicKey(pk);
  const decoded = decodeCoinPublicKey(encoded);

  expect(decoded).toBe(pk);
});
```

### ContractAddress

```typescript
import {
  encodeContractAddress,
  decodeContractAddress,
  sampleContractAddress,
} from '@midnight-ntwrk/ledger-v8';

it('should round-trip ContractAddress encoding', () => {
  const addr = sampleContractAddress();
  const encoded = encodeContractAddress(addr);
  const decoded = decodeContractAddress(encoded);

  expect(decoded).toBe(addr);
});
```

### Pattern: Generic Round-Trip Helper

For multiple types, extract a helper to avoid duplication:

```typescript
function roundTripTest<T>(
  label: string,
  sample: () => T,
  encode: (v: T) => Uint8Array,
  decode: (b: Uint8Array) => T,
) {
  it(`should round-trip ${label}`, () => {
    const original = sample();
    const encoded = encode(original);
    const decoded = decode(encoded);
    expect(decoded).toBe(original);
  });
}

roundTripTest(
  'CoinPublicKey',
  sampleCoinPublicKey,
  encodeCoinPublicKey,
  decodeCoinPublicKey,
);

roundTripTest(
  'ContractAddress',
  sampleContractAddress,
  encodeContractAddress,
  decodeContractAddress,
);
```

---

## Testing signData and verifySignature

`SigningKey` and `SignatureVerifyingKey` are hex `string` types (not classes).
Derive the verifying key from the signing key with the free function
`signatureVerifyingKey(signingKey)` — there is no `signingKey.publicKey()`
method.

```typescript
import {
  signData,
  verifySignature,
  signatureVerifyingKey,
  sampleSigningKey,
} from '@midnight-ntwrk/ledger-v8';

it('should produce a verifiable signature', () => {
  const signingKey = sampleSigningKey();
  const data = new Uint8Array([1, 2, 3, 4]);

  const signature = signData(signingKey, data);
  const verifyingKey = signatureVerifyingKey(signingKey);

  const valid = verifySignature(verifyingKey, data, signature);
  expect(valid).toBe(true);
});

it('should reject signature for different data', () => {
  const signingKey = sampleSigningKey();
  const data = new Uint8Array([1, 2, 3, 4]);
  const otherData = new Uint8Array([5, 6, 7, 8]);

  const signature = signData(signingKey, data);
  const verifyingKey = signatureVerifyingKey(signingKey);

  const valid = verifySignature(verifyingKey, otherData, signature);
  expect(valid).toBe(false);
});

it('should reject signature from different key', () => {
  const signingKey1 = sampleSigningKey();
  const signingKey2 = sampleSigningKey(); // different key
  const data = new Uint8Array([1, 2, 3, 4]);

  const signature = signData(signingKey1, data);
  const wrongVerifyingKey = signatureVerifyingKey(signingKey2);

  const valid = verifySignature(wrongVerifyingKey, data, signature);
  expect(valid).toBe(false);
});
```

---

## Fixture Organisation

For tests that use many crypto types, organise fixtures in a shared setup file:

```typescript
// test/fixtures/ledger-fixtures.ts
import {
  sampleCoinPublicKey,
  sampleContractAddress,
  sampleRawTokenType,
  sampleSigningKey,
  sampleEncryptionPublicKey,
  nativeToken,
  feeToken,
  ZswapSecretKeys,
} from '@midnight-ntwrk/ledger-v8';

export function createLedgerFixtures() {
  const secretKeys = ZswapSecretKeys.fromSeed(new Uint8Array(32).fill(1));
  return {
    coinPk: sampleCoinPublicKey(),
    coinSk: secretKeys.coinSecretKey, // no sampleCoinSecretKey — derive from ZswapSecretKeys
    contractAddr: sampleContractAddress(),
    rawTokenType: sampleRawTokenType(),
    signingKey: sampleSigningKey(),
    encPk: sampleEncryptionPublicKey(),
    nightToken: nativeToken(),
    feeToken: feeToken(),
  };
}
```

Then in tests:

```typescript
let fixtures: ReturnType<typeof createLedgerFixtures>;

beforeEach(() => {
  fixtures = createLedgerFixtures();
});
```
