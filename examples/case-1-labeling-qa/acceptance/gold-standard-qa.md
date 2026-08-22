# Acceptance — gold-standard sampling, decided before any receipt exists

## The bar

Each batch of 500 contains **20 gold-standard tickets** whose correct labels the buyer
holds. A batch passes when **at least 19 of 20 match** (95%). Matching is exact
against `taxonomy.labels`; `confidence` and `notes` are not graded.

Gold positions are secret and differ per batch. They are drawn across the whole
taxonomy, including `other.unclassifiable`, so a batch cannot be passed by labeling
everything with one safe value.

## Who decides, and when

The grading happens off-chain, in the buyer's QA system, at the moment the batch is
submitted — before any on-chain object exists. The chain never sees a label. What the
chain checks is narrower and fully mechanical:

    sha256(proof.receipt || submission.fulfiller) == submission.resultHash
    and that leaf is in the committed Merkle root
    and block.timestamp >= submission.submittedAt + minAge

A passing batch yields a receipt; a failing batch yields nothing to settle with. The
buyer cannot withhold a receipt from a batch that passed without the failure being
visible: the bounty stays escrowed, the slot stays reserved, and the buyer cannot
reclaim it.

## What each side can rely on

**The annotator.** No one can accept, reject, stall, or reverse a valid claim — the
judgment slot is a contract. The reward for their batch is reserved from the moment
they submit. Their receipt cannot be replayed by anyone else, because the committed
leaf binds their address. And nobody can front-run their reveal, because settlement
is refused until the submission has aged.

**The buyer.** Nothing pays out for a batch that did not pass QA. The commitment is
set-once, so the buyer cannot be accused of moving the bar after seeing the work; the
Merkle root was published before the tender was frozen and is checkable by anyone.

## Out of scope

Annotator sourcing, tooling access, ticket confidentiality, and the assignment of
batches to annotators are contractual matters settled before this tender exists. The
kernel prices and pays; it does not recruit.
