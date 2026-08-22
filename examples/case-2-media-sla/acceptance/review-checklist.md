# Acceptance — what the reviewer checks, and what the clock does

Judgment here is human on purpose. Creative compliance and traffic plausibility are
not machine-decidable, and pretending otherwise would either pay for junk or refuse
good work. The kernel does not try; it enforces the arithmetic and puts a deadline on
the human.

## The checklist

1. **Completeness.** Every field in `spec/daily-report-schema.yaml` present for the
   period claimed; one screenshot per active creative; raw platform export attached.
2. **Reconciliation.** Reported spend, impressions, clicks and conversions match the
   attached export. Any discrepancy is a rejection, not a rounding discussion.
3. **Creative compliance.** Every active creative carries `policy_check: pass`, and
   the served screenshot matches the approved asset. A flagged or removed creative
   left running is a rejection.
4. **Plausibility.** Metrics that jump beyond the thresholds in the spec are treated
   as suspected invalid traffic until reconciled against the export.
5. **Brief adherence.** Placements sit inside the audiences and networks agreed at
   award.

A report failing any item SHOULD be rejected with `rejectFulfillment`, which is
terminal for that report, moves no money, and leaves a public record. It does not bar
the agency from delivering the next period.

## The clock

The reviewer has `judgmentWindow` seconds from `submittedAt`. After that the agency
may call `claimUnjudged` itself and take that period's fee.

This is not a loophole for bad work; it is the price of silence. A reviewer who
believes a report is inadequate has a cheap, explicit remedy available for the whole
window. Declining to use it, and declining to accept, is a choice — and under these
terms it is a choice that pays.

Two limits keep the deadline honest in both directions. It is **paced**: a queued
default claim waits for the next period rather than draining the budget in one go. And
it is **judged-path only**: it does not exist on machine-settled tenders, where code
has already ruled.

## Out of scope

Media buying strategy, audience construction, and creative production are the
agency's craft and are not specified here. The brand buys a compliant, reconciled,
plausible daily report; how the numbers were earned is the agency's business, subject
to the checklist above.
