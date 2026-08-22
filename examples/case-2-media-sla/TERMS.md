# Terms — Paid Media Retainer, five periods

**Fee.** One fee per accepted daily report, as recorded in the on-chain
`TenderTerms`. Flat across all five periods. Media spend is the agency's own cost of
sale and is reported, not reimbursed separately.

**Cadence.** One settlement per period, five periods total. The contract enforces
both bounds. A report may be delivered whenever it is ready — delivery is not paced —
but no period can pay twice, and this holds on every settlement path, including the
review deadline below.

**Escrow.** The whole campaign budget is escrowed before the campaign starts and is
visible on this token's vault address. A delivered report reserves its fee: once a
report is on the books, that fee cannot be refunded, cancelled away, or paid to
anyone else while the report is undecided.

**Review.** Reports are judged by a person — the brand's marketing lead holds the
acceptance authority. Acceptance pays. Rejection pays nothing and is final for that
report, but does not bar the agency from delivering the next period.

**Review deadline.** Every report starts a clock, `judgmentWindow`, fixed at mint and
public before the campaign began. A report neither accepted nor rejected before the
clock expires may be claimed by the agency itself, permissionlessly. The deadline
survives cancellation and the expiry of any other term: it is the one obligation the
brand cannot walk away from. It is paced like any other settlement — a queued claim
moves to the next period rather than being lost.

**Stopping early.** The brand may cancel at any time. Cancellation stops new reports
immediately. It does not void reports already delivered, and no refund may be taken
while any report is still undecided. Unworked periods are refunded pro rata to the
funders; anything gifted to the vault by a third party accrues to the token holder.

**Confidentiality.** None. The report schema and the review checklist are public;
the reports themselves are exchanged off-chain and committed only by hash.
