# Paid Media Retainer — Daily Delivery, Daily Settlement

**Buyer:** a DTC consumer brand running a fixed-length performance campaign
**Seller:** the media agency buying and optimising the placements
**Category:** tender — the buyer states the outcome, not the method
**Settlement:** judged, one delivery per period, with a deadline on the judgment

## The commercial situation

Paid media is bought on trust and settled on paperwork. The agency fronts the media
spend, does the work, and then waits: net-30, net-60, sometimes net-90. Whole
agencies live or die on that gap. Meanwhile the buyer's own worry is the mirror
image — pay up front and you may get a burned budget, a spike of junk traffic, or a
campaign you cannot stop when the product goes out of stock.

Neither side is being unreasonable. The gap is structural: the money and the work
move on different clocks, and the party holding the money also decides when the work
was good enough.

This tender puts both clocks on-chain. The brand escrows **the entire campaign
budget up front**, where the agency can see it — no invoices, no receivables, no
credit risk. But the budget is not handed over: **one period's fee is released per
period**, against one delivered report, and only after the brand has had its say.

## What one completion is

One **daily campaign report** covering the placements run in that period, delivered
per `spec/daily-report-schema.yaml`: spend, impressions, clicks, conversions, CPA,
and creative-compliance evidence for every active asset.

The campaign runs **five periods**. Exactly **one** report may be settled per period,
so a week's fees cannot be drawn in an afternoon.

## What the buyer keeps, and what it gives up

**Keeps:** the right to say no. Reports are reviewed by a person — whether creative
sits inside platform policy, whether a conversion curve is plausible rather than
farmed, whether the brief was actually executed. None of that is machine-decidable,
so the judgment slot holds the brand's marketing lead, not a contract.

**Gives up:** the right to say nothing. Every report starts a clock. If the brand
neither accepts nor rejects it before the clock runs out, **the agency takes that
period's fee itself**. Rejecting stays available and costs nothing — but it must be
done out loud, on-chain, within the window the brand published before the campaign
started.

That single rule is what replaces net-60. The agency is no longer financing the
brand's approval workflow. A marketing lead on holiday, a departed signatory, a
finance queue — none of them are the agency's problem any more.

## Stopping early

Campaigns get pulled: budget cuts, stock-outs, a competitor incident. The brand may
stop the tender at any time, and no further reports will be accepted.

What it cannot do is stop the tender to avoid paying for a report it has already
received. A delivered report keeps its reserved fee until it is accepted, rejected,
or claimed on the deadline; only the periods that were never worked are refunded,
pro rata, to whoever funded them.

## Demonstration timings

The on-chain terms of this reference run compress a day into **120 seconds** and the
review window into **90 seconds**, so that a five-period campaign can be observed
end to end. In production these are `86400` and typically three to seven days. The
period boundary is real either way: settlement genuinely waits for the next period.
