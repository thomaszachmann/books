# Chapter 1

**Kapitel 1: CI/CD-Ketten selbst betreiben (GitLab CI, Jenkins, Argo CD/Flux)**

Starts from Chapter 0. Leaves GitLab CE and a registered runner (stopped), Jenkins (stopped) and Argo CD syncing `k8s/` of `root/demo-app` into `demo`.

| File | Book step | Goes to |
|---|---|---|
| `gitlab/compose.yaml` | Schritt 1 | `~/seclab/kap01/gitlab/` |
| `demo-app/.gitlab-ci.yml` | Schritt 6 | `~/seclab/demo-app/` |
| `demo-app/Jenkinsfile` | Schritt 9 | `~/seclab/demo-app/` |
| `argocd-app.yaml.tmpl` | Schritt 13 | `GITLAB_IP=… envsubst < argocd-app.yaml.tmpl > ~/seclab/kap01/argocd-app.yaml` |
| `uebung/runner-docker-allowlist.toml` | Übung, Lösung | replaces `[runners.docker]` in `~/seclab/kap01/config.toml` (other lines stay) |

The runner token (`glrt-…`) is read with `read -rs`; the runner stores it in its own `config.toml` inside the container, never here.
