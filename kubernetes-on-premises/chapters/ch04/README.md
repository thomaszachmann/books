# Chapter 4 — Choosing the Substrate

**State this chapter expects:** Chapter 1, so that `evidence/REGISTER.csv`
exists. No cluster, no network.

| Path | What it is |
|---|---|
| `products.tsv` | Dated snapshot: every product in ComplianceAsCode and its profiles |
| `profiles.sh` | Answers the three questions the chapter asks, offline |
| `substrate-decision.md` | Template for the artifact. Copy it into `evidence/ch04/` |

## The snapshot is the point

`products.tsv` is not a cache, it is the offline behaviour this whole
book is about. Refresh it deliberately, from a clone, and read the diff:

```sh
./profiles.sh --refresh ~/src/content
git diff products.tsv
```

A product appearing or losing a profile is a change to Chapter 4's
recommendation, not a routine update.
