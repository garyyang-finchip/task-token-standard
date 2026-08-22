#!/usr/bin/env python3
"""Conformance check for a delivered tax opinion (profile x-tax-opinion-conformance-v1).

Deterministic, dependency-free, and public: an adviser runs it before delivering, the
buyer runs it before reading. A delivery that fails here is rejected without review.

    python3 opinion_check.py <opinion.md> [--scope <engagement-scope.yaml>]

Exit code 0 on pass, 1 on fail. Every check prints its own verdict so a rejection can
cite the item that failed.
"""
import argparse
import re
import sys

REQUIRED_SECTIONS = [
    "Executive Summary",
    "Facts and Assumptions",
    "Questions Presented",
    "Analysis",
    "Conclusions",
    "Limitations and Reliance",
    "Signature",
]
PLACEHOLDERS = ["TBD", "TODO", "XXX", "lorem ipsum", "[ ]", "<insert", "FIXME"]
MIN_WORDS_PER_ANALYSIS = 250
MIN_CITATIONS = 8

CITATION_PATTERNS = [
    r"\bArticle\s+\d+", r"\bArt\.\s*\d+", r"\bChapter\s+[IVX]+",
    r"\bCircular\s+No\.?\s*[\w/\-]+", r"\bProtocol\b", r"\bParagraph\s+\d+",
    r"\bSection\s+\d+", r"\bDecree\s+No\.?\s*[\w/\-]+",
]


class Report:
    def __init__(self):
        self.rows = []
        self.failed = 0

    def check(self, name, ok, detail=""):
        self.rows.append((name, ok, detail))
        if not ok:
            self.failed += 1

    def render(self):
        width = max(len(r[0]) for r in self.rows)
        for name, ok, detail in self.rows:
            mark = "PASS" if ok else "FAIL"
            print(f"  [{mark}] {name.ljust(width)}  {detail}")
        print()
        if self.failed:
            print(f"CONFORMANCE: FAIL ({self.failed} of {len(self.rows)} checks failed)")
        else:
            print(f"CONFORMANCE: PASS ({len(self.rows)} checks)")
        return 1 if self.failed else 0


def sections(text):
    """Map heading text -> body, for '## ' and '### ' headings."""
    out, current, buf = {}, None, []
    for line in text.splitlines():
        m = re.match(r"^#{2,3}\s+(.*?)\s*$", line)
        if m:
            if current is not None:
                out[current] = "\n".join(buf)
            current, buf = m.group(1), []
        elif current is not None:
            buf.append(line)
    if current is not None:
        out[current] = "\n".join(buf)
    return out


def scope_question_ids(path):
    ids = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            m = re.match(r"\s*-\s*id:\s*(Q\d+)\s*$", line)
            if m:
                ids.append(m.group(1))
    return ids


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("opinion")
    ap.add_argument("--scope", help="decrypted engagement scope, to cross-check question coverage")
    args = ap.parse_args()

    text = open(args.opinion, encoding="utf-8").read()
    secs = sections(text)
    rep = Report()

    # 1 - required sections
    for want in REQUIRED_SECTIONS:
        hit = [k for k in secs if k.lower().startswith(want.lower())]
        rep.check(f"section: {want}", bool(hit), hit[0] if hit else "missing")

    # 2/3/4 - one analysis section, one express conclusion, and real reasoning per question
    qids = sorted(set(re.findall(r"\bQ(\d+)\b", text)), key=int)
    rep.check("questions detected", bool(qids), "Q" + ", Q".join(qids) if qids else "none")
    for q in qids:
        key = [k for k in secs if re.search(rf"Analysis\s*[—-]\s*Q{q}\b", k)]
        rep.check(f"analysis section for Q{q}", bool(key), key[0] if key else "missing")
        if key:
            words = len(secs[key[0]].split())
            rep.check(f"analysis depth Q{q}", words >= MIN_WORDS_PER_ANALYSIS,
                      f"{words} words (min {MIN_WORDS_PER_ANALYSIS})")
        rep.check(f"express conclusion Q{q}",
                  bool(re.search(rf"\*\*Conclusion\s*\(Q{q}\)\s*:\*\*", text)),
                  "**Conclusion (Q%s):**" % q)

    # 5 - citations to named authority
    cites = []
    for pat in CITATION_PATTERNS:
        cites += re.findall(pat, text)
    rep.check("citations to authority", len(cites) >= MIN_CITATIONS,
              f"{len(cites)} found (min {MIN_CITATIONS})")

    # 6 - no placeholders
    found = [p for p in PLACEHOLDERS if p.lower() in text.lower()]
    rep.check("no placeholder text", not found, ", ".join(found) if found else "clean")

    # 7 - signature block
    sig = next((secs[k] for k in secs if k.lower().startswith("signature")), "")
    has_name = bool(re.search(r"^\s*(Signed|Name)\s*:", sig, re.M))
    has_qual = bool(re.search(r"^\s*Qualification\s*:", sig, re.M))
    has_date = bool(re.search(r"\b\d{4}-\d{2}-\d{2}\b", sig))
    rep.check("signature block complete", has_name and has_qual and has_date,
              f"name={has_name} qualification={has_qual} date={has_date}")

    # 8 - coverage against the confidential scope, when the key holder supplies it
    if args.scope:
        want = scope_question_ids(args.scope)
        missing = [q for q in want if not re.search(rf"\b{q}\b", text)]
        rep.check("scope coverage", not missing,
                  "all of " + ", ".join(want) if not missing else "missing " + ", ".join(missing))
    else:
        print("  [note] no --scope supplied: question coverage not cross-checked\n")

    return rep.render()


if __name__ == "__main__":
    sys.exit(main())
