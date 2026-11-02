# Version-locked submission and settlement — v2 prototype

Contributor: Ted (@haot3x).

The six existing cases now exercise a real `ITaskAdmission` policy at the kernel submission boundary. The policy stores a publisher-selected test award and its `(version, taskHash)` anchor; auction finalization is not implemented by this fixture. `HashlockVerifier` remains the independent proof check at settlement.

- V1 delivery still settles after a V2 update, with the original fulfiller and version.
- A new V2 or V3 delivery cannot reuse the V1 award, even when V3 restores the same root bytes.
- Refused deliveries create no submission, pending reservation or reward lock.
- A non-winner is refused before admission.
- Admitted V1 work still requires the correct inner proof after an update.

`AdmissionSlot.t.sol` covers the empty slot, exact parameters, false/revert/malformed results, static-call writes, gas exhaustion, mint-time declarations, pacing, expiry cleanup and the immutable slot. The prior v1 verifier-only regression is preserved in Git history; this branch intentionally changes its expectations to admission-time refusal.

See [prototype results](../docs/v2-admission-prototype.md) for the pinned toolchain, measured code size, limitations and reproduction command.
