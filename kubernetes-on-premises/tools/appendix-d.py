#!/usr/bin/env python3
"""Regenerate the two tables of Appendix D from the vendored control files.

The identifier, title and protection level come from ComplianceAsCode.
The chapter and the artifact come from mapping.csv, which is the part
this book maintains. Merging them here rather than typing them into the
manuscript is the whole point: if the compendium gains or loses a
requirement, this fails instead of drifting.

    ./tools/appendix-d.py            print both tables
    ./tools/appendix-d.py --check    exit non-zero if the sets disagree
"""
import csv
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent.parent
VENDOR = HERE / "vendor" / "compliance-as-code"
LEVEL = {"basic": "B", "standard": "S", "elevated": "E"}

BLOCKS = [
    ("SYS.1.6 Containerisation", VENDOR / "bsi_sys_1_6.yml"),
    ("APP.4.4 Kubernetes", VENDOR / "bsi_app_4_4.yml"),
]


def controls(path):
    """(id, level, title) for every requirement, in file order."""
    out = []
    for block in re.split(r"\n    - id: ", path.read_text())[1:]:
        cid = block.split("\n", 1)[0].strip()
        if not re.match(r"^(SYS|APP)\.[\d.]+\.A\d+$", cid):
            continue
        m = re.search(r"title: '?(.+?)'?\s*\n", block)
        lv = re.search(r"levels:\n((?:\s+- \w+\n)+)", block)
        lvls = re.findall(r"- (\w+)", lv.group(1)) if lv else []
        out.append((cid, LEVEL.get(lvls[0] if lvls else "", "?"),
                    m.group(1).strip() if m else "?"))
    return out


def mapping():
    with (HERE / "mapping.csv").open(newline="") as f:
        return {r["id"]: r for r in csv.DictReader(f)}


def main():
    check = "--check" in sys.argv
    mp = mapping()
    seen, problems = set(), []

    for heading, path in BLOCKS:
        rows = controls(path)
        if not check:
            print(f"\n## {heading}\n")
            print("| Requirement | What it demands | Ch. | Artifact |")
            print("|---|---|---|---|")
        for cid, lvl, title in rows:
            seen.add(cid)
            m = mp.get(cid)
            if m is None:
                problems.append(f"{cid} is in the catalogue and not in "
                                f"mapping.csv")
                continue
            n = cid.rsplit(".", 1)[1]
            if not check:
                print(f"| **{n}** ({lvl}) {title} | {m['summary']} | "
                      f"{m['chapter']} | {m['artifact']} |")

    for cid in mp:
        if cid not in seen:
            problems.append(f"{cid} is in mapping.csv and not in the "
                            f"catalogue")

    if problems:
        print("\n".join(problems), file=sys.stderr)
        print(f"{len(problems)} problem(s). The compendium moved, or "
              f"mapping.csv did.", file=sys.stderr)
        return 1
    if check:
        print(f"appendix-d OK  ({len(seen)} requirements mapped)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
