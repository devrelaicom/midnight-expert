# Test Examples Reference

Each section shows a **good** and **bad** example pair. Good examples follow OpenZeppelin patterns observed in the actual test suite. Bad examples show the common mistakes they correct.

---

## 1. Access Control

Test both the authorized path and the unauthorized path. A test that only checks the happy path gives false confidence.

### Bad -- happy-path only

```typescript
describe('transferOwnership', () => {
  it('should transfer ownership', () => {
    ownable.as(OWNER).transferOwnership(Z_NEW_OWNER);
    expect(ownable.owner()).toEqual(Z_NEW_OWNER);
  });
});
```

### Good -- both `.as(OWNER)` and `.as(UNAUTHORIZED)`

```typescript
describe('transferOwnership', () => {
  it('should transfer ownership', () => {
    ownable.as(OWNER).transferOwnership(Z_NEW_OWNER);
    expect(ownable.owner()).toEqual(Z_NEW_OWNER);

    // Verify original owner lost permissions
    expect(() => {
      ownable.as(OWNER).assertOnlyOwner();
    }).toThrow('Ownable: caller is not the owner');

    // Verify new owner gained permissions
    expect(() => {
      ownable.as(NEW_OWNER).assertOnlyOwner();
    }).not.toThrow();
  });

  it('should fail when unauthorized transfers ownership', () => {
    expect(() => {
      ownable.as(UNAUTHORIZED).transferOwnership(Z_NEW_OWNER);
    }).toThrow('Ownable: caller is not the owner');
  });
});
```

---

## 2. State Mutation

Assert state both **before and after** the mutation. Asserting only the final state does not prove the operation actually changed anything -- the initial state might already match.

### Bad -- only final state

```typescript
it('should mint tokens', () => {
  token._mint(Z_OWNER, AMOUNT);
  expect(token.balanceOf(Z_OWNER)).toEqual(AMOUNT);
});
```

### Good -- assert before AND after

```typescript
it('should mint and update supply', () => {
  expect(token.totalSupply()).toEqual(0n);

  token._mint(Z_RECIPIENT, AMOUNT);
  expect(token.totalSupply()).toEqual(AMOUNT);
  expect(token.balanceOf(Z_RECIPIENT)).toEqual(AMOUNT);
});
```

For transfers, verify both the sender and receiver balance changed:

```typescript
beforeEach(() => {
  token._mint(Z_OWNER, AMOUNT);
  expect(token.balanceOf(Z_OWNER)).toEqual(AMOUNT);
  expect(token.balanceOf(Z_RECIPIENT)).toEqual(0n);
});

it('should transfer full balance', () => {
  const txSuccess = token.as(OWNER).transfer(Z_RECIPIENT, AMOUNT);

  expect(txSuccess).toBe(true);
  expect(token.balanceOf(Z_OWNER)).toEqual(0n);
  expect(token.balanceOf(Z_RECIPIENT)).toEqual(AMOUNT);
});
```

---

## 3. Error Message Assertion

Always assert the **exact error string**. A bare `.toThrow()` passes for any exception, including bugs in your test setup.

### Bad -- bare `.toThrow()`

```typescript
it('should fail when unauthorized', () => {
  expect(() => {
    ownable.as(UNAUTHORIZED).transferOwnership(Z_NEW_OWNER);
  }).toThrow();
});
```

### Good -- exact error string

```typescript
it('should fail when unauthorized transfers ownership', () => {
  expect(() => {
    ownable.as(UNAUTHORIZED).transferOwnership(Z_NEW_OWNER);
  }).toThrow('Ownable: caller is not the owner');
});

it('should fail with insufficient balance', () => {
  expect(() => {
    token.as(OWNER).transfer(Z_RECIPIENT, AMOUNT + 1n);
  }).toThrow('FungibleToken: insufficient balance');
});

it('should fail when minting to zero', () => {
  expect(() => {
    token._mint(utils.ZERO_KEY, AMOUNT);
  }).toThrow('FungibleToken: invalid receiver');
});
```

---

## 4. Initialization Guards

Use `it.each` to verify **all** circuits fail before initialization. Testing a single circuit leaves others unguarded.

### Bad -- testing one circuit

```typescript
describe('when not initialized', () => {
  it('should fail to get owner', () => {
    const ownable = new OwnableSimulator(Z_OWNER, false);
    expect(() => ownable.owner()).toThrow('Initializable: contract not initialized');
  });
});
```

### Good -- `it.each` over all circuits

```typescript
describe('when not initialized correctly', () => {
  beforeEach(() => {
    token = new FungibleTokenSimulator(EMPTY_STRING, EMPTY_STRING, NO_DECIMALS, BAD_INIT);
  });

  type FailingCircuits = [method: keyof FungibleTokenSimulator, args: unknown[]];

  const circuitsToFail: FailingCircuits[] = [
    ['name', []],
    ['symbol', []],
    ['decimals', []],
    ['totalSupply', []],
    ['balanceOf', [Z_OWNER]],
    ['allowance', [Z_OWNER, Z_SPENDER]],
    ['transfer', [Z_RECIPIENT, AMOUNT]],
    ['_unsafeTransfer', [Z_RECIPIENT, AMOUNT]],
    ['transferFrom', [Z_OWNER, Z_RECIPIENT, AMOUNT]],
    ['approve', [Z_OWNER, AMOUNT]],
    ['_approve', [Z_OWNER, Z_SPENDER, AMOUNT]],
    ['_transfer', [Z_OWNER, Z_RECIPIENT, AMOUNT]],
    ['_mint', [Z_OWNER, AMOUNT]],
    ['_burn', [Z_OWNER, AMOUNT]],
  ];

  it.each(circuitsToFail)('%s should fail', (circuitName, args) => {
    expect(() => {
      (token[circuitName] as (...args: unknown[]) => unknown)(...args);
    }).toThrow('Initializable: contract not initialized');
  });
});
```

---

## 5. Token Operations

Use `afterEach` supply invariant checks to catch bugs that individual test assertions miss. Always verify balances, allowances, and overflow boundaries.

### Bad -- no invariant, no boundary

```typescript
describe('transfer', () => {
  it('should transfer tokens', () => {
    token._mint(Z_OWNER, AMOUNT);
    token.as(OWNER).transfer(Z_RECIPIENT, AMOUNT);
    expect(token.balanceOf(Z_RECIPIENT)).toEqual(AMOUNT);
  });
});
```

### Good -- balance assertions, `afterEach` invariant, overflow test

```typescript
describe('transfer', () => {
  beforeEach(() => {
    token._mint(Z_OWNER, AMOUNT);
    expect(token.balanceOf(Z_OWNER)).toEqual(AMOUNT);
    expect(token.balanceOf(Z_RECIPIENT)).toEqual(0n);
  });

  afterEach(() => {
    // Invariant: total supply never changes during transfers
    expect(token.totalSupply()).toEqual(AMOUNT);
  });

  it('should transfer partial', () => {
    const partialAmt = AMOUNT - 1n;
    const txSuccess = token.as(OWNER).transfer(Z_RECIPIENT, partialAmt);

    expect(txSuccess).toBe(true);
    expect(token.balanceOf(Z_OWNER)).toEqual(1n);
    expect(token.balanceOf(Z_RECIPIENT)).toEqual(partialAmt);
  });

  it('should transfer full', () => {
    const txSuccess = token.as(OWNER).transfer(Z_RECIPIENT, AMOUNT);

    expect(txSuccess).toBe(true);
    expect(token.balanceOf(Z_OWNER)).toEqual(0n);
    expect(token.balanceOf(Z_RECIPIENT)).toEqual(AMOUNT);
  });

  it('should fail with insufficient balance', () => {
    expect(() => {
      token.as(OWNER).transfer(Z_RECIPIENT, AMOUNT + 1n);
    }).toThrow('FungibleToken: insufficient balance');
  });

  it('should allow transfer of 0 tokens', () => {
    const txSuccess = token.as(OWNER).transfer(Z_RECIPIENT, 0n);

    expect(txSuccess).toBe(true);
    expect(token.balanceOf(Z_OWNER)).toEqual(AMOUNT);
    expect(token.balanceOf(Z_RECIPIENT)).toEqual(0n);
  });
});

describe('_mint', () => {
  it('should catch mint overflow', () => {
    const MAX_UINT128 = BigInt(2 ** 128) - BigInt(1);
    token._mint(Z_RECIPIENT, MAX_UINT128);

    expect(() => {
      token._mint(Z_RECIPIENT, 1n);
    }).toThrow('FungibleToken: arithmetic overflow');
  });
});
```

Allowance tests should verify the full lifecycle -- set, spend, check remaining:

```typescript
it('should transfer exact allowance and fail subsequent transfer', () => {
  token._mint(Z_OWNER, AMOUNT);
  token.as(OWNER).approve(Z_SPENDER, AMOUNT);

  token.as(SPENDER).transferFrom(Z_OWNER, Z_RECIPIENT, AMOUNT);
  expect(token.allowance(Z_OWNER, Z_SPENDER)).toEqual(0n);

  expect(() => {
    token.as(SPENDER).transferFrom(Z_OWNER, Z_RECIPIENT, 1n);
  }).toThrow('FungibleToken: insufficient allowance');
});
```

---

## 6. ZK Commitment Verification

When testing ZK-based ownership (like `ZOwnablePK`), recompute commitments locally and compare against the contract. Never just assert "not zero".

### Bad -- "not zero" assertion

```typescript
it('should set owner commitment', () => {
  const commitment = ownable.owner();
  expect(commitment).not.toEqual(new Uint8Array(32).fill(0));
});
```

### Good -- local recomputation

```typescript
const createIdHash = (pk: ZswapCoinPublicKey, nonce: Uint8Array): Uint8Array => {
  const rt_type = new CompactTypeVector(2, new CompactTypeBytes(32));
  return persistentHash(rt_type, [pk.bytes, nonce]);
};

const buildCommitmentFromId = (
  id: Uint8Array, instanceSalt: Uint8Array, counter: bigint,
): Uint8Array => {
  const rt_type = new CompactTypeVector(4, new CompactTypeBytes(32));
  const bCounter = convertFieldToBytes(32, counter, '');
  const bDomain = new TextEncoder().encode(DOMAIN);
  return persistentHash(rt_type, [id, instanceSalt, bCounter, bDomain]);
};

it('should return the correct owner commitment', () => {
  const expCommitment = buildCommitment(
    Z_OWNER, secretNonce, INSTANCE_SALT, INIT_COUNTER, DOMAIN,
  );
  expect(ownable.owner()).toEqual(expCommitment);
});

it('should change commitment when transferring to self', () => {
  const repeatedId = createIdHash(Z_OWNER, secretNonce);
  const initCommitment = ownable.owner();

  ownable.as(OWNER).transferOwnership(repeatedId);
  const newCommitment = ownable.owner();

  // Same owner, same id -- but commitment differs due to counter bump
  expect(initCommitment).not.toEqual(newCommitment);

  const bumpedCounter = INIT_COUNTER + 1n;
  const expNewCommitment = buildCommitmentFromId(repeatedId, INSTANCE_SALT, bumpedCounter);
  expect(newCommitment).toEqual(expNewCommitment);
});
```

---

## 7. Parameterized Testing

Use `describe.each` and `it.each` to test the same logic across different inputs. Avoid copy-pasting near-identical tests.

### Bad -- copy-paste for contract vs pubkey

```typescript
it('should transfer ownership to a pubkey', () => {
  ownable.as(OWNER)._unsafeTransferOwnership(Z_NEW_OWNER);
  expect(ownable.owner()).toEqual(Z_NEW_OWNER);
});

it('should transfer ownership to a contract', () => {
  ownable.as(OWNER)._unsafeTransferOwnership(Z_OWNER_CONTRACT);
  expect(ownable.owner()).toEqual(Z_OWNER_CONTRACT);
});
```

### Good -- `describe.each` with named types

```typescript
const newOwnerTypes = [
  ['contract', Z_OWNER_CONTRACT],
  ['pubkey', Z_NEW_OWNER],
] as const;

describe.each(newOwnerTypes)('when the owner is a %s', (type, newOwner) => {
  it('should transfer ownership', () => {
    ownable.as(OWNER)._unsafeTransferOwnership(newOwner);
    expect(ownable.owner()).toEqual(newOwner);

    // Original owner lost permissions
    expect(() => {
      ownable.as(OWNER).assertOnlyOwner();
    }).toThrow('Ownable: caller is not the owner');

    if (type === 'pubkey') {
      expect(() => {
        ownable.as(NEW_OWNER).assertOnlyOwner();
      }).not.toThrow();
    }
  });
});
```

For hash computation, use `it.each` with descriptive labels:

```typescript
const testCases = [
  ...Array.from({ length: 10 }, (_, i) => ({
    label: `User${i}`,
    ownerPK: utils.encodeToPK(`User${i}`),
    counter: BigInt(Math.floor(Math.random() * 2 ** 64 - 1)),
  })),
  { label: 'ZeroCounter', ownerPK: utils.encodeToPK('ZeroCounter'), counter: 0n },
  { label: 'MaxCounter', ownerPK: utils.encodeToPK('MaxUser'), counter: MAX_U64 },
];

it.each(testCases)(
  'should match commitment for $label with counter $counter',
  ({ ownerPK, counter }) => {
    const id = createIdHash(ownerPK, secretNonce);
    const hashFromContract = ownable._computeOwnerCommitment(id, counter);
    const hashFromHelper = buildCommitmentFromId(id, INSTANCE_SALT, counter);
    expect(hashFromContract).toEqual(hashFromHelper);
  },
);
```

---

## 8. Test Isolation

Use `beforeEach` to create a fresh simulator for every test. Shared mutable state between tests causes ordering-dependent failures.

### Bad -- shared state

```typescript
describe('Ownable', () => {
  const ownable = new OwnableSimulator(Z_OWNER, true);

  it('should transfer ownership', () => {
    ownable.as(OWNER).transferOwnership(Z_NEW_OWNER);
    expect(ownable.owner()).toEqual(Z_NEW_OWNER);
  });

  it('should renounce ownership', () => {
    // BROKEN: ownable.owner() is now Z_NEW_OWNER from previous test
    ownable.as(OWNER).renounceOwnership();
  });
});
```

### Good -- `beforeEach` fresh simulator

```typescript
describe('Ownable', () => {
  let ownable: OwnableSimulator;

  beforeEach(() => {
    ownable = new OwnableSimulator(Z_OWNER, true);
  });

  it('should transfer ownership', () => {
    ownable.as(OWNER).transferOwnership(Z_NEW_OWNER);
    expect(ownable.owner()).toEqual(Z_NEW_OWNER);
  });

  it('should renounce ownership', () => {
    expect(ownable.owner()).toEqual(Z_OWNER);
    ownable.as(OWNER).renounceOwnership();
    expect(ownable.owner()).toEqual(utils.ZERO_KEY);
  });
});
```

For ZK contracts with generated private state, create both the private state and derived values in `beforeEach`:

```typescript
let secretNonce: Uint8Array;
let ownable: ZOwnablePKSimulator;

beforeEach(() => {
  const PS = ZOwnablePKPrivateState.generate();
  secretNonce = PS.secretNonce;
  const ownerId = createIdHash(Z_OWNER, secretNonce);
  ownable = new ZOwnablePKSimulator(ownerId, INSTANCE_SALT, isInit, {
    privateState: PS,
  });
});
```

---

## 9. Property-Based Testing

For math-heavy circuits (hash computation, overflow checks, counter arithmetic), use `fast-check` to explore the input space systematically rather than picking a few manual values.

### Bad -- a few hand-picked values

```typescript
it('should compute commitment for counter 0', () => {
  const hash = ownable._computeOwnerCommitment(id, 0n);
  expect(hash).toEqual(buildCommitmentFromId(id, INSTANCE_SALT, 0n));
});

it('should compute commitment for counter 1', () => {
  const hash = ownable._computeOwnerCommitment(id, 1n);
  expect(hash).toEqual(buildCommitmentFromId(id, INSTANCE_SALT, 1n));
});
```

### Good -- `fast-check` for exhaustive coverage

```typescript
import * as fc from 'fast-check';

describe('_computeOwnerCommitment', () => {
  it('should match local computation for arbitrary counters', () => {
    fc.assert(
      fc.property(
        fc.bigUintN(64),
        (counter) => {
          const hashFromContract = ownable._computeOwnerCommitment(id, counter);
          const hashFromHelper = buildCommitmentFromId(id, INSTANCE_SALT, counter);
          expect(hashFromContract).toEqual(hashFromHelper);
        },
      ),
    );
  });

  it('should produce unique commitments for different counters', () => {
    fc.assert(
      fc.property(
        fc.bigUintN(64),
        fc.bigUintN(64),
        (counter1, counter2) => {
          fc.pre(counter1 !== counter2);
          const hash1 = ownable._computeOwnerCommitment(id, counter1);
          const hash2 = ownable._computeOwnerCommitment(id, counter2);
          expect(hash1).not.toEqual(hash2);
        },
      ),
    );
  });
});
```

For token arithmetic, verify conservation laws:

```typescript
it('should conserve total supply across transfers', () => {
  fc.assert(
    fc.property(
      fc.bigUint({ max: AMOUNT }),
      (transferAmount) => {
        const freshToken = new FungibleTokenSimulator(NAME, SYMBOL, DECIMALS, INIT);
        freshToken._mint(Z_OWNER, AMOUNT);

        const supplyBefore = freshToken.totalSupply();
        freshToken.as(OWNER).transfer(Z_RECIPIENT, transferAmount);
        const supplyAfter = freshToken.totalSupply();

        expect(supplyBefore).toEqual(supplyAfter);
      },
    ),
  );
});
```
