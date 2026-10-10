# Errata

This file lists differences between the book and the code in this directory, and between
the book and later releases of the software. Each entry names the day, the step, and what
to do instead.

## Corrections made while extracting

None. The files were copied unchanged from the manuscript's `code/` folder. Nothing was
improved on the way.

## Differences between the book and `code/`

The book has you type 34 of these files as heredocs (`cat > file <<'EOF'`) on Tags 0–7.
28 of them are byte-identical to the file here. The other six differ only in ways that
do not change what Kubernetes receives:

1. **Tag 4, Drill 7 (`secure-api.yaml`, `backend-tls.yaml`); Tag 5, Challenge solution
   (`qa-canary.yaml`); Tag 6, Drill 5 (`tcproute.yaml`) and Drill 6 (`udproute.yaml`).**
   The file here has one extra comment line at the top, for example
   `# TCPRoute (v1 seit Gateway API v1.6)`. The heredoc in the book does not have it.
2. **Tag 6, Drill 5 (`l4-echo.yaml`).** The file here indents the list items under
   `containers:`, `env:` and `ports:` two spaces less than the heredoc. Both parse to the
   same YAML.

If you typed the book's version, you have the right file.

## Layout notes

1. **Tag 4, Tag 7 → Tag 9, Tag 14, Anhang B.** The heredocs of Tag 4 and Tag 7 write into
   `~/gw-lab/tag04` and `~/gw-lab/tag07`. Later days apply the copies under
   `~/gw-lab/code/`: `code/tag04/lab-ca.yaml` (Tag 9, Anhang B) and
   `code/tag07/refgrant-backend.yaml` (Tag 14). Copy `code/` to `~/gw-lab/` as the [README](README.md) describes,
   or use the path of your own file.
2. **Tag 9, Drill 3.** The book changes `infra-rke2/group_vars/all.yml` in place
   (`cilium_gateway_class_create: auto` → `"true"`). The file here holds the value from
   *before* Tag 9, which is what Tag 8 expects.
3. **Anhang B, Aufgabe 10.** The book has you type a `legacy-ingress.yaml` in
   `~/gw-lab/pruefung`. It is a different file from `code/tag13/legacy-ingress.yaml`
   (host `legacy.pruefung.gw.localtest.me`, one Ingress). Do not mix them up.

## Fixed in the manuscript (2026-10-10)

The book was corrected before this release; the PDF and EPUB in the release contain the fixes.

1. **Tag 0, Drill 3.** From Tag 4 on the book applies files it does not print in full,
   such as `tag04/secure-backend.yaml` and `tag07/rbac.yaml`. Tag 0 now names this
   repository and copies `code/` to `~/gw-lab/code/`. Before, it never said where to get
   them.

## Open

None reported yet.

## Format

**Tag N, Drill M** — since `<component> <version>`, `<what changed>`.
The step as printed reads `<old>`; use `<new>` instead.
