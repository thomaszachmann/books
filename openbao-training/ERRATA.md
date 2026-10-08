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

## Found while extracting — open, not changed

1. **Tag 14, Vorbereitung; Szenarien 4, 5, 6, 8** — the drills log in as
   `admin` (policy `bao-admin` from Tag 13), but `bao-admin` grants nothing
   on `secret/` and nothing on `sys/audit-hash/*`. Checked with `bao` 2.7.1:
   `bao token capabilities` returns `deny` for `secret/data/webshop/config`,
   `secret/metadata/webshop/config` and `sys/audit-hash/datei`. Affected:
   every `bao kv …` in Szenario 4, `bao kv get` in Szenario 5 (Prüfung) and
   Szenario 8 (Behebung), and `sys/audit-hash/datei` in Szenario 6
   (Diagnose). Tag 13 itself says the admin *liest aber keine Secrets*.
   Either extend the policy for Tag 14 or use a separate token for these
   steps.
2. **Tag 14, Szenario 4, Symptome** — the expected output shows
   `webshop-config … REFRESH INTERVAL 1m`. Tag 11, Drill 6 sets
   `refreshInterval: 15s` for `webshop-config`; `1m` belongs to the
   challenge's `webshop-all`.
3. **Tag 14, Szenario 7** — the renewal certificate's `san.ext` has no
   explicit `openbao-0/1/2.openbao-internal` and no key usages. Tag 7,
   Drill 4 adds those names on purpose, and Tag 7's challenge concludes
   *Neue Pod-Namen explizit als SAN aufnehmen*. Go (Raft `retry_join`)
   accepts the wildcard, so the drill works, but OpenSSL-based clients do
   not. Reuse `openbao.ext` from Tag 7 for the renewal.
4. **Tag 0, Drill 1 vs. Tag 7 and Tag 14** — Tag 0 does not install
   OpenSSL 3. On macOS, `/usr/bin/openssl` is LibreSSL (3.3.6 on the test
   machine) and fails Tag 7 (`-addext`, `-verify_hostname`, `-verify_ip`)
   and Tag 14, Szenario 7 (`-not_before`/`-not_after`, OpenSSL ≥ 3.4).
   Add `openssl@3` to the `brew install` line and `openssl` to the
   Kontrollpunkt.
5. **Tag 14, Szenario 6 vs. Tag 13, Drill 9** — Szenario 6 rewrites
   `auth/approle/role/webshop` with `token_policies=webshop-read`. OpenTofu
   has managed that role since Tag 13 (policy `webshop-read-tf`), so
   Tag 13's Kontrollpunkt *OpenTofu ohne Drift* fails after Tag 14.
6. **Tag 6 and Part B, style** — Tag 1 recommends `-mount=` (*Nimm
   `-mount=`*), Tag 6 and Tags 9–14 use the short form
   `bao kv put secret/…`. Tag 6, Drill 3 and the challenge create userpass
   users with the legacy `policies=`, the other days with
   `token_policies=`. Both work with 2.7.1 (`policies=default` is stored as
   `token_policies [default]`); it is only inconsistent.

## Format

**Tag N, Drill M** — since `<component> <version>`, `<what changed>`.
The step as printed reads `<old>`; use `<new>` instead.
