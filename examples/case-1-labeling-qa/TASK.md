# Support-Ticket Intent Labeling — Batch 0417-0419

**Buyer:** a support-automation vendor building an intent classifier
**Category:** problem-solving — the buyer already knows the answers it checks against
**Settlement:** machine, per batch, no judge

## The commercial situation

We are training an intent classifier on our own historical support tickets. We hold
30,000 unlabeled tickets and need them labeled against the taxonomy in
`spec/labeling-schema.yaml`. This is ordinary, well-priced work with a deep supply
side: labeling teams, agencies, and individual annotators all sell it by the
thousand items.

What has always been awkward about buying it is the settlement, not the work. The
buyer cannot judge 500 labels one by one, and the seller cannot prove diligence
without handing over the labels first. The industry's answer is **gold-standard
sampling**: the buyer seeds each batch with items whose correct labels it already
knows, keeps their positions secret, and grades the returned batch against them.
This tender puts exactly that arrangement on-chain, and nothing else.

## What one completion is

One batch of **500 tickets**, labeled in full, delivered as a JSONL file per
`spec/labeling-schema.yaml`. Three batches are open — 0417, 0418, 0419 — one per
assigned annotator, each paying the same reward.

Seeded invisibly in each batch are **20 gold-standard tickets** whose correct labels
we already hold. Their positions are not disclosed and differ per batch, so the only
way to clear the bar is to label the whole batch carefully. A batch passes when at
least **19 of 20** gold items match (95%).

## How you get paid

Payment does not depend on us being reachable, cooperative, or solvent later.

1. Label your assigned batch and submit the file to the QA endpoint in
   `spec/labeling-schema.yaml`.
2. The endpoint grades it against that batch's gold items and, on a pass, returns
   that batch's **settlement receipt**. Nothing else returns a receipt.
3. Commit `resultHash = sha256(receipt ‖ your_address)` with `submitFulfillment`.
4. After the receipt has been on the books for the tender's minimum settlement age,
   call `settleFulfillment` with the receipt and its Merkle branch. The vault pays
   you in the same transaction.

The bounty for all three batches is already escrowed in this token's vault, visible
to anyone, and the buyer cannot withdraw it while a delivery is outstanding.

## Why one annotator cannot ride another's work

Every batch has its **own** receipt, and the commitment we published before freezing
is a Merkle root over `sha256(receipt ‖ assigned_annotator)`. Batch 0417's receipt is
worthless against batch 0418 — not merely unhelpful, but unusable, because the leaf
is bound to the annotator who was assigned that batch. A shared password would have
meant the first person to settle gives away everyone else's claim.

The tender also refuses settlement until a submission has aged. Someone who copies a
revealed receipt out of the mempool would have to post their own commitment and then
wait, by which time the rightful claim has already settled.

## What we are not putting on-chain

Ticket contents are customer data and never leave our systems; annotators work in our
tool against their assigned batch. The chain verifies that a batch passed QA and pays
for it. Whether the labels are any good is decided by the gold standard, off-chain,
before any receipt exists — which is exactly the division of labour we want: the
buyer's judgment happens where the data is, and the money moves where neither party
can interfere with it.
