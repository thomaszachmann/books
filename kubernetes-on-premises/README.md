# Kubernetes On-Premises — companion repository

Everything the book asks you to type, plus the fixtures it types against.

```sh
git clone https://github.com/thomaszachmann/books.git
cd books/kubernetes-on-premises
make check
```

Work inside this directory. Every path printed in the book is relative
to it, so nothing needs adjusting as you read.

## Layout

| Path | What it is |
|---|---|
| `VERSIONS.md` | The only place a version number lives. Scripts read it. |
| `chapters/chNN/` | One directory per chapter, with its own `README.md` |
| `evidence/` | Where the artifacts land. `REGISTER.csv` is created in Chapter 1 |

## Rules this repository follows

**Nothing here is a substitute for typing.** The scripts exist so you can
check your work and recover when something is broken, not so you can skip
the chapter.

**No real hostnames, no real keys.** Everything resolves under
`meridian.test` or `meridian.example`, both reserved for exactly this.

**The labs run weekly**, against the pinned versions and against whatever
is current. Differences become entries in `ERRATA.md`.

One limitation, stated here rather than in small print: a genuine air gap
cannot be created on a hosted build runner. Part VII is verified in the
pipeline with strict egress denial, which is a simulation. The green-field
offline installation in Chapter 30 is additionally verified by hand
against the physical lab, and the date of that run is recorded here.
