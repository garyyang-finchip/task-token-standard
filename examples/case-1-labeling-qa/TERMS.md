# Terms — Support-Ticket Intent Labeling, batches 0417-0419

**Price.** One reward per accepted batch of 500 labeled tickets, as recorded in the
on-chain `TenderTerms`. All three batches pay the same amount; there is no bidding,
no bonus, and no penalty schedule.

**Quantity.** Three batches, one per assigned annotator. The tender closes when the
third settles. Under TASK-KERNEL v3.0 a delivery reserves its slot and its reward at
submission time, so an annotator who has delivered cannot be crowded out.

**Assignment.** Batches are assigned before this tender is frozen; the settlement
commitment is a Merkle root over `sha256(receipt ‖ assigned_annotator)`. Submitting
from an address that was not assigned a batch cannot settle, however correct the work.

**Acceptance.** Mechanical and final. The judgment slot holds a verifier contract, so
no person can accept, reject, delay, or reverse a valid claim — including us. See
`acceptance/gold-standard-qa.md` for the bar and how it is measured.

**Settlement age.** A submission must stand for the tender's minimum age before it
may settle. This protects the annotator who reveals first from being front-run.

**Escrow.** The full bounty for all three batches is escrowed before work begins and
is visible on the token's vault address. It cannot be reclaimed while any delivery is
outstanding; a delivery left unsettled is not a delivery we may walk away from.

**Data.** Ticket contents are customer data. They are not published, not committed to
this package, and never leave our systems. Annotators work in our tool on their
assigned batch only, under the confidentiality terms of their engagement.

**Version.** This package is frozen. The taxonomy, the pass bar, and the receipt
mechanics cannot change once work has started; any change requires a new tender.
