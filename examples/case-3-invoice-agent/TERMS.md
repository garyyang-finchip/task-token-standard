# Terms — Carrier Invoice Extraction Agent

**Award.** Exclusive. `maxCompletions` is 1: one supplier, one accepted delivery,
one owner of the artifact. This is a build, not a batch.

**Fee.** A single fee on acceptance, as recorded in the on-chain `TenderTerms`,
escrowed in full before work begins and visible on the token's vault address.

**Delivery deadline (`submitBy`).** No delivery is accepted after it. The buyer's
platform migration window is fixed; an agent that misses it cannot be deployed this
cycle.

**Decision deadline (`settleBy`).** After it, no settlement path driven by the buyer
remains open and unspent budget may be reclaimed. The standard requires
`settleBy >= submitBy`: a tender that closed for judgment before it closed for
delivery would be a contradiction.

**Review deadline (`judgmentWindow`).** Independent of the two above, and the one
obligation the buyer cannot escape. A delivery neither accepted nor rejected within
the window may be claimed by the supplier. This survives cancellation and survives
`settleBy`: a delivery made in good time is not extinguished by the buyer running out
the clock.

**Rejection.** Explicit, attributable, terminal for that delivery, and free of
charge — it moves no money and releases the reserved fee. It does not bar the
supplier from delivering a revised package against the same frozen terms.

**Reservation.** A delivery reserves the award slot and the fee. While a delivery is
undecided the buyer cannot cancel it away, cannot reclaim the escrow, and cannot
award the slot to anyone else.

**Ownership.** On acceptance the delivered package and its contents transfer to the
buyer, including the right to run, modify, and transfer it. The supplier retains no
call-home, no licence key, and no dependency the buyer cannot replace. `resultHash`
pins exactly which bytes were bought.

**Development data.** The 300-invoice development set is provided at award under the
confidentiality terms of the engagement and must be destroyed on completion. The
held-out set is never disclosed.

**Confidentiality of this package.** None. The task, the interface, the bar, and this
document are public, and the primary document is published on-chain.
