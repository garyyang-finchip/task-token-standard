# Cross-Border Restructuring — Tax Opinion (Redacted Invitation)

**Buyer:** a Chinese manufacturing group, sales operations across Southeast Asia
**Seller:** an international tax practice or independent adviser
**Category:** tender — a signed professional opinion, not a research memo
**Settlement:** judged, exclusive, priced in a stable unit

## Why this invitation is redacted

The question we need answered is itself commercially sensitive. Naming the entities,
the jurisdictions, or the transaction volumes would disclose a restructuring we have
not announced — to competitors, to our current advisers, and to two tax authorities.
The parameters of the acceptance test leak the same information: which treaties must
be covered tells you exactly where we are going.

So this on-chain invitation is deliberately thin. It states what kind of work is
bought, how it is priced, what a competent deliverable looks like, and how a decision
will be made. **The engagement scope is committed in this package as an encrypted
object** and is released to shortlisted advisers under the engagement NDA. The chain
still anchors the hash of the *plaintext* scope, so nothing is hidden from
verification — only from the public.

## What is bought

One **signed tax opinion** addressing the questions set out in the engagement scope,
of a standard sufficient to be produced to a tax authority in support of a filing
position. Not a summary, not a slide deck, not a research memo: a document with
stated facts, questions presented, reasoned analysis, express conclusions, stated
limitations, and a signature.

The acceptance standard and the automated conformance check that screens deliveries
are **public**, in `acceptance/`. What is competent professional work is not a
secret. Where we are restructuring is.

## Pricing

Priced and settled in a stable unit of account rather than in ether. A professional
fee agreed at award must not become a different fee because the settlement asset
moved twenty percent while the work was being done. That risk has nothing to do with
the engagement and neither party is paid to bear it.

## Scope changes before, and only before, work starts

We expect shortlisted advisers to come back with clarifying questions. Where those
questions change what we are asking for, we will revise the scope and the acceptance
standard, and the tender's content version will increment on-chain.

Revision stops when we freeze. From that moment the question cannot move under the
answer, and every delivery records on-chain **which version of the scope it answers** —
which matters for a document that may later be produced to an authority alongside the
engagement record.

## How a delivery is decided

Our CFO holds the acceptance authority. Deliveries are first screened by the
automated conformance check in `acceptance/`, which is deterministic and which any
adviser can run before delivering; a delivery that fails it will be rejected without
further review. Passing the check is necessary and not sufficient — the substance is
read by a person.

Silence is not one of the options available to us. Every delivery starts a review
clock published before any work began; if we neither accept nor reject within it, the
adviser takes the fee. Rejection remains free, and remains attributable.
