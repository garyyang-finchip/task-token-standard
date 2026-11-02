# Submission-time admission prototype

Author: Ted (@haot3x). Date: 2026-11-02.

Implements the [v2 design draft](v2-admission-slot.md) from upstream `a2c2ea040f4729bb0499a709cf937d1ffa58345f`. This is a review branch, not a change to the filed ERC, its normative assets or an existing deployment.

The kernel stores an immutable admission authority at mint, emits its genesis event, exposes the new getter and checks the policy before any submission reservation. Zero preserves open submission. A policy receives the actual task contract, token, caller, result hash and current task version. It cannot mutate state through the kernel's static call. A revert, empty/oversized data or noncanonical boolean is refused. Subsequent settlement, expiry cleanup and refunds do not re-evaluate admission.

The existing seven-argument `mintTask` remains a convenience for a zero slot; the new overload takes the policy as its last argument. This is a prototype implementation choice, not an additional normative mint requirement. `ITaskTender` has a new interface identifier; the former identifier is not advertised. The new `ITaskAdmission` identifier is `0x1262f0b4`.

For the draft's open gas question this branch tries **100,000 gas per admission** and **30,000 for its mint-time interface declaration**. The low-level call copies only 32 return bytes, so a policy cannot cause an unbounded return-data copy. These budgets need feedback from real policies; they are not claimed as agreed protocol values. The policy address is immutable, but its code or external dependencies may still be upgradeable or its eligibility state mutable. The kernel does not prove policy immutability or fairness.

## Results

Foundry 1.7.1; Solidity 0.8.24, optimizer runs 1, **via-IR enabled**. Full suite: **106 tests pass** (94 existing/adapted plus 12 admission tests). The six version-lock cases now use the real admission slot with a fixed-award policy, retaining a real kernel, vault and HashlockVerifier. Award selection in that policy is still a fixture, not an ERC-8469 auction.

`TaskToken` runtime is **22,919 bytes**, leaving **1,657 bytes** below EIP-170. This measures the implemented prototype, including the compatibility mint overload, not just v1 compiled through a different pipeline. Removing the admission guard fails the refusal/reservation regression. The source is restored after that negative control.

Logs: [full suite](../evidence/v2-admission-check.txt), [sizes](../evidence/v2-admission-sizes.txt), [negative control](../evidence/v2-admission-negative-control.txt).

```sh
forge install foundry-rs/forge-std@bf647bd6046f2f7da30d0c2bf435e5c76a780c1b --no-git
forge test -vv
forge build --sizes --skip test
```

The validation entry point for this branch is Foundry. Historical solc-js/demo scripts, normative asset copies and deployment records describe v1 and are not a completed v2 release package. No deployment, audit, upstream merge or sealed-bid companion integration is claimed. Review should settle the call budget and mint surface before generating a revised filing package.
