# Acceptance — what a competent opinion must contain

The engagement scope is confidential. This standard is not: what makes a tax opinion
usable is a matter of professional practice, and publishing it lets any adviser check
their own delivery before submitting it.

Screening is in two stages. `acceptance/opinion_check.py` is deterministic, public,
and runnable by either side; a delivery that fails it is rejected without further
review. Passing it is necessary and not sufficient — the substance is then read by
the buyer's CFO.

## Structural requirements (machine-checked)

| # | Requirement |
| --- | --- |
| 1 | Sections present: Executive Summary, Facts and Assumptions, Questions Presented, Analysis, Conclusions, Limitations and Reliance, Signature |
| 2 | Every question in the engagement scope has its own `### Analysis — Qn` section |
| 3 | Every question has an express `**Conclusion (Qn):**` line stating a position |
| 4 | Each analysis section carries at least 250 words of substantive reasoning |
| 5 | At least 8 citations to named authorities (treaty articles, statutes, circulars, guideline chapters) |
| 6 | No placeholder text: TBD, TODO, XXX, lorem, or empty bracket stubs |
| 7 | A signature block naming the signing adviser, their qualification, and a date |
| 8 | Where the scope key is supplied, every question id in the scope appears in the opinion |

## Substantive requirements (read by the buyer)

- Conclusions are **expressed at a stated confidence level** — "more likely than not",
  "should", "will" — and the level is justified, not asserted.
- Adverse authority is addressed, not omitted. An opinion that cites only helpful
  material is not usable against a challenge.
- The facts relied on are stated as assumptions the client can confirm or correct,
  and the opinion states that it fails if those facts differ.
- Recommendations are actionable: what to document, by when, and who holds it.

## Rejection

A delivery failing any structural requirement, or found on reading to be
substantively deficient, is rejected with `rejectFulfillment` and the reason stated.
Rejection is terminal for that delivery, moves no money, and releases the reserved
fee for a revised delivery from the same adviser.

## Deliverable form

The opinion is delivered as a package: the opinion document, a manifest, and a
declaration of the scope version answered. `resultHash` is that package's
deterministic digest, so the exact bytes accepted are provable afterwards — which
matters for a document that may be produced to an authority alongside the engagement
record.
