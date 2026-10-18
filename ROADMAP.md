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
- Refinement (credit: @shentonyan, t/29597#30): the locked version is the one
  the tender *opened* against, not the one current at award time — bids were
  priced against that document, so an update between opening and award means
  the award would cover work nobody priced; the award inherits the tender's
  lock. The lock binds `taskHash` (the TaskRoot, which covers the specification
  and the eligibility profile), not `tdHash` (the document alone), and it is
  read from `taskOf(tokenId)` at opening, so the pair (version, taskHash) is
  established on-chain at that block and versions are append-only thereafter.
- Regression case (credit: @ted0x, t/29597#31): work is submitted at V1, the
  task is updated to V2, then the V1 submission is settled. The adapter checks
  only `submissionOf(...).taskVersion == lockedVersion` against its own anchor;
  the current binding is not consulted, so the update does not invalidate work
  already delivered. This follows the draft: the fulfiller cites the version it
  fulfilled, and a verifier that must bind to the exact bytes answered carries
  those anchors in its own commitment at configuration time (Security
  Considerations, "A verifier sees the cited version"). The single check also
  covers the other order — a submission made after the update cites V2 and
  fails — so no current-state check is needed. Candidate 5 is for authorities
  that hold no anchor of their own and read the binding at verification time
  (PR #2's signed authority).

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

### 5. Binding history view

The kernel keeps only the current binding: `taskOf(tokenId)` returns today's
`tdHash`, `taskHash` and `version`, and nothing returns the binding at an
earlier version. Every submission cites the version it was made against, so a
judge can know *which* version a delivery answered but cannot verify *what*
that version was once the task has moved. PR #2's signed verdict authority hit
this first (`TaskChanged`: no verdict can rule on a submission after an update,
because the digest binds `tdHash` and the earlier value is gone), and the
award-gated verifiers in t/29597#30 hit it the same way.

- Candidate: a view `bindingAt(tokenId, version)` returning the historical
  `(tdHash, taskHash)`, written by `_applyUpdate` alongside the version bump.
- Why not now: it adds a storage write per update and a new view to
  `ITaskToken`, which changes the interface identifier. It is cheap and does
  not touch settlement, so it is a strong v2 candidate, but it is a kernel
  change and belongs with the others.
- Today: an authority that holds no anchor of its own rules only while
  `taskOf(tokenId).version` equals the version the submission cites; after an
  update, "the task moved" and "the ruling lapsed" are the same event, and the
  judged path's deadline default (or, on the machine path, `releaseExpired`)
  resolves the submission. An authority that locked (version, taskHash) at
  configuration time needs no history: it settles against its own anchor
  (candidate 3's regression case).

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
