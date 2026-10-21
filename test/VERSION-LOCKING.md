# Settlement against a locked submission version

Contributor: Ted (@haot3x).

[`VersionLockedSettlement.t.sol`](VersionLockedSettlement.t.sol) makes the regression discussed in [post 31](https://ethereum-magicians.org/t/erc-8414-token-bound-task-tenders/29597/31) and clarified in [post 33](https://ethereum-magicians.org/t/erc-8414-token-bound-task-tenders/29597/33) executable against the current kernel. It tests the machine-settlement pattern available today, not the proposed submission-time admission slot in ROADMAP candidate 3.

The verifier stores `(version, taskHash)` from `taskOf(tokenId)` when configured, modelling the tender-opening anchor. At settlement it compares the submission's recorded `taskVersion` with its locked version. It does not compare against the task's current binding: an update can stop future deliveries from using the old award without invalidating work already delivered under that award.

The six cases cover:

| Sequence | Expected result |
| --- | --- |
| Submit V1, update to V2, settle V1 | Recorded winner receives the reward once; current binding stays V2. |
| Update to V2, then submit | Submission records V2 and cannot use the V1 award; failed verification leaves its reservation and funds unchanged. |
| V1 and V2 submissions coexist | V1 settles; V2 remains Pending and cannot receive that award. |
| Update to V2, then reuse the V1 root at V3 | V3 remains a different version and cannot reactivate the V1 award; the original V1 delivery still settles. |
| A non-winner delivers V1 | Historical version matching does not bypass eligibility. |
| A winner supplies the wrong inner proof for V1 | It stays Pending; a later valid proof can settle it. |

The V2 update deliberately keeps `tdHash` unchanged and changes `taskHash`: a companion or acceptance-profile change can alter the TaskRoot without editing the primary document. Returning to the old root bytes does not restore an earlier append-only version.

## Run

From the repository root, install the normal Foundry test dependency if needed, then run:

```sh
forge install foundry-rs/forge-std --no-git
forge test --match-contract VersionLockedSettlementTest -vv
forge test
```

The tests use the real `TaskToken`, its per-token `TaskVault`, and the stock `HashlockVerifier`. A test-only gate fixes one winner to isolate the version check. It does not implement commit/reveal bidding, award finalization, production authorization, a new kernel interface, or the sealed-bid companion's full integration. A V2 submission is still accepted by the current permissionless submission API and reserves a slot; refusal here is at verification, not admission. An ineligible machine-path submission remains subject to the existing `releaseExpired` policy.

This is a regression example, not a report of a kernel vulnerability. No production contract or normative rule changes with it.
