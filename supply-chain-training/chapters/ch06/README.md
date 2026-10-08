# Chapter 6

**Kapitel 6: Secrets-Management, Rotation und Ablösung von Zugangsdaten im Repository (Vault/OpenBao, External Secrets Operator)**

Starts from Chapter 0. Runs Vault in dev mode (`VAULT_TOKEN=root`) and Postgres beside the cluster, installs ESO, and syncs `kv/demo-app/db` into the Secret `demo-app-db`.

| File | Book step | Goes to |
|---|---|---|
| `demo-app-read.hcl` | Schritt 6 | `~/seclab/kap06/` |
| `secretstore.yaml`, `externalsecret.yaml` | Schritt 11 | `~/seclab/kap06/` |
| `hooks/pre-commit` | Schritt 15 | `~/seclab/kap06/leak-demo-clean/.git/hooks/pre-commit` |
| `.pre-commit-config.yaml` | Schritt 15 | repository root (team variant) |
| `gitlab-ci-secret-scan.yml` | Schritt 15 | job for `.gitlab-ci.yml` |
| `uebung/team-b-read.hcl` | Übung, Lösung | `~/seclab/kap06/` |

The leak demo of Schritte 2–3 and 14 (`leak-demo/config.py`, `replacements.txt`) is **not** included — see the top-level README.
