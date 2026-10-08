# Chapter 7

**Kapitel 7: SBOM nach CycloneDX/SPDX und Abhängigkeitsanalyse (Syft, Dependency-Track)**

Starts from Chapter 5 for the attestation step (`~/seclab/kap05/cosign.key`). Runs Dependency-Track on `localhost:8080` (API) and `localhost:8088` (UI).

| File | Book step | Goes to |
|---|---|---|
| `docker-compose.yml` | Schritt 7 | `~/seclab/kap07/` |
| `Dockerfile.tools` | Schritt 12 | `~/seclab/kap07/` — `docker build -t localhost:5001/tools/sbom:1.0.0 - < Dockerfile.tools` |
| `gitlab-ci-sbom.yml` | Schritt 12 | jobs for `.gitlab-ci.yml` |
| `gitlab-ci-sbom-gate.yml` | Schritt 12 | job for `.gitlab-ci.yml` |

The Dependency-Track API key is read with `read -rs` and only exported to the shell.
