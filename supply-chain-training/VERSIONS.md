# Versions

The tool versions *Sichere Lieferketten zum Anfassen* was written against,
as the book states them. Nothing here is pinned by a script — unlike
*Harbor in Practice*, this directory has no `versions.sh`. The book asks you
to install current releases (Homebrew or the official binaries, Chapter 0)
and to compare your versions with these when a command behaves differently.

```bash
chapters/ch00/check-tools.sh     # are all tools on the PATH?
```

## What the book requires

| Tool | Expectation in the book | Chapter |
|---|---|---|
| Docker Engine / Desktop / Colima | 8 GB RAM for Docker, 16 GB recommended, ~40 GB disk | 0 |
| `docker compose` | v2.x, the plugin — not the old `docker-compose` | 0 |
| `kubectl` | at most one minor version away from the cluster | 0 |
| `yq` | mikefarah's Go `yq` (`yq --version` prints "mikefarah") | 0 |
| `cosign` | **v2.x**; v3.x works with the alternatives printed in Chapter 5 | 5 |
| OpenSSL | 3.x — macOS ships LibreSSL, use `brew install openssl@3` | 5 |
| `gitleaks` | ≥ 8.19 for `gitleaks dir` / `gitleaks git`; older: `detect`/`protect` | 6 |
| Kyverno | ≥ 1.13 for `failureAction` per rule and namespaced PolicyExceptions | 9, 10 |
| OPA | ≥ 1.0 (Rego v1 syntax); `import rego.v1` works from 0.59 | 9 |
| External Secrets Operator | `external-secrets.io/v1` (from ESO 0.17) | 6 |

The example output in Chapter 5 shows `OpenSSL 3.3.2` and cosign
`GitVersion: v2.4.1`.

## cosign v2 or v3

Chapter 5 prints both variants side by side. In short:

| | cosign v2.x | cosign v3.x |
|---|---|---|
| Offline signing | `--tlog-upload=false` | `cosign signing-config create` → `--signing-config signing-config-offline.json` |
| Certificate chain on `sign` | `--certificate-chain chain.pem` | additionally `--trusted-root trusted-root.json` (`cosign trusted-root create`) |
| Verify with own PKI | `--certificate-chain chain.pem` | `--trusted-root trusted-root.json --allow-certificate-chain` |

Chapters 7 and 11 use the **v2** flags (`--tlog-upload=false`) only. On
cosign v3 replace them with the `OFFLINE` array from Chapter 5, Step 1.

## Images the labs pull

| Image | Tag in the book | Chapter |
|---|---|---|
| `registry` | `2` | 0 |
| `python` | `3.12-slim` (Chapter 2 pins it by digest) | 0, 2, 3 |
| `gitlab/gitlab-ce`, `gitlab/gitlab-runner` | `latest` — the book says to pin a release outside the lab | 1 |
| `gcr.io/kaniko-project/executor` | `v1.23.2-debug` | 1 |
| `jenkins/jenkins` | `lts-jdk21` | 1 |
| `alpine` | `3.20` | 1, 7, 9 |
| Argo CD | `stable/manifests/install.yaml` | 1 |
| `hadolint/hadolint` | untagged | 2 |
| `sonatype/nexus3` | untagged | 3 |
| `hashicorp/vault` | `1.18` | 6 |
| `openbao/openbao` | untagged (alternative) | 6 |
| `postgres` | `16` | 6 |
| `dependencytrack/apiserver`, `dependencytrack/frontend` | `latest` | 7 |
| `anchore/syft` (copied into `Dockerfile.tools`) | `v1.18.0` | 7 |
| OPA, conftest, Kyverno CLI (downloaded into `Dockerfile.policy-tools`, SHA-256 pinned) | `1.4.2`, `0.56.0`, `1.13.4` | 9 |
| `alpine/k8s` | `1.31.13` | 10, 11 |

Python packages of the demo app (Chapter 0): `flask==3.0.3`,
`gunicorn==22.0.0`, `requests==2.25.0` — **deliberately outdated** so that
Chapters 7 and 8 have something to find — and `pytest==8.3.3`.

## CI image versions differ between chapters

The pipeline fragments in Chapters 6–8 and the final pipeline in
Chapter 11 name different versions of the same scanner images. Both are
printed here as the book has them:

| Image | Chapters 6–8 | Chapter 11 |
|---|---|---|
| `aquasec/trivy` | `0.58.1` | `0.74.0` |
| `semgrep/semgrep` | `1.90.0` ("Beispielversion") | `1.180.0` |
| `zricethezav/gitleaks` | `v8.21.2` | `v8.30.1` |
| `bridgecrew/checkov` | `3` | `3.3.26` |
| `anchore/syft` | `v1.18.0` | `v1.54.1-debug` |
| `buildah/stable` | — | `v1.43` |

Chapter 11 is the later and more specific of the two.
