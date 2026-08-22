# Terms — Cross-Border Restructuring Tax Opinion

**Award.** Exclusive. One adviser, one accepted opinion.

**Fee and unit of account.** Priced and settled in DemoUSD, a points-style ERC-20
used by these examples so that a professional fee agreed at award is not repriced by
the settlement asset moving during the engagement. One point stands for 1/100,000 USD
in the worked example; the eighteen-thousand-point fee is play money standing in for
a real engagement fee. DemoUSD is not a stablecoin and has no redemption.

**Escrow.** The full fee is escrowed in DemoUSD before the adviser begins. Funding a
token-denominated tender must carry no native value; the contract rejects it.

**Confidentiality.** The engagement scope is committed as an encrypted object in this
package and released to shortlisted advisers under the engagement NDA. The chain
anchors the hash of the plaintext, so verification is unaffected by encryption. The
acceptance standard and the conformance check are public.

**Scope revision.** The buyer may revise the scope until the tender is frozen; each
revision increments the on-chain content version. The public invitation does not
change, so the primary-document hash is constant across revisions while the package
hash changes. Every delivery records the version it answers.

**Screening then reading.** Deliveries are screened by `acceptance/opinion_check.py`,
which is deterministic and public. Failing it is a rejection without further review.
Passing it is necessary and not sufficient.

**Review deadline.** Every delivery starts a clock fixed at mint. If the buyer
neither accepts nor rejects within it, the adviser may claim the fee. The deadline
survives cancellation.

**Rejection.** Explicit, attributable, terminal for that delivery, free of charge,
and it releases the reserved fee for a revised delivery from the same adviser.

**Deliverable.** A package containing the signed opinion and its manifest.
`resultHash` is that package's deterministic digest, so the exact bytes accepted are
provable afterwards — which matters for a document that may be produced to a tax
authority alongside the engagement record.
