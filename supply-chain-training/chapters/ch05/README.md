# Chapter 5

**Kapitel 5: Offline-Signatur und Herkunftsprüfung mit eigenem Vertrauensanker (Cosign, eigene PKI)**

Starts from Chapter 0 (`demo-app:1.0.0` in `reg-build`). Leaves an offline root CA, an intermediate CA, a signing certificate and a cosign key pair under `~/seclab/pki` and `~/seclab/kap05`.

| File | Book step | Goes to |
|---|---|---|
| `pki/root/root.cnf` | Schritt 2 | `~/seclab/pki/root/` |
| `pki/intermediate/intermediate.cnf` | Schritt 3 | `~/seclab/pki/intermediate/` |
| `signer.cnf` | Schritt 4 | `~/seclab/kap05/` |
| `provenance.json.tmpl` | Schritt 8 | `COMMIT=… envsubst < provenance.json.tmpl > ~/seclab/kap05/provenance.json` |
| `erzeuge-kyverno-verify-images.sh` | Schritt 9 | writes `~/seclab/kap05/kyverno-verify-images.yaml` from `cosign.pub` |

cosign v2 and v3 differ in the offline flags — see `../../VERSIONS.md`. The passwords `lab-root-pass`, `lab-int-pass` and `lab-cosign-pass` are lab values; no key or certificate is included.
