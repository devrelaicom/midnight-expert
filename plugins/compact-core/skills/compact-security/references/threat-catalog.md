# Compact Security Threat Catalog

The agent's working index. Walk every row. For each threat, search the code; if present, raise a finding at the indicated severity band and (for Critical/High) emit a Verification Request. The **Detailed checklist** column is the single source of truth for the item-by-item criteria — read it there; it is not duplicated here.

Reference shorthand:
- `SR` = `compact-core:compact-review` → `references/security-review.md`
- `TR` = `compact-core:compact-review` → `references/token-security-review.md`
- `PR` = `compact-core:compact-review` → `references/privacy-review.md`
- `WTB` = this skill → `references/witness-trust-boundary.md`

| # | Threat | Severity band | Trust boundary | Detailed checklist | PoC-confirmable? |
|---|--------|---------------|----------------|--------------------|------------------|
| 1 | `ownPublicKey()` used for authorization / identity gating | Critical | witness → auth | WTB; SR (Access Control) | Yes — forged `coinPublicKey` passes the gate |
| 2 | Witness value trusted in an `assert`/state-gate without re-derivation | Critical/High | witness → auth | WTB | Yes |
| 3 | Exported state-modifying circuit with no authorization check | Critical | caller input | SR (Access Control) | Yes |
| 4 | Mint/burn/transfer without authority or ownership check | Critical | caller input | TR (Authorization) | Yes |
| 5 | Authority captured from a runtime value instead of pinned at deploy | High | caller input | WTB; SR (Access Control) | Yes |
| 6 | `transientHash` used for a nullifier (not reproducible across executions/upgrades) | High | crypto | SR (Crypto Correctness); TR (Double-Spend) | Yes |
| 7 | Hash/commit without domain separation | High | crypto | SR (Crypto Correctness) | Sometimes |
| 8 | Nullifier without secret key (pre-computable) | High | crypto | SR; TR | Yes |
| 9 | Commitment without nonce/salt (brute-forceable) | High | crypto | SR (Crypto Correctness) | Sometimes |
| 10 | Randomness/salt reused across commitments (linkability) | High | privacy | PR; SR | Sometimes |
| 11 | Merkle path not checked against on-chain root (`checkRoot`) | Critical | crypto | SR (Merkle Path) | Yes |
| 12 | Double-spend: nullifier not checked before spend | Critical | token | TR (Double-Spend) | Yes |
| 13 | Subtraction underflow / missing balance check | High | arithmetic | TR (Overflow/Underflow); SR (Error Handling) | Yes |
| 14 | Missing `receiveShielded` in receiving contract (token loss) | Critical | token | TR (Shielded) | Yes |
| 15 | `unshieldedBalance()` in conditional logic (construction-time lock) | Medium | token | TR (Unshielded) | Sometimes |
| 16 | `disclose()` placed too early / too broadly | High | privacy | PR; SR | No (review judgment) |
| 17 | Assert message leaks private state | High | privacy | SR (Error Handling) | No (review judgment) |
| 18 | Sealed field write attempted outside constructor | Medium | compile | SR; this skill (Security Model) | Yes (compile error) |
| 19 | Exported-circuit parameters unvalidated | High | caller input | SR (Input Validation) | Sometimes |
| 20 | State-machine phase guard missing | High | protocol | SR (Access Control) | Yes |

Severity bands are defaults — adjust to the contract's actual impact (e.g. an unauthenticated mint on a live token is Critical; on an internal test scaffold, lower).
