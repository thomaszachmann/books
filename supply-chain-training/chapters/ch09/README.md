# Chapter 9

**Kapitel 9: Policy as Code (Kyverno, OPA)**

Starts from Chapter 0. Installs Kyverno; Gatekeeper runs briefly in a second cluster `seclab-gk`.

| File | Book step | Goes to |
|---|---|---|
| `k8s/deployment.yaml` | Schritt 1 | `~/seclab/kap09/k8s/` |
| `policies/baseline.yaml` | Schritt 3 | `~/seclab/kap09/policies/` |
| `policies/team-label.yaml` | Schritt 4 | `~/seclab/kap09/policies/` |
| `beispiele/schlecht.yaml` | Schritt 7 | `~/seclab/kap09/beispiele/` |
| `tests/resources.yaml`, `tests/kyverno-test.yaml` | Schritt 8 | `~/seclab/kap09/tests/` |
| `policy/k8s.rego` | Schritt 9 | `~/seclab/kap09/policy/` |
| `policy/k8s_test.rego` | Schritt 10 | `~/seclab/kap09/policy/` |
| `gk-template.yaml`, `gk-constraint.yaml` | Schritt 11 | `~/seclab/kap09/` |
| `gitlab-ci-policy-check.yml` | Schritt 12 | job for `.gitlab-ci.yml` |

The policies are printed in `Audit` mode; Schritt 6 switches them to `Enforce` with `sed`. `opa test policy/` passes 5/5; for `opa fmt --fail` see `../../ERRATA.md`.
