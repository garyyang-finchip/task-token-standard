# Shared Evaluation Benchmark for Chinese Financial Text Extraction

**Demanded by:** three firms that all need it and none of which will fund it alone
**Judged by:** a review committee none of them controls
**Delivered by:** a cross-institution team that cannot share a wallet

## The commercial situation

Three organisations — a brokerage research desk, a financial data vendor, and an AI
platform company — are each building models that extract structured facts from
Chinese annual reports and analyst notes. Each has built its own test set. None of
the scores are comparable. When any of them tells a client "our extraction is 94%
accurate", the client has no way to check what that number means, and neither do the
other two.

What is missing is an agreed benchmark: a public evaluation set with a published
labelling standard and a reference scorer, so that a number means the same thing to
everyone who quotes it.

Nobody wants to pay for it alone, and nobody wants to hand a competitor a free ride.
Worse, a benchmark is only worth having if it is **neutral**: the moment one of the
three controls what counts as a passing deliverable, the other two stop citing it.

So this tender separates the three roles that a single-buyer arrangement usually
collapses into one.

## Who pays: several parties, one visible vault

One firm posts the tender. The others fund the **same token's vault** directly.
Contributions are attributed on-chain, so the perennial consortium argument — has
everyone actually paid? — is answered by looking at an address rather than by
circulating a spreadsheet.

The vault also accepts unattributed gifts. We expect at least one: an institution
that benefits from the benchmark and would rather not be named as a sponsor. The
rules for that money are fixed in advance and are not negotiable afterwards: **gifts
are spent on rewards before attributed contributions**, which maximises what named
funders can recover if the work is never done, and any **unspent gift residue goes to
whoever holds the tender token**, not back to the funders who did not give it.

## Who judges: a committee none of the funders controls

Acceptance authority is held by a **K-of-N review committee contract**, not by any
funder. Below quorum, nothing moves. No single institution — including the one that
posted the tender — can release the money, and none can unilaterally block it either.

This is the point of the whole arrangement. A benchmark blessed by one vendor is
marketing; a benchmark blessed by a committee that vendor cannot outvote is
infrastructure.

## Who works: a team, paid as a team

Building this needs three different people: a linguist to write the labelling
standard, a domain specialist to define what each field means in a financial filing,
and an engineer to build the pipeline and the reference scorer. They work at three
different employers and will not be sharing a wallet.

The fulfiller of record is therefore a **split contract**. The reward is paid to it,
and each member withdraws their agreed share. The kernel needs no special support
for this: the fulfiller is an address, and an address may be a contract.

## What one completion is

One benchmark release per `spec/benchmark-release.yaml`: the labelled evaluation set,
the labelling standard it was produced under, the reference scorer, and a baseline
scored with it. Two releases are funded — an initial release and a follow-up
covering the second document class.

## A configuration warning, stated because it is easy to get wrong

The committee contract has its own timeout: if quorum is not reached inside its
voting window, the delivery is **rejected** by default. The kernel has a timeout too:
if a delivery is neither accepted nor rejected within `judgmentWindow`, it is **paid**
by default.

These defaults point in opposite directions, and the earlier one wins. A deployment
must therefore set the committee's voting window **strictly shorter** than
`judgmentWindow`. Configured the other way round, a fulfiller could take the money
while the committee was still voting, and the committee would be decorative. This
tender is configured correctly and demonstrates the ordering.
