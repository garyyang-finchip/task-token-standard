"""Carrier invoice extraction, build v2. Illustrative excerpt of the delivered package."""

SCORED = ("invoice_number", "invoice_date", "currency", "invoice_total",
          "account_code", "amount")


def extract(document: bytes, carrier_hint: str | None = None) -> dict:
    page = render_with_anchors(document)
    carrier = fingerprint_header(page)          # carrier_hint is advisory only
    record = map_to_record(page, carrier)
    record["currency"] = document_currency(page)
    for line in record["line_items"]:
        # v2: each line keeps the currency it was stated in, then converts at the
        # rate printed on the document. This is what the buyer's multi-currency
        # tax-split invoices needed, and where v1 lost its margin.
        line["currency"] = line_currency(line, page) or record["currency"]
        line["amount"] = to_invoice_currency(line, page)
        line["account_code"] = map_account(line["description"], carrier)
    if not totals_reconcile(record):
        # refusing beats guessing: a wrong invoice_total is scored worse than none
        record["invoice_total"] = None
        record.setdefault("flags", []).append("needs_review")
    return record
