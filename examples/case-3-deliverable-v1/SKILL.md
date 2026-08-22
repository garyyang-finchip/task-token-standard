# Carrier Invoice Extraction Agent — build v1

Delivered against `examples/case-3-invoice-agent`, revision 1.

## Approach

Layout-agnostic extraction. Each document is rendered to text with positional
anchors, then a single structured-output pass maps the page to `InvoiceRecord`.
Carrier identity is inferred from a fingerprint of the header block rather than from
`carrier_hint`, so the agent works on unlabelled input.

Account-code mapping is a two-stage lookup: an exact match against the buyer's
chart of accounts, falling back to nearest-neighbour over a curated set of carrier
line-item phrasings.

## Measured on the development set

| Metric | Bar | v1 |
| --- | --- | --- |
| Field accuracy across scored fields | 98.0% | 96.2% |
| `invoice_total` accuracy | 99.5% | 99.1% |
| Determinism (two runs, identical bytes) | identical | identical |

## Known weakness

Multi-currency tax split. Where tax is stated in the carrier's currency and the
total in the buyer's, the agent applies the document-level currency to the tax line
and the totals disagree by the FX delta. This accounts for most of the shortfall
against both bars.

Submitted for review with the gap disclosed rather than papered over.
