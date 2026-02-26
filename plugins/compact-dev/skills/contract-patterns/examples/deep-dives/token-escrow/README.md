# Multi-Party Token Escrow

A comprehensive escrow system for Midnight supporting multiple parties, milestone payments, and dispute resolution.

## Overview

This escrow system provides:
- **Multi-party support** - Depositors, beneficiaries, and arbitrators
- **Milestone payments** - Staged releases based on progress
- **Dispute resolution** - Arbitrator-mediated conflict resolution
- **Timeout protection** - Automatic refunds if deadlines pass
- **Flexible configuration** - Customizable delays, windows, and approvals

## Files

| File | Purpose |
| ------ | --------- |
| `escrow.compact` | Core escrow contract with all functionality |

## State Machine

```
  ┌───────────┐
  │  Created  │
  └─────┬─────┘
        │ deposit() [all funded]
  ┌─────▼─────┐
  │  Funded   │───────┐
  └─────┬─────┘       │
        │             │ timeout
  completeMilestone() │
        │             │
  ┌─────▼──────┐      │
  │ InProgress │──────┤
  └─────┬──────┘      │
        │             │
  releaseMilestone()  │
        │             │
  ┌─────▼─────┐ ┌─────▼────┐
  │ Completed │ │ Refunded │
  └───────────┘ └──────────┘
```

## Related Patterns

- [Time Lock](../../simple/time-lock.compact) - Deadline enforcement
- [Multi-Sig](../../simple/multi-sig.compact) - Approval mechanism
- [Pausable](../../simple/pausable.compact) - Emergency stops
- [Fee Collector](../../simple/fee-collector.compact) - Service fees
