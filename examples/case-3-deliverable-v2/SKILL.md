# Carrier Invoice Extraction Agent — build v2

Delivered against `examples/case-3-invoice-agent`, revision 2. Supersedes build v1,
which was rejected at 96.2% field accuracy.

## What changed

Currency is resolved **per line**, not per document. Each line item now carries the
currency it was stated in, and totals are reconciled after converting every line to
the invoice currency at the rate printed on the document. Where no rate is printed,
the line is flagged `needs_review` and `invoice_total` is emitted as null rather than
guessed — refusing is scored better than a wrong total, and this is where v1 lost
most of its margin.

Two secondary fixes: reweigh credits are now matched to the original consignment by
reference rather than by date proximity, and near-duplicate invoices are flagged
instead of silently deduplicated.

## Measured on the development set

| Metric | Bar | v1 | v2 |
| --- | --- | --- | --- |
| Field accuracy across scored fields | 98.0% | 96.2% | 98.7% |
| `invoice_total` accuracy | 99.5% | 99.1% | 99.8% |
| Determinism (two runs, identical bytes) | identical | identical | identical |

## Ownership

The buyer receives this package in full: agent, configuration, and the scoring
harness used to produce the table above. No licence key, no call-home, and the model
endpoint is configured by the buyer and replaceable without repackaging.
