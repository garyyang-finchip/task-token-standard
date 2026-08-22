"""Carrier invoice extraction, build v1. Illustrative excerpt of the delivered package."""

SCORED = ("invoice_number", "invoice_date", "currency", "invoice_total",
          "account_code", "amount")


def extract(document: bytes, carrier_hint: str | None = None) -> dict:
    page = render_with_anchors(document)
    carrier = fingerprint_header(page)          # carrier_hint is advisory only
    record = map_to_record(page, carrier)
    # v1: one currency for the whole document. Invoices that state tax in the
    # carrier's currency and the total in the buyer's are mis-summed by the FX delta.
    record["currency"] = document_currency(page)
    for line in record["line_items"]:
        line["account_code"] = map_account(line["description"], carrier)
    if not totals_reconcile(record):
        record["invoice_total"] = None
        record.setdefault("flags", []).append("needs_review")
    return record
