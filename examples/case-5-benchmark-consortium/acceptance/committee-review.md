# Acceptance — a committee vote, and why it is not a single reviewer

## Who decides

The acceptance authority is a K-of-N review committee contract. Each member reviews
independently and votes on-chain. Below quorum nothing settles; at quorum the reward
is released in the same transaction as the deciding vote.

No funder can release the money alone, and no funder can block it alone. That is the
property the benchmark's users are actually paying for: a number they can cite
without having to trust whoever produced it.

## What each member checks

1. **Coverage.** The document counts and classes in `spec/benchmark-release.yaml` are
   met, and the evaluation set contains no training split.
2. **Standard quality.** The labelling standard is sufficient for a new annotator to
   reproduce the labels, and inter-annotator agreement is reported on a real
   double-labelled sample rather than asserted.
3. **Scorer reproducibility.** A member re-runs the reference scorer on the published
   set and obtains the published baseline numbers exactly.
4. **Neutrality.** No contributing firm's taxonomy, tooling, or model is embedded in
   the standard or the scorer. This is the single most common reason to reject.
5. **Licensing.** The published terms match the specification.

## Timeouts, and the order they must be configured in

The committee's voting window expires into **rejection**: silence from reviewers is
not consent, because a benchmark nobody vouched for is not a benchmark.

The kernel's `judgmentWindow` expires into **payment**: silence from the party
holding the money is not a free option.

Both are correct in their own frame, and they disagree. The committee's window MUST
therefore be configured strictly shorter than `judgmentWindow`, so the committee's
default lands first. A deployment that inverts the two makes the committee
decorative: a fulfiller could claim payment while review was still in progress.

## Rejection

Rejection, whether by vote or by committee timeout, is terminal for that delivery,
moves no money, and releases the reserved slot and reward. The team may deliver a
revised release against the same frozen terms.
