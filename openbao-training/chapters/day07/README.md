# Day 7

**Tag 7: kind-Cluster und TLS**

Starts from Tag 0. Leaves the kind cluster `bao-lab` (one control plane, three workers, context `kind-bao-lab`), a lab CA and a server certificate in `~/bao-lab/tls`, the namespace `openbao` and the secret `openbao-tls`.

The book works in `~/bao-lab/k8s`, `~/bao-lab/tls`.

| File | Book step | Goes to |
|---|---|---|
| `kind.yaml` | Drill 1 | `~/bao-lab/k8s/kind.yaml` |
| `erzeuge-lab-ca.sh` | Drill 3 | writes `ca.key`, `ca.crt` into `~/bao-lab/tls` |
| `openbao.ext`, `erzeuge-server-zertifikat.sh` | Drill 4 | run inside `~/bao-lab/tls`; writes `openbao.ext`, `tls.key`, `tls.csr`, `tls.crt` |
| `check.sh` | Kontrollpunkt | `bash check.sh` against that day's lab |

Needs **OpenSSL 3** from Tag 0 — the LibreSSL in macOS (`/usr/bin/openssl`) rejects `-addext`, `-verify_hostname` and `-verify_ip`. `openbao.ext` is reused on Tag 14, Szenario 7. No key or certificate is included.
