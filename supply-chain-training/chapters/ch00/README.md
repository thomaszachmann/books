# Chapter 0

**Kapitel 0: Dein Labor aufbauen**

Starts from nothing. Leaves two registries (`reg-build` on `localhost:5001`, `reg-ziel` on `localhost:5002`), the kind cluster `seclab` attached to the Docker network `kind`, and `demo-app:1.0.0` running in namespace `demo`.

| File | Book step | Goes to |
|---|---|---|
| `check-tools.sh` | Versionen prüfen | `~/seclab/check-tools.sh` |
| `erzeuge-hosts-toml.sh` | Schritt 2 | writes `~/seclab/containerd-certs.d/<reg>:5000/hosts.toml` |
| `kind.yaml.tmpl` | Schritt 3 | `envsubst < kind.yaml.tmpl > ~/seclab/kind.yaml` (needs `$HOME`) |
| `demo-app/app.py` | Schritt 6 | `~/seclab/demo-app/` |
| `demo-app/requirements.txt`, `requirements-dev.txt` | Schritt 7 | `~/seclab/demo-app/` |
| `demo-app/tests/test_app.py` | Schritt 8 | `~/seclab/demo-app/tests/` |
| `demo-app/Dockerfile`, `.dockerignore`, `.gitignore` | Schritt 9 | `~/seclab/demo-app/` |
| `demo-app/k8s/deployment.yaml`, `service.yaml` | Schritt 10 | `~/seclab/demo-app/k8s/` |

`requests==2.25.0` is outdated on purpose — Chapters 7 and 8 scan for it.
