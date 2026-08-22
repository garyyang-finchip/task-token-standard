# Acceptance — how a delivery is scored, and what the clock does

## The bar

A delivery is accepted if and only if, run by the buyer against the held-out set:

| Metric | Bar |
| --- | --- |
| Field-level accuracy across `scored_fields` | ≥ 98.0% |
| `invoice_total` accuracy | ≥ 99.5% |
| Determinism: two runs, identical bytes | identical output |
| Harness runs on buyer infrastructure | no supplier-controlled network call |

A wrong `invoice_total` is scored worse than a refusal: the agent may emit
`null` with a `needs_review` flag, and a refusal counts as neither correct nor
incorrect on that field. Guessing a total is the one behaviour we will not buy.

## The held-out set

500 invoices, labeled by our own AP team, never published, spanning all 40 carriers
and the hard cases listed in the spec. It is not disclosed before or after the
tender — disclosing it would destroy its value for the next build.

The supplier is given a **development set** of 300 different invoices at award, drawn
from the same population and labeled the same way. A delivery that scores well on the
development set and poorly on the held-out set has overfitted, which is a rejection,
not a dispute.

## What the reviewer does

1. Verify the delivered package hashes to the committed `resultHash`.
2. Run the packaged harness on our infrastructure against the held-out set.
3. Run it twice and diff the outputs, for determinism.
4. Compare against the bars above.
5. Accept, or reject with the measured numbers stated.

Steps 1–3 are mechanical and reproducible. Step 4 is arithmetic. Only the decision to
award partial credit for a near miss is discretionary, and this tender awards none:
the bar is the bar.

## Rejection

A delivery that misses any bar SHOULD be rejected with `rejectFulfillment`, citing
the measured figures. Rejection is terminal for that delivery, moves no money, and
releases the reserved fee so that the same supplier may deliver a revised package
against the same frozen terms. Iteration is the expected shape of this work.

## The clock, and what it costs the buyer

The reviewer has `judgmentWindow` from `submittedAt`. If the buyer neither accepts
nor rejects in that time, the supplier may call `claimUnjudged` and take the fee.

This is the supplier's only structural protection, and it is deliberately blunt.
Evaluation here is cheap for the buyer — the harness is packaged, the labels are in
hand, the run is automated. A buyer who cannot answer inside the window is not
struggling to evaluate; it is declining to. Under these terms that is a paid choice.

## What this protocol does not protect against

The buyer must receive the package in order to score it. Nothing in the kernel
prevents a buyer from rejecting a delivery and then using it anyway. What the kernel
does is make that act **explicit, attributable, and permanent**: a named rejection,
on-chain, against a `resultHash` that pins exactly which bytes were rejected. That is
the evidence a reputation or arbitration layer needs, and it is the layer where this
particular risk belongs. Suppliers who need more SHOULD negotiate staged disclosure —
committing the package hash, delivering the harness output first, and releasing full
bytes on payment — which this standard's `resultHash` commitment supports without
modification.
