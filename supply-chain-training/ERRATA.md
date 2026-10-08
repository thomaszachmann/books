# Errata

Differences between the book and the code in this directory, and between
the book and later releases of the software. Each entry names the chapter,
the step, and what to do instead.

The book is not published yet. The files here were extracted **verbatim**
from the manuscript's code blocks; nothing was improved on the way.

## Corrections made while extracting

None. No file in `chapters/` differs from the code block it came from.
The only additions are listed in [`README.md`](README.md#how-the-files-were-made):
a shebang and a one-line source comment on the three `erzeuge-*.sh`
wrappers, and the `.tmpl` suffix on files whose heredoc expands a shell
variable.

## Fixed in the manuscript (2026-10-08)

The eight inconsistencies found while extracting are fixed in the book;
the files here were regenerated from the corrected manuscript.

1. **Chapter 9, Steps 9, 10, 12** — `policy/k8s.rego` and `policy/k8s_test.rego` are printed as `opa fmt` (OPA 1.4.2) writes them; `opa fmt --list --fail` is silent, `opa test` passes 5/5.
2. **Chapter 8, Steps 3 and 9; Chapter 11, Steps 5–6** — Chapter 8 creates `.semgrep/python-sicherheit.yaml` and `.checkov.yaml` (baseline + one justified skip) and uses them in its pipeline; Chapter 11 copies exactly these files.
3. **Chapters 6 and 11** — the GitLab project is `root/demo-app` everywhere, as Chapter 1's push-to-create makes it (JWT `bound_claims`, API URL `root%2Fdemo-app`).
4. **Chapter 11, Step 2** — `app.py` stays unchanged; the version is set via `APP_VERSION` (Dockerfile `ARG`/`ENV`, build argument in `build:image`, `env` in the deployment).
5. **Chapter 11, Step 11** — creates `root/demo-deploy` by push-to-create and switches the Chapter 1 Argo CD application `demo-app` to it (`argocd repo add`, `argocd app set`).
6. **Chapters 7 and 8, Step 12** — the CI fragments use Chapter 1's job `build`, `IMAGE_NAME` and the artefact `image-digest.txt` (`needs: [build]`, same branch rule); Chapter 8's stages are `test, build, security`.
7. **Chapters 8, 10, 11** — the YAML ignore file is `.trivyignore.yaml` throughout.
8. **Chapter 9, Step 12** — the job image is built in the chapter from `Dockerfile.policy-tools` (alpine 3.20, OPA 1.4.2, conftest 0.56.0, Kyverno CLI 1.13.4, SHA-256 pinned) and pushed as `reg-build:5000/tools/policy-tools:1.0.0`, like Chapter 7's tools image.

## Found while extracting — open, not changed

None.

## Format

**Chapter N, Step M** — since `<component> <version>`, `<what changed>`.
The step as printed reads `<old>`; use `<new>` instead.
