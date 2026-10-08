# Errata

Differences between the book and the code in this directory, and between
the book and later releases of the software. Each entry names the day, the
step, and what to do instead.

The book is not published yet. The files here were extracted **verbatim**
from the manuscript's code blocks; nothing was improved on the way.

## Corrections made while extracting

None. No file in `chapters/` differs from the code block it came from.
The only additions are listed in [`README.md`](README.md#how-the-files-were-made):
a shebang and a one-line source comment on wrapped blocks, the `.tmpl`
suffix on heredocs that expand `$HOME` or `$PWD`, and the composed
`values.yaml` files of Tags 10–12.

## Fixed in the manuscript (2026-10-08)

The book was corrected and `chapters/` was extracted again, still verbatim.

1. **Tag 14, rights** — Vorbereitung writes the policy `wettkampf` (only `secret/{data,metadata,undelete}/webshop/config`, `sys/audit-hash/datei`) and works as user `wettkampf` (`bao-admin` + `wettkampf`, deleted at the end); `bao-admin` stays secret-free as on Tag 13.
2. **Tag 14, Szenario 4** — expected `REFRESH INTERVAL` is `15s`, as set on Tag 11.
3. **Tag 14, Szenario 7** — both certificates use Tag 7's `openbao.ext` (same ten SANs and key usages), `-sha256`, renewal `-days 180`.
4. **Tag 0 / Tag 7** — Tag 0 installs `openssl@3`, puts it on the `PATH` and checks `openssl version` for OpenSSL 3 (Linux: ≥ 3.4 for Tag 14); Tag 7's briefing points back to it.
5. **Tag 14, Szenario 6** — uses its own AppRole `leak-drill` and deletes it, so the OpenTofu-managed role `webshop` stays without drift.
6. **Style** — all `bao kv` calls in Tag 1 (KV v1), Tag 6, Tags 9–14 and both appendices use `-mount=`; Tag 6 uses `token_policies=`; Tag 13, Drill 8 shows the 2.7.1 message for `-mount=`.
7. **Further fixes** — Anhang B now names its token (Break-Glass root from Tag 13, Drill 4, revoked after Part 1; `bao-admin` cannot read secrets or restore snapshots); Tag 14 logs in with `-token-only` like Tag 13 and logs in again after Szenario 5's restore.

## Open

None.

## Format

**Tag N, Drill M** — since `<component> <version>`, `<what changed>`.
The step as printed reads `<old>`; use `<new>` instead.
