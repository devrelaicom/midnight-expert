# Genesis Seed (Local Devnet Only)

The local devnet's `dev` preset pre-mints NIGHT tokens to the wallet
derived from this seed:

    0000000000000000000000000000000000000000000000000000000000000001

Building a wallet from this seed against the local devnet gives access
to the pre-minted NIGHT, which is the standard way to fund test wallets
for development workflows.

## Why it works

`templates/devnet.yml` sets `CFG_PRESET: 'dev'` on the node service.
The `dev` preset's chain spec includes a pre-mint to the wallet derived
from the seed above.

## When to use it

Funding test wallets on the local devnet. See
`midnight-wallet:managing-test-wallets` for the SDK-driven funding
pattern that uses this seed.

## Security warning

LOCAL DEVNET ONLY. This seed is well-known. Never use it on `preprod`,
`preview`, or any environment that handles real value. Anyone running
the local devnet has full access to the funds at this seed.
