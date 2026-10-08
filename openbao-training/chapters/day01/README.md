# Day 1

**Tag 1: Dev-Server und KV v2**

Starts from a fresh dev server (`bao server -dev -dev-root-token-id=root`). Leaves `secret/webshop/config` with five versions, the KV v1 mount `kv1/` and the KV v2 mount `team-shop/`.

The book works in `~/bao-lab/tag01`.

| File | Book step | Goes to |
|---|---|---|
| `check.sh` | Kontrollpunkt | `bash check.sh` against that day's lab |

Tag 1 works only with the CLI and `curl`; it writes no files of its own.
