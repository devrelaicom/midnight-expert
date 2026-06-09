# Governance Internals — Federated Authority Deep Dive

Detailed pallet-level mechanics for the two-body governance system in Midnight node 1.0.0. The SKILL.md covers the user-facing model; this file covers what the source actually wires together.

All citations are from `/tmp/mn-audit/midnight-node` @ tag `node-1.0.0`.

---

## The Two Collective Bodies

Both bodies are instances of `pallet_collective` sharing identical configuration constants.

```
runtime/src/lib.rs:688-720   (Council)
runtime/src/lib.rs:752-774   (TechnicalCommittee)
```

| Parameter | Value | Source |
|-----------|-------|--------|
| `MOTION_DURATION` | `5 * DAYS` = **72 000 blocks** (~5 days at 6 s/block) | `runtime/src/lib.rs:688` |
| `MAX_PROPOSALS` | `100` | `runtime/src/lib.rs:689` |
| `MAX_MEMBERS` | `10` | `runtime/src/lib.rs:690` |
| Approval threshold | `EnsureProportionAtLeast<AccountId, _, 2, 3>` | `runtime/src/lib.rs:808,812` |
| `DefaultVote` (production) | `AlwaysNo` — absentee votes count as Nay | `runtime/src/lib.rs:707,761` |
| `MaxProposalWeight` | 50 % of max block weight | `runtime/src/lib.rs:694` |

Block-time arithmetic (`runtime/src/constants.rs`):

```
MILLISECS_PER_BLOCK = 6 000
MINUTES = 60 000 / 6 000 = 10 blocks
HOURS   = 10 × 60         = 600 blocks
DAYS    = 600 × 24        = 14 400 blocks
5 * DAYS                  = 72 000 blocks   ← MOTION_DURATION
```

`runtime/src/constants.rs:5-12` defines these constants; `runtime/src/lib.rs:688` consumes them.

### Council — Instance1

```rust
// runtime/src/lib.rs:698-721
type CouncilCollectiveInstance = pallet_collective::Instance1;
impl pallet_collective::Config<CouncilCollectiveInstance> for Runtime {
    type MotionDuration = MotionDuration;          // 72 000 blocks
    type MaxProposals  = ConstU32<MAX_PROPOSALS>;  // 100
    type MaxMembers    = ConstU32<MAX_MEMBERS>;    // 10
    type DefaultVote   = AlwaysNo;                 // production only
    type SetMembersOrigin = NeverEnsureOrigin<()>; // production only
    type MaxProposalWeight = MaxProposalWeight;    // 50 % block weight
    type DisapproveOrigin = EnsureRoot<Self::AccountId>;
    type KillOrigin       = EnsureRoot<Self::AccountId>;
    ...
}
```

### TechnicalCommittee — Instance2

```rust
// runtime/src/lib.rs:752-774
type TechnicalCommitteeCollectiveInstance = pallet_collective::Instance2;
impl pallet_collective::Config<TechnicalCommitteeCollectiveInstance> for Runtime {
    // Identical constants — MotionDuration, MaxProposals, MaxMembers, AlwaysNo, etc.
    ...
}
```

`SetMembersOrigin = NeverEnsureOrigin<()>` in production prevents direct member manipulation via extrinsics; membership flows exclusively through `pallet_membership`.

---

## Membership Pallets

Both bodies use `pallet_membership` instances that mirror their collective instances.

| Instance | Collective | Type alias |
|----------|-----------|------------|
| `pallet_membership::Instance1` | Council (Instance1) | `CouncilMembershipInstance` |
| `pallet_membership::Instance2` | TechnicalCommittee (Instance2) | `TechnicalCommitteeMembershipInstance` |

`runtime/src/lib.rs:723,776`

### Production Origin Lock-Down

In production builds (`#[cfg(not(feature = "runtime-benchmarks"))]`):

```rust
// runtime/src/lib.rs:729-742  (CouncilMembership; TCMembership is identical, :781-792)
type AddOrigin    = NeverEnsureOrigin<()>;
type RemoveOrigin = NeverEnsureOrigin<()>;
type SwapOrigin   = NeverEnsureOrigin<()>;
type PrimeOrigin  = NeverEnsureOrigin<()>;
type ResetOrigin  = EnsureNone<Self::AccountId>; // called by RawOrigin::None (inherent)
```

`NeverEnsureOrigin` blocks the individual add/remove/swap/prime extrinsics unconditionally. The only live path is `reset_members`, which is gated on `EnsureNone` — meaning it must be called with `RawOrigin::None` origin, which only inherents can provide.

### Cardano-Driven Reset

`MembershipObservationHandler` (in `runtime/common/src/governance.rs:90-122`) implements `ChangeMembers` by dispatching `pallet_membership::Call::reset_members` via `RawOrigin::None`:

```rust
// runtime/common/src/governance.rs:96-103
fn change_members_sorted(_incoming, _outgoing, sorted_new) {
    let call = pallet_membership::Call::<T, I>::reset_members {
        members: sorted_new.to_vec()
    };
    let _ = call.dispatch_bypass_filter(frame_system::RawOrigin::None.into());
}
```

`pallet_federated_authority_observation` drives this handler when it processes the Cardano-sourced inherent carrying updated member lists:

```rust
// runtime/src/lib.rs:849-852
type CouncilMembershipHandler =
    MembershipObservationHandler<Runtime, CouncilMembershipInstance>;
type TechnicalCommitteeMembershipHandler =
    MembershipObservationHandler<Runtime, TechnicalCommitteeMembershipInstance>;
```

Cross-ref: `references/cardano-integration.md` for the full inherent delivery pipeline and Cardano address / policy ID storage (`MainChainCouncilAddress`, `MainChainCouncilPolicyId`, etc.).

---

## The Federated Authority Origin

`pallet_federated_authority` tracks multi-body approval for governance motions. Its key types are defined in `pallets/federated-authority/src/types.rs`.

### `FederatedAuthorityEnsureProportionAtLeast<N, D>`

```rust
// pallets/federated-authority/src/types.rs:103-110
pub struct FederatedAuthorityEnsureProportionAtLeast<const N: u32, const D: u32>;

impl<const N: u32, const D: u32> FederatedAuthorityProportion
    for FederatedAuthorityEnsureProportionAtLeast<N, D>
{
    fn reached_proportion(n: u32, d: u32) -> bool {
        n * D >= N * d   // n/d >= N/D
    }
}
```

The runtime wires `<1, 1>` — both bodies must have approved (proportion = 1/1 = 100 %):

```rust
// runtime/src/lib.rs:838
type MotionApprovalProportion = FederatedAuthorityEnsureProportionAtLeast<1, 1>;
```

`reached_proportion(n=1, d=2)` → `1*1 >= 1*2` → `false` (one of two is not enough).
`reached_proportion(n=2, d=2)` → `2*1 >= 1*2` → `true`  (both bodies approved).

### `AuthorityBody` and `FederatedAuthorityOriginManager`

Each body's approval is represented by an `AuthorityBody` wrapping the collective pallet and its `EnsureProportionAtLeast` guard:

```rust
// runtime/src/lib.rs:806-818
type CouncilApproval = AuthorityBody<
    Council,
    pallet_collective::EnsureProportionAtLeast<AccountId, CouncilCollectiveInstance, 2, 3>,
>;
type TechnicalCommitteeApproval = AuthorityBody<
    TechnicalCommittee,
    pallet_collective::EnsureProportionAtLeast<AccountId, TechnicalCommitteeCollectiveInstance, 2, 3>,
>;
```

Both are bundled into a `FederatedAuthorityOriginManager` tuple used as `MotionApprovalOrigin`:

```rust
// runtime/src/lib.rs:839-840
type MotionApprovalOrigin =
    FederatedAuthorityOriginManager<(CouncilApproval, TechnicalCommitteeApproval)>;
```

`FederatedAuthorityOriginManager::try_origin` iterates the tuple and returns the first that succeeds, yielding the `AuthId` (pallet index) of the approving body (`types.rs:81-96`). Approval by either body advances the motion's `approvals` set independently.

A symmetric `MotionRevokeOrigin` pair (`CouncilRevoke`, `TechnicalCommitteeRevoke`) allows an approving body to withdraw before the window closes (`runtime/src/lib.rs:820-842`).

---

## Motion Lifecycle

### Extrinsics

All three extrinsics are `DispatchClass::Operational` (`pallets/federated-authority/src/lib.rs:136,208,269`):

| Extrinsic | Call index | Who can call | Purpose |
|-----------|-----------|-------------|---------|
| `motion_approve(call)` | 0 | Validated member of either body (via `MotionApprovalOrigin`) | Submit or add body approval; creates motion on first call |
| `motion_revoke(motion_hash)` | 1 | Approving body member | Withdraw this body's approval before expiry |
| `motion_close(motion_hash, proposal_weight_bound)` | 2 | **Anyone** (`ensure_signed`) | Enact (or expire) a motion after the window |

`pallets/federated-authority/src/lib.rs:139,211,272-278`

### `motion_approve` — Independent Any-Order Approval

On first call, the motion is created with `ends_block = current_block + MOTION_DURATION` (72 000 blocks). On subsequent calls from a different body, its `AuthId` is inserted into `motion.approvals` (a `BoundedBTreeSet<AuthId, MaxAuthorityBodies>`). Because each body calls independently, Council and TechnicalCommittee can approve in any order with no sequencing requirement.

`pallets/federated-authority/src/lib.rs:149-195`

### `motion_close` — Enactment or Expiry

```rust
// pallets/federated-authority/src/lib.rs:262-353
pub fn motion_close(
    origin: OriginFor<T>,
    motion_hash: T::Hash,
    proposal_weight_bound: Weight,
) -> DispatchResultWithPostInfo {
    ensure_signed(origin)?;   // callable by anyone
    ...
    if Self::is_motion_approved(total_approvals) {
        // verify dispatch_weight <= proposal_weight_bound
        // dispatch via RawOrigin::Root in isolated storage layer
    } else if has_ended {
        // emit MotionExpired, remove motion
    } else {
        return Err(MotionNotEnded)
    }
}
```

Key mechanics:

- `proposal_weight_bound` — caller supplies a `Weight` upper bound. If the motion's actual call weight exceeds it, `motion_close` returns `MotionWeightBoundTooLow` without dispatching. This prevents unbounded block weight from governance calls.
- Dispatch runs inside `with_storage_layer` so a failed call rolls back its own storage mutations while the `MotionDispatched` event and motion removal persist.
- The call is dispatched as `frame_system::RawOrigin::Root` — governance motions execute with root privileges.
- `is_motion_approved` delegates to `FederatedAuthorityEnsureProportionAtLeast<1,1>::reached_proportion(approvals.len(), MaxAuthorityBodies)` — both bodies must have called `motion_approve`. `pallets/federated-authority/src/lib.rs:400-404`

### Two-Body Approval Flow

```text
Council member                            TechnicalCommittee member
     │                                              │
     ▼                                              ▼
motion_approve(call)                    motion_approve(call)
 • creates Motions[hash] if new          • inserts TC AuthId into approvals
 • inserts Council AuthId (pallet idx)   • (order irrelevant)
     │                                              │
     └─────────────── (any order) ─────────────────┘
                            │
                  approvals.len() == 2
                  reached_proportion(2, 2) → true
                            │
                    (window still open)
                            │
                   anyone calls
                   motion_close(hash, weight_bound)
                            │
               dispatch_weight <= weight_bound?
                    Yes ────┘
                            │
               dispatch(RawOrigin::Root)
                            │
                   MotionDispatched event
                   motion removed from storage
```

If either body never approves and `block_number >= ends_block`, `motion_close` emits `MotionExpired` and removes the motion.

---

## D-Parameter (`pallet_system_parameters`)

The D-parameter is an Ariadne `(num_permissioned_candidates, num_registered_candidates)` tuple — not a floating-point ratio.

```rust
// pallets/system-parameters/src/lib.rs:84-86
/// D-Parameter storage as (num_permissioned_candidates, num_registered_candidates)
/// Uses ValueQuery with default values of (0, 0)
pub type DParameterStorage<T: Config> = StorageValue<_, (u16, u16), ValueQuery>;
```

`pallets/system-parameters/src/lib.rs:84-86`

| Field | Type | Meaning |
|-------|------|---------|
| `num_permissioned_candidates` | `u16` | Federated (permissioned) seats in the block-producer committee |
| `num_registered_candidates` | `u16` | Staked (registered) seats in the block-producer committee |

A tuple of `(2, 5)` means Ariadne selects 2 permissioned and 5 registered candidates per committee epoch. There is no single scalar — both values are independent.

Default at genesis is `(0, 0)` (`ValueQuery` uses `Default::default()`). Genesis can override via `DParameterGenesisConfig` (`pallets/system-parameters/src/lib.rs:123`).

### Update Path

`update_d_parameter` is gated on `SystemOrigin = EnsureRoot<AccountId>` (`runtime/src/lib.rs:857`). In practice, root can only be obtained through a successful governance motion. The extrinsic signature:

```rust
// pallets/system-parameters/src/lib.rs:238-260
pub fn update_d_parameter(
    origin: OriginFor<T>,
    num_permissioned_candidates: u16,
    num_registered_candidates: u16,
) -> DispatchResult
```

### Query

`get_d_parameter` reads `DParameterStorage` and wraps it in the `sidechain_domain::DParameter` type:

```rust
// pallets/system-parameters/src/lib.rs:274-277
pub fn get_d_parameter() -> DParameter {
    let (num_permissioned, num_registered) = DParameterStorage::<T>::get();
    DParameter::new(num_permissioned, num_registered)
}
```

RPC method: `systemParameters_getDParameter` (`pallets/system-parameters/rpc/src/lib.rs:142`) returns a `DParameterRpcResponse { num_permissioned_candidates: u16, num_registered_candidates: u16 }`.

---

## Configuration Summary

| Item | Value | File:line |
|------|-------|-----------|
| `MOTION_DURATION` | 72 000 blocks (5 days × 14 400 blocks/day) | `runtime/src/lib.rs:688` |
| `MAX_PROPOSALS` (both bodies) | 100 | `runtime/src/lib.rs:689` |
| `MAX_MEMBERS` (both bodies) | 10 | `runtime/src/lib.rs:690` |
| Council collective | `pallet_collective::Instance1` | `runtime/src/lib.rs:698` |
| TechnicalCommittee collective | `pallet_collective::Instance2` | `runtime/src/lib.rs:752` |
| Council membership | `pallet_membership::Instance1` | `runtime/src/lib.rs:723` |
| TechnicalCommittee membership | `pallet_membership::Instance2` | `runtime/src/lib.rs:776` |
| Per-body approval threshold | `EnsureProportionAtLeast<_, _, 2, 3>` | `runtime/src/lib.rs:808,812` |
| Cross-body proportion | `FederatedAuthorityEnsureProportionAtLeast<1, 1>` | `runtime/src/lib.rs:838` |
| `motion_close` callable by | Anyone (`ensure_signed`) | `pallets/federated-authority/src/lib.rs:278` |
| `motion_close` dispatch class | `Operational` | `pallets/federated-authority/src/lib.rs:269` |
| D-parameter storage type | `StorageValue<_, (u16, u16), ValueQuery>` | `pallets/system-parameters/src/lib.rs:86` |
| D-parameter RPC | `systemParameters_getDParameter` | `pallets/system-parameters/rpc/src/lib.rs:142` |
| Membership `ResetOrigin` | `EnsureNone` (inherent-only) | `runtime/src/lib.rs:740,792` |
| Individual add/remove/swap | `NeverEnsureOrigin<()>` (blocked) | `runtime/src/lib.rs:729-742` |

---

## Cross-references

- `midnight-node:node-governance` — user-facing governance overview (the SKILL.md this file extends)
- `midnight-node:node-architecture` → `references/cardano-integration.md` — how `pallet_federated_authority_observation` delivers Cardano-sourced member lists via inherent and triggers `MembershipObservationHandler::reset_members`
- `midnight-node:node-architecture` → `references/pallet-inventory.md` — full list of runtime pallets and their roles
- `midnight-node:node-rpc-api` — `systemParameters_getDParameter`, `systemParameters_getAriadneParameters`, and other governance RPC endpoints
