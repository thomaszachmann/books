# Chapter 11

**Kapitel 11: Abschlussprojekt – die ganze Kette**

Assumes Chapters 0–10: Nexus, Vault, Dependency-Track, both registries, Kyverno and Argo CD running, GitLab project `seclab/demo-app`, deploy repository `seclab/demo-deploy`.

| File | Book step | Goes to |
|---|---|---|
| `demo-app/Dockerfile` | Schritt 2 | `~/seclab/demo-app/` |
| `erzeuge-ausnahmen.sh` | Schritt 3 | run in `~/seclab/demo-app` — copies the Chapter 10 checks to `ci/`, writes `exceptions.yaml` and `.trivyignore.yaml` |
| `vault/demo-app-ci.hcl` | Schritt 4 | `vault policy write demo-app-ci -` |
| `vault/jwt-role-demo-app.json` | Schritt 4 | `vault write auth/jwt/role/demo-app -` |
| `demo-app/.gitlab-ci.yml` | Schritt 5 | `~/seclab/demo-app/` |
| `zielzone-policies.yaml` | Schritt 10 | `~/seclab/kap11/` — then replace `PLATZHALTER` with `cosign.pub` using the book's `yq` command |

The Dependency-Track key goes into Vault as `<API-Key aus Kapitel 7>`; `GITLAB_TOKEN` is `<dein Lab-Token>`. Neither is stored here. `.semgrep/` and `.checkov.yaml` are referenced by the pipeline but not defined in the book — see `../../ERRATA.md`.
