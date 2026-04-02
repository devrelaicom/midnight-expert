# DApp Connector Error Handling Test Patterns

Test patterns for each of the 5 DApp Connector API error codes.

## Error Code Taxonomy

| Code | Transient? | DApp Response | Test Strategy |
|---|---|---|---|
| `InternalError` | Maybe | Show error, allow retry | Inject error, assert UI shows message |
| `InvalidRequest` | No | Fix request, don't retry | Should not happen with correct code; test guards |
| `Rejected` | Yes | Allow user to retry | Inject on first call, succeed on second |
| `PermissionRejected` | No (per session) | Degrade gracefully | Inject error, assert feature is hidden/disabled |
| `Disconnected` | Yes | Reconnect | Inject error, assert reconnection attempt |

## Testing Rejected vs PermissionRejected

This is the most important distinction. `Rejected` means "not this time",
`PermissionRejected` means "not ever (this session)".

```typescript
describe('submitTransaction error handling', () => {
  it('should allow retry after Rejected', async () => {
    let attempts = 0;
    const stub = createWalletStub({
      errors: {
        // Only reject the first attempt
        submitTransaction: 'Rejected',
      },
    });

    const wallet = await stub.connect('undeployed');

    // First attempt — rejected
    await expect(wallet.submitTransaction('tx')).rejects.toMatchObject({
      code: 'Rejected',
    });

    // DApp should show "try again" UI, not disable the button
    // (assert on your DApp's state/UI here)
  });

  it('should disable feature after PermissionRejected', async () => {
    const stub = createWalletStub({
      errors: { submitTransaction: 'PermissionRejected' },
    });

    const wallet = await stub.connect('undeployed');

    await expect(wallet.submitTransaction('tx')).rejects.toMatchObject({
      code: 'PermissionRejected',
    });

    // DApp should disable submit button for this session
    // DApp should NOT retry
    // (assert on your DApp's state/UI here)
  });
});
```

## Testing Disconnected Recovery

```typescript
describe('disconnection handling', () => {
  it('should detect disconnection and attempt reconnect', async () => {
    const stub = createWalletStub({
      connectionStatus: { status: 'disconnected' },
    });

    const wallet = await stub.connect('undeployed');
    const status = await wallet.getConnectionStatus();

    expect(status.status).toBe('disconnected');
    // DApp should show "reconnecting..." state
    // DApp should call connect() again
  });

  it('should handle Disconnected error during operation', async () => {
    const stub = createWalletStub({
      errors: { getShieldedBalances: 'Disconnected' },
    });

    const wallet = await stub.connect('undeployed');

    await expect(wallet.getShieldedBalances()).rejects.toMatchObject({
      code: 'Disconnected',
    });

    // DApp should show reconnection UI
    // DApp should retry after reconnection
  });
});
```

## Testing Progressive Enhancement

Test that your DApp works with reduced API surface:

```typescript
describe('progressive enhancement', () => {
  it('should work without proving delegation', async () => {
    const stub = createWalletStub({
      errors: { getProvingProvider: 'PermissionRejected' },
    });

    const wallet = await stub.connect('undeployed');

    // DApp should fall back to client-side proving
    // DApp should NOT show an error
    // Core functionality (transfers, balances) should still work
  });

  it('should work without hintUsage', async () => {
    const stub = createWalletStub({
      errors: { hintUsage: 'PermissionRejected' },
    });

    const wallet = await stub.connect('undeployed');

    // DApp should still function
    // Permission prompts may appear per-method instead of upfront
  });

  it('should work with all balance methods rejected', async () => {
    const stub = createRestrictedWallet([
      'getShieldedBalances',
      'getUnshieldedBalances',
      'getDustBalance',
    ]);

    const wallet = await stub.connect('undeployed');

    // DApp should hide balance display
    // Transfer functionality may be limited
    // DApp should NOT crash
  });
});
```

## Testing XSS Prevention

The spec requires DApps to sanitize wallet-provided name and icon:

```typescript
describe('wallet name/icon sanitization', () => {
  it('should render wallet name as text, not HTML', () => {
    const stub = createWalletStub({
      name: '<img src=x onerror=alert(1)>',
    });

    // Render your wallet selector component with this stub
    // Assert: the name appears as literal text, no tag interpretation
    // Assert: no script execution occurred
  });

  it('should render wallet icon in img tag only', () => {
    const stub = createWalletStub({
      icon: 'data:image/svg+xml,<svg onload="alert(1)"/>',
    });

    // Render your wallet selector component with this stub
    // Assert: icon is rendered as <img src="...">, not inline <svg>
  });
});
```

## Testing apiVersion Validation

```typescript
describe('wallet version validation', () => {
  it('should reject incompatible wallet version', () => {
    const stub = createWalletStub({
      apiVersion: '0.1.0', // too old
    });

    // DApp should check semver compatibility before calling connect()
    // Assert: DApp shows "wallet version not supported" message
  });

  it('should accept compatible wallet version', () => {
    const stub = createWalletStub({
      apiVersion: '1.2.0', // compatible with ^1.0.0
    });

    // DApp should proceed with connection
  });
});
```

## Testing Duplicate Wallet Detection

```typescript
describe('duplicate wallet detection', () => {
  it('should warn if multiple wallets share the same rdns', () => {
    const stub1 = createWalletStub();
    const stub2 = createWalletStub();
    // Both have rdns: 'com.test.wallet'

    // Inject both into window.midnight with different UUIDs
    // DApp should detect the duplicate rdns and warn the user
  });
});
```
