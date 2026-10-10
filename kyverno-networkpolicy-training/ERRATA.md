# Errata

Differences between the book and the code in this directory, and between
the book and later releases of the software. Each entry names the day, the
step, and what to do instead.

`code/demo/`, `code/kyverno/` and `code/kyverno-ops/` are copied by the
book itself; it prints only excerpts of them. `code/cilium/` and
`code/np-tests/` reproduce the heredocs of Tags 4–6 and were compared byte
for byte against the manuscript; nothing was improved on the way.

## Corrections made while extracting

None. No file differs in content from the code block it came from. The
only additions:

1. **Tag 4 and Tag 5, a leading comment** — twelve files in `cilium/` have
   one added first line naming the day and the step (for example
   `# Tag 4, Drill 3: …`); the rest is byte-identical to the book's
   heredoc. Tag 4: `api-l4.yaml`, `api-l7.yaml`, `client-fqdn.yaml`,
   `client-entities.yaml`. Tag 5: `ccnp-tenant-deny.yaml`,
   `ccnp-metadata-deny.yaml`, `cnp-tenant-deny.yaml`, `cnp-monitoring.yaml`,
   `cnp-pass-shop.yaml`, `cnp-baseline.yaml`, `calico-gnp.yaml`,
   `cnp-metadata-deny.yaml`. `values-kind.yaml` is identical without any
   addition.
2. **Tag 4, Challenge** — `cilium/scraper-l7.yaml` is composed the way the
   *Lösung* builds it: the `api-l7.yaml` heredoc of Drill 5 followed by the
   block appended with `cat >>`, plus one leading comment line.
3. **Tag 6, Challenge** — the *Lösung* writes
   `~/guard-lab/code/np-tests/policies/50-db-no-egress.yaml`. Here it lives
   in `np-tests/solution/50-db-no-egress.yaml`; `policies/` holds only the
   four files of Drill 1. Content identical.
4. **Tag 6, Challenge** — `np-tests/matrix.tsv` is the file as written in
   Drill 2 (nine tests). The Challenge appends
   `shop/db https://example.com deny` with `echo … >>`; that line is not
   in this file.

Not included on purpose: `~/guard-lab/code/matrix.sh` from the Tag 0
Challenge. You write it as an exercise; Tag 1, Drill 1 uses it.

## Fixed in the manuscript (2026-10-10)

The book was corrected before this release; the PDF and EPUB in the release contain the fixes.

1. **Tag 0, Drill 2; Tag 7; Tag 11** — the copy commands read
   `cp -R <buch-repo>/code/…`. They now clone this repository to
   `~/books` and copy from `~/books/kyverno-networkpolicy-training/code/…`.
2. **Vorwort, Trainingsregel 6** — named `lab-pg-1234` as an example lab
   password, which no day uses. It now names `lab-cosign-pw` (Tag 10).
3. **Tag 5, comment lines in `cilium/`** — `cnp-pass-shop.yaml` said
   `# Tag 5, Drill 7` and `cnp-baseline.yaml` said `# Tag 5, Drill 8`. They
   now name Drill 6 and Drill 7, where the book writes them.

## Open

None reported yet.

## Format

**Tag N, Drill M** — since `<component> <version>`, `<what changed>`.
The step as printed reads `<old>`; use `<new>` instead.
