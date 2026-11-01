# v2 candidate 3 — Submission-time admission slot (draft for discussion)

Status: design draft for the v2 revision of the task kernel. It is **not** part of
ERC-8414 as filed in ethereum/ERCs#2005; nothing in the current kernel, its interface
identifiers, the reference implementation or the Sepolia deployment changes with this
document. It exists so that the companions waiting on candidate 3 have an interface to
adapt against, and so that the thread can argue with a concrete shape rather than a
bullet point.

## 1. Problem (from the thread)

- `submitFulfillment` is permissionless and records `msg.sender` as the fulfiller of
  record, so nothing placed in front of it can gate it: a wrapper becomes the fulfiller,
  and direct calls bypass it (t/29597#25, @JCXsivan).
- On the judged path, eligibility holds only as far as the judge's availability: the
  deadline default pays whatever was not rejected inside `judgmentWindow`. On the machine
  path a verifier can refuse, but the refused submission still reserves a slot and a
  reward until `releaseExpired`, and still counts against the pacing budget
  (t/29597#27, @shentonyan).
- Award profiles need admission keyed on the task version the tender *opened* against,
  so that an update withdraws the award from future submissions without invalidating
  work already delivered (t/29597#28, #30, #31; @ted0x, @shentonyan).

The draft today answers all three in prose: eligibility that must hold without a live
judge belongs on the machine path, and a submission-time slot is a kernel change
recorded as a revision candidate. This document is that candidate.

## 2. Proposal

### 2.1 Interface

```solidity
/// Consulted by the task contract inside submitFulfillment, before a slot is reserved.
interface ITaskAdmission {
    /// @notice Return true to admit the submission. MUST be a view: the kernel calls it
    ///         with STATICCALL, so a policy cannot write state or reenter. Reverting is
    ///         equivalent to returning false.
    /// @param taskContract The calling task contract (so one policy can serve many).
    /// @param tokenId      The task token being submitted against.
    /// @param submitter    msg.sender of submitFulfillment — the would-be fulfiller of record.
    /// @param resultHash   The deliverable commitment being submitted.
    /// @param taskVersion  The binding version the submission will cite (the current one).
    function admit(
        address taskContract,
        uint256 tokenId,
        address submitter,
        bytes32 resultHash,
        uint64 taskVersion
    ) external view returns (bool);
}
```

`ITaskAdmission` gets its own ERC-165 identifier. A policy that needs more than these
five values — the current `taskHash`, the tender terms, a bond it holds, an award it
recorded, an ERC-8004 registry entry — reads it itself; everything it could need is
either on the task contract or in its own storage.

### 2.2 Slot

- `admissionAuthorityOf(tokenId) → address` is added to `ITaskTender`. `address(0)`
  means open submission — exactly today's behaviour.
- The slot is **set at mint and immutable**, through a new `mintTask` parameter, not
  through `TenderTerms`. Reasoning: `TenderTerms` are the numbers a fulfiller prices
  work against; the admission authority is an address with code. Both are terms of the
  tender in the economic sense — "who may reserve a slot" is something a fulfiller
  reads before deciding to work, like `rewardPerCompletion` — so both are fixed at mint.
  It is deliberately *not* modelled on `acceptanceAuthority`, which is transferable
  because judgment is an adversarial post-delivery power a buyer must be able to inspect
  and price; admission is a pre-submission term, and a transferable one would need a
  per-submission snapshot (as `machineSettled` does) to stop a publisher changing the
  rules on work in flight. Immutability removes that machinery entirely.
- At mint, a non-zero authority MUST declare `ITaskAdmission` via ERC-165, checked the
  same way `_declaresVerifier` probes the judgment slot. A genesis event
  (`AdmissionAuthoritySet(tokenId, authority)`) completes the event-stream history, as
  the two existing authority events do.

### 2.3 Kernel change

In `submitFulfillment`, after the existing cancellation and deadline checks and before
the slot and reward are reserved:

```solidity
address adm = _admissionAuthority[tokenId];
if (adm != address(0)) {
    require(_admits(adm, tokenId, msg.sender, resultHash, _binding[tokenId].version),
            "TaskToken: not admitted");
}
```

where `_admits` is a `try/catch` around `ITaskAdmission(adm).admit(...)` that treats a
revert, a malformed return or a `false` as refusal. A refused submission reserves
nothing, records nothing and emits nothing: the transaction reverts. No snapshot is
needed, because the slot cannot change after mint and an admitted submission is already
a record.

Everything after admission is unchanged: reservation, the judged and machine paths, the
judgment deadline and its default, `releaseExpired`, epoch pacing, cancellation and
refund.

### 2.4 What does not change

- The vault lock and the deadline default. Admission narrows *who may reserve a slot*;
  it never touches what happens to a slot once reserved. "Silence pays the fulfiller"
  is as true for an admitted submission as it is today.
- Tenders that leave the slot empty behave exactly as v1 tokens: eligibility is
  enforced at the acceptance decision (judged path) or in the verifier (machine path),
  with the limits the Security Considerations already state.
- The fulfiller of record is still `msg.sender` of `submitFulfillment`. Admission does
  not introduce submission on behalf of another address.

## 3. Identifiers and compatibility

- `ITaskAdmission`: new interface, new ERC-165 identifier.
- `ITaskTender`: gains `admissionAuthorityOf`, so its identifier changes. This is the
  reason candidate 3 is a v2 item and not an amendment to the filed draft.
- `ITaskToken`, `ITaskVerifier`, `IOnchainTaskDocument`: unchanged.
- v1 tokens have no slot and are unaffected. A v2 contract with every slot left at
  `address(0)` is behaviourally identical to v1 for submitters, judges and funders.

## 4. Engineering constraint: EIP-170 — measured

The current reference kernel compiles (solc 0.8.24, optimizer on, `optimizer_runs = 1`)
to a **23,766-byte** runtime, **810 bytes** under the 24,576-byte limit. A slot, an
ERC-165 probe at mint, a `try/catch` admission call and a genesis event will not fit in
810 bytes with any confidence.

Measured on the current `main` (b3da62e), same compiler and settings, adding only
`--via-ir`:

| Build | `TaskToken` runtime | EIP-170 headroom | Test suite |
| --- | --- | --- | --- |
| default (today) | 23,766 bytes | 810 bytes | 94 / 94 |
| `--via-ir` | 19,550 bytes | 5,026 bytes | 94 / 94 |

So the slot fits with room to spare if the v2 reference build switches to the IR
pipeline; no module split or revert-string surgery is required for that alone. Two
further levers exist if v2 needs more: converting the 55 distinct `require` strings to
custom errors (several kilobytes, but it changes revert data and every `expectRevert`
in the suite), and moving `IOnchainTaskDocument` into an optional module. The
recommendation is via-IR for the v2 reference implementation, measured again on the
prototype branch before any v2 text is written. (The v1 Sepolia deployment is not
rebuilt; v2 is a new deployment either way.)

## 5. Reference admission policies (companions, not kernel)

- **Award-gated.** The policy locked `(version, taskHash)` from `taskOf(tokenId)` when
  the tender opened and recorded the award winner. `admit` returns true iff
  `submitter == winner` and `taskVersion == lockedVersion`. An update after the award
  changes the version the kernel stamps on new submissions, so new submissions are
  refused; a submission admitted before the update settles against its cited version
  (the regression case in `test/VersionLockedSettlement.t.sol`). The sealed-bid award
  companion (shentonyan/sealed-bid-award-erc) is the first consumer.
- **Allowlisted / bonded.** `admit` returns true iff the submitter is listed, or has
  posted a bond the policy holds. Bond posting is a call on the policy made *before*
  `submitFulfillment`; the policy is stateful so that `admit` can stay a view.
- **ERC-8004 eligibility.** `admit` returns true iff the submitter's agent passes a
  validation requirement in the ERC-8004 Identity and Validation registries.

A policy may combine these. None of them needs a submitter-supplied proof at submission
time, which is why `admit` takes none (see §7).

## 6. Acceptance suite

- `test/VersionLockedSettlement.t.sol` (PR #5, @ted0x): both orderings of update versus
  submission, winner eligibility, inner-proof checks — re-run with the fixture gate
  replaced by a real `ITaskAdmission` policy installed in the slot.
- The sealed-bid award companion adapted to the slot (t/29597#27 offer).
- New cases: an empty slot behaves as v1; a refused submission reserves nothing, records
  nothing and emits nothing; an admitted submission later refused by the verifier still
  recycles through `releaseExpired`; the pacing budget is unaffected by refused
  admissions; a policy that reverts or returns malformed data is treated as refusal;
  mint with a non-zero authority that does not declare `ITaskAdmission` reverts.

## 7. Decided here, and open for the thread

Decided in this draft (argue with them if they are wrong):

1. The slot is immutable and set at mint (§2.2), not transferable with a snapshot.
2. `admit` receives no caller-supplied bytes. The three reference policies need none,
   and a proof parameter would require a second `submitFulfillment` signature. A policy
   that needs submitter-provided data can take it in a prior call on the policy itself.

Open:

3. Should a refused admission emit an event? A revert is cheapest and leaves no trace;
   an indexer-facing event would cost gas on every refusal and is only visible if the
   kernel catches the refusal rather than reverting.
4. Whether the kernel should bound the gas forwarded to `admit` (a slow policy delays
   every submission; the publisher chose the policy, so the cost is the publisher's, but
   the submitter pays the gas).
5. Where the v2 bytes come from if via-IR alone proves insufficient once the slot is
   actually written (§4).

## 8. Next step

A prototype branch (`v2/admission-slot`) that adds the interface, the slot and the
`submitFulfillment` check, swaps the fixture gate in `VersionLockedSettlement.t.sol` for
a real policy, and reports the measured runtime size under via-IR. Results go to the
thread before any v2 specification text is drafted. This document is the shape to
adapt against until then.

Credits: @JCXsivan (t/29597#25), @shentonyan (#27, #30), @ted0x (#28, #31, PR #5).
