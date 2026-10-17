# Roadmap — candidates beyond the current draft

The current draft (TASK-KERNEL v3.0 + the two amendments adopted from first-round
Ethereum Magicians review) is feature-frozen for the ERC PR. Items below are
recorded here so they are decided deliberately in a future revision or companion,
not smuggled into the kernel. Nothing here blocks Draft status.

## v2 revision candidates (change the interface identifier)

### 1. `judgmentFee` — the price of one recomputable ruling

A tender term set by the publisher at mint and paid from the vault to
`acceptanceAuthority` **on acceptance only**: metered per verdict, default zero.

- Reframed during first-round review (credit: @babyblueviper1): not a governance
  knob for paying judges, but literally the price of one recomputable ruling —
  which puts a tender's *full* price, reward plus judgment, in one vault that
  travels with the token when it trades. The reverse-asset thesis applied to
  judgment itself.
- Why not now: it changes the `ITaskTender` identifier, and it must never pay per
  rejection (a rejection-paid fee lets junk submissions plus a complicit judge
  drain the vault one ruling at a time — see Security Considerations).
- Prototype path without kernel change: the slot holds a fee-holding attestation
  or panel contract, the same way the fulfiller of record can be a splitter. The
  companion below can prove the economics before the kernel adopts the field.

### 2. On-chain verifier-kind discovery

Two verifiers can both declare `ITaskVerifier` and both set `machineSettled`
while being different kinds of judge — a deterministic recomputation anyone can
reproduce from the committed criteria, versus an attestation of a nondeterministic
or off-chain process. A buyer of a traded tender inherits very different judgment
risk from each, and `acceptanceAuthorityOf` alone cannot tell them apart.

- Today: the committed acceptance profile SHOULD state the verifier kind and
  whether rulings can be independently recomputed (off-chain, but inside
  `taskHash`, so a buyer who verifies the package before purchase learns it).
- Future: an on-chain discovery surface (e.g. a `verifierKindOf()` /
  ERC-165-discoverable classification interface) belongs with the judgment
  attestation companion, where "what kind of ruling is this" is the native
  question rather than an afterthought bolted onto the kernel.

### 3. Submission-time admission slot

`submitFulfillment` is permissionless and records `msg.sender` as the fulfiller
of record, so no companion can gate it: a wrapper becomes the fulfiller, and
direct calls bypass it. On the judged path, eligibility is enforced only by
rejection inside `judgmentWindow`, and the deadline default pays whatever was
not rejected (credit: @JCXsivan, t/29597#25).

- Candidate: an optional, ERC-165-discoverable admission policy consulted inside
  `submitFulfillment` (and snapshotted on the submission, like `machineSettled`),
  so that an ineligible submission is refused before it reserves a slot.
- Why not now: it is a new slot and a new MUST in the kernel, changes the
  `ITaskTender` identifier, and re-opens the observability boundary (the kernel
  enforces what is observable; a policy contract is observable, which is the
  argument for it). Decide deliberately in v2.
- Today: eligibility that must hold without a live judge belongs on the machine
  path (a verifier that refuses ineligible proofs; `releaseExpired` recycles the
  slot). The draft now says so in Submission and Security Considerations.
- Motivation note (credit: @shentonyan, t/29597#27): admission checked at
  submission rather than at verification means losing bidders cannot submit at
  all, which saves them gas and keeps refused slots out of the pacing budget.
- Test case (credit: @ted0x, t/29597#28): an award is granted at task version N
  and the specification is updated to N+1 before submission. The kernel stamps
  every submission with the binding version current at submission, so the
  bidder's submission cites N+1. Under version-locking — the normative answer
  for award profiles — admission refuses it: by updating, the publisher has
  withdrawn the award and must re-award. A profile MAY offer freeze-at-award as
  a stricter option, but freezing is an irreversible write by the update
  authority and SHOULD NOT be a bidding flow's default.

### 4. Partial reclaim while submissions are pending

`reclaimEscrow` and `reclaimResidual` revert while `pendingOf > 0`, so one
Pending submission locks the whole vault for up to `judgmentWindow`, which has
no upper bound (credit: @JCXsivan, t/29597#25).

- Candidate: let funders reclaim the unreserved part of the vault
  (`escrowBalanceOf − lockedEscrowOf`) while submissions are pending, and/or a
  recommended cap on `judgmentWindow`.
- Why not now: the refund rule fixes the distributable pool and the denominator
  at the first reclaim so that payout is order-independent, and a funder's
  outstanding contribution is zeroed on reclaim. Reservations freed *after* a
  partial reclaim (by rejection) would then have no funder left to return to and
  would fall to the owner's residual. A running-ratio pull design can fix this
  but it is a different refund arithmetic, not a patch.
- Today: the draft states the lockup bound exactly (one window after the tender
  closes, clearable by anyone since the claim is permissionless) and asks
  wallets to display `judgmentWindow` as the lockup a contribution accepts.

## Companion track (no kernel change; separate drafts)

### Judgment-execution attestation companion (proposed by @babyblueviper1)

For judged tenders (N ≥ 1), the contract today records only the judge's say-so;
it cannot distinguish "the judge looked and it's fine" from a rubber stamp. The
companion occupies the acceptance-authority slot and, given
`(taskHash, version, resultHash)` plus the task's committed acceptance criteria,
issues a signed verdict *with a recomputable proof hash* — and only that hash,
not the say-so, triggers `acceptFulfillment` / `rejectFulfillment`. Kernel-side
composition points already exist by design: the companion is simply an acceptance
authority; each `Submission` records the cited `taskVersion`; its internal
decision window must run strictly shorter than `judgmentWindow` (see Security
Considerations on composing external judging timeouts). Sketches against the real
interface IDs are welcome as issues or PRs to this repository; if it firms up it
deserves its own draft.

### Other standing candidates

- ERC-1155 fulfillment shares: team splits, bid allocations, subcontract shares
  referencing `TaskRef = (chainId, taskContract, taskTokenId)`.
- Atomic reveal-on-payment delivery profiles for judged tenders.
- Streaming (per-second) settlement for faucet task tokens.
- Submission bonds and allowlists for hostile-submitter deployments, enforced at
  the acceptance decision or by a machine-path verifier (a submission-time slot
  is v2 candidate 3 above: no companion can gate `submitFulfillment`).
