#!/usr/bin/env python3
"""How much of the compendium has evidence behind it, right now.

appendix-d.py answers "which chapter promises to cover what".  This
answers the harder question: "which of those promises has produced a
file yet".  It reads mapping.csv for the claim and
evidence/REGISTER.csv for the receipt.

    ./tools/coverage.py                 the summary
    ./tools/coverage.py --pending       what is still owed, by chapter
    ./tools/coverage.py --markdown      for pasting into a review

WHAT THIS TOOL DOES NOT CLAIM
-----------------------------
A registered artifact for chapter 7 does not prove SYS.1.6.A3 is met.
It proves chapter 7 produced the file it said it would.  The mapping is
a claim somebody made; the register is a receipt that something exists.
Neither is an assessment, and a tool that reported "compliant" from
these two inputs would be lying.

What it is good for is the gap: a requirement whose chapter has never
produced anything is a requirement nobody has started, and that is worth
knowing in month one rather than in the audit.
"""
import csv
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent.parent
MAPPING = HERE / "mapping.csv"
REGISTER = HERE / "evidence" / "REGISTER.csv"

MARKDOWN = "--markdown" in sys.argv
PENDING = "--pending" in sys.argv


def load_mapping():
    with MAPPING.open() as fh:
        return list(csv.DictReader(fh))


def load_register():
    """chapter -> [artifact, ...]  for everything actually recorded."""
    out = {}
    if not REGISTER.exists():
        return out
    with REGISTER.open() as fh:
        for row in csv.DictReader(fh):
            ch = (row.get("chapter") or "").lstrip("0") or "0"
            out.setdefault(ch, []).append(row.get("artifact", ""))
    return out


def classify(rows, register):
    """evidenced / pending / declared-gap, per requirement."""
    ev, pend, gaps = [], [], []
    for r in rows:
        ch = r["chapter"].strip()
        if not ch.isdigit():
            gaps.append(r)
        elif register.get(ch.lstrip("0") or "0"):
            ev.append(r)
        else:
            pend.append(r)
    return ev, pend, gaps


def main():
    rows = load_mapping()
    register = load_register()
    ev, pend, gaps = classify(rows, register)
    total = len(rows)

    if PENDING:
        by_ch = {}
        for r in pend:
            by_ch.setdefault(int(r["chapter"]), []).append(r)
        for ch in sorted(by_ch):
            print(f"\nChapter {ch:>2}  ({len(by_ch[ch])} requirement(s))")
            for r in by_ch[ch]:
                print(f"    {r['id']:<14} {r['summary']}")
        return 0

    fmt = (lambda s: f"- {s}") if MARKDOWN else (lambda s: f"  {s}")
    if MARKDOWN:
        print("## Evidence coverage\n")
    else:
        print("== Evidence coverage")

    print(fmt(f"requirements in the compendium: {total}"))
    print(fmt(f"evidenced   {len(ev):>2}  "
              f"their chapter has registered at least one artifact"))
    print(fmt(f"pending     {len(pend):>2}  "
              f"mapped to a chapter that has produced nothing yet"))
    print(fmt(f"declared    {len(gaps):>2}  "
              f"deliberately not covered, and named as such"))

    if gaps:
        print()
        for r in gaps:
            print(fmt(f"declared gap: {r['id']} — {r['summary']}"))

    if not register:
        print()
        print(fmt("evidence/REGISTER.csv is empty or missing."))
        print(fmt("That is the expected state in Chapter 3: the chain is"))
        print(fmt("built before there is anything to put through it."))

    print()
    print(fmt("A registered artifact is a receipt that a file exists."))
    print(fmt("It is not an assessment, and this tool does not make one."))
    return 0


if __name__ == "__main__":
    sys.exit(main())
