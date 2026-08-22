# Carrier Invoice Extraction Agent — Build to Specification

**Buyer:** a third-party logistics operator, 40+ carriers, ~9,000 invoices a month
**Seller:** whoever can build it — the method is not specified here
**Category:** tender — the buyer states the outcome and cannot state the method
**Settlement:** judged, exclusive, with a delivery deadline and a decision deadline

## The commercial situation

Our accounts payable team keys carrier invoices by hand. Forty-odd carriers, each
with its own layout, several of them changing format whenever their billing system
is upgraded: PDFs, scans, spreadsheet attachments. Six people spend their month on
data entry instead of on disputes, and the disputes are where the money is —
duplicate billings, fuel surcharges outside contract, reweighs applied against the
wrong consignment. We know we are leaking. We cannot currently prove how much.

We have evaluated three OCR vendors. All three plateau in the low nineties, and the
failures are not character recognition — they are semantic. Deciding that a line
reads as *fuel surcharge* rather than *customs disbursement* against **our** chart of
accounts is the part nobody has solved for us.

So we are not buying OCR. **We are buying a working agent, built against our data, to
our accuracy bar, delivered as an artifact we own and can run ourselves.**

We do not know how to build it. That is the point of this tender: we state the
outcome, the interface, and the bar; the supplier designs the approach and carries
the implementation risk.

## What is demanded

One agent, delivered as a versioned, hash-committed package, that implements the
interface in `spec/agent-interface.yaml` and clears the bar in
`acceptance/evaluation-protocol.md`:

- **≥ 98.0%** field-level accuracy across the scored fields, on our held-out set
- **≥ 99.5%** on `invoice_total` specifically — a wrong total is worse than no answer
- deterministic given the same input bytes and configuration
- runnable by us, on our infrastructure, with no call-home dependency

The held-out set is 500 invoices we have labeled ourselves and never published. It
spans all 40 carriers, three currencies, and includes the reweigh and split-shipment
cases that broke the vendors we tried.

## Exclusive, and why

This is one build, awarded to one supplier. Paying three teams to integrate the same
40 carriers three times is waste, not redundancy — and the artifact has to have one
owner who is answerable for it. `maxCompletions` is 1.

## The two deadlines

**Delivery closes at `submitBy`.** Our platform migration window is fixed; an agent
delivered after it cannot be put into production this cycle, and the project stops
being worth buying.

**A decision is owed by `settleBy`.** We commit to evaluating and answering by then.
After that date the escrow unlocks and unspent budget returns. This is a discipline
we impose on ourselves, and it is the reason a supplier can justify starting work:
the budget is neither imaginary nor hostage.

## Rejection is expected, not exceptional

Custom builds do not land first time. A delivery that misses the bar will be
rejected explicitly, with the measured numbers, on-chain. Rejection is final for
that delivery and moves no money — and it releases the reserved fee back to the
tender, so the same supplier may deliver again against the same terms. We would
rather see three iterations that converge than one delivery nobody dares to judge.

## What we are giving up by holding the judgment

We hold the acceptance authority: our engineering lead scores the delivery against
the held-out set. That is unavoidable — only we have the labels.

What we give up in exchange is the ability to stay quiet. Every delivery starts a
clock. If we neither accept nor reject before it expires, the supplier takes the fee
itself. We also cannot cancel our way out of a delivery already received: the fee
stays reserved until we rule on it. If we think a delivery is inadequate, we have to
say so, in public, with our name on it, inside a window we published before any work
began.

## The deliverable is an asset, not a report

What changes hands is a package: the agent, its configuration, its evaluation
harness, committed by hash. `resultHash` is that package's deterministic digest, so
what we accepted is provable afterwards, byte for byte. On acceptance we hold a
runnable, versioned artifact — a supply-side asset in its own right, which we may
run, re-run, extend, or transfer.

The demand for the work retires as the artifact arrives. That is the whole trade.
