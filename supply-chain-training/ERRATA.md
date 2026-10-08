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

## Found while extracting — open, not changed

These are inconsistencies in the manuscript itself. The code here keeps
the book's text until the manuscript is fixed.

**Chapter 9, Step 12** — `opa fmt --list --fail policy/` in the
`policy-check` job fails against the book's own `policy/k8s.rego` and
`policy/k8s_test.rego` with OPA 1.4.2: `opa fmt` wants trailing commas in
the multi-line `sprintf(...)` calls and object literals. `opa test` (5/5)
and `opa check` pass. Either format the two printed files with `opa fmt -w`
or drop `--fail` from the job.

**Chapter 11, Step 5** — `test:sast` runs `semgrep scan --config .semgrep/`
and `test:iac` runs `checkov --config-file .checkov.yaml`. The text says
both come "from Chapter 8", but Chapter 8 uses `--config p/python`,
`semgrep-rules/` and `k8s/.checkov.baseline`, and creates neither
`.semgrep/` nor `.checkov.yaml`. The same holds for `semgrep-rules/` in the
Chapter 8 pipeline.

**Chapter 1 vs. Chapters 6 and 11** — GitLab's push-to-create in Chapter 1
makes the project `root/demo-app`; Chapter 6 (JWT role) and Chapter 11
(`project_path`, API URL `seclab%2Fdemo-app`) assume `seclab/demo-app`.
Chapter 11 states the assumption; the JWT `bound_claims` will not match a
`root/demo-app` project.

**Chapter 11, Step 2** — "change the return value of `/version` to
`1.1.0`": `app.py` from Chapter 0 returns the environment variable
`APP_VERSION` with the default `"1.0.0"`. The change meant is presumably the
default, or `APP_VERSION` in `k8s/deployment.yaml`.

**Chapter 11, Step 11** — the deploy repository `~/seclab/demo-deploy` is
used but never created in any chapter.

**Chapter 8, Step 12** — the `security` stage fragment has `needs:
[build-image]`, a job it does not define. **Chapter 7, Step 12** — the `sbom`
job uses `${IMAGE_REF}` and `needs: ["build"]`; the Chapter 1 pipeline
defines `IMAGE_NAME`, not `IMAGE_REF`. Both are fragments meant to be merged
into a pipeline; the names still do not line up.

**Chapter 8 vs. Chapter 10** — Chapter 8 writes `trivyignore.yaml`;
Chapter 10's `exceptions:validate` job and `CODEOWNERS` watch
`.trivyignore.yaml`. Chapter 11 settles on `.trivyignore.yaml`.

**Chapter 9, Step 12** — `${MIRROR}/seclab/policy-tools:1.0` ("eigenes
Image mit kyverno, conftest, opa") is not built anywhere in the book.

## Format

**Chapter N, Step M** — since `<component> <version>`, `<what changed>`.
The step as printed reads `<old>`; use `<new>` instead.
