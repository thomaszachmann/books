# Chapter 10

**Kapitel 10: Zusammenarbeit mit Entwicklungsteams, Ausnahmen und Übergangsfristen**

Starts from Chapter 9 (Kyverno installed). Enables PolicyExceptions in namespace `policy-exceptions`.

| File | Book step | Goes to |
|---|---|---|
| `policies/require-run-as-non-root.yaml` | Schritt 2 | `~/seclab/kap10/policies/` |
| `legacy-batch.yaml` | Schritt 2 | `~/seclab/kap10/` |
| `exception-legacy-batch.yaml.tmpl` | Schritt 4 | `EXPIRES=… envsubst < … > ~/seclab/kap10/exception-legacy-batch.yaml` |
| `policies/require-exception-metadata.yaml` | Schritt 4 | `~/seclab/kap10/policies/` |
| `find-expired-exceptions.sh`, `cronjob-expired-exceptions.yaml` | Schritt 6 | `~/seclab/kap10/` |
| `exceptions.yaml.tmpl` | Schritt 7 | `CREATED=… EXPIRES=… envsubst < … > ~/seclab/kap10/exceptions.yaml` |
| `check-exceptions.sh`, `gitlab-ci-exceptions.yml`, `CODEOWNERS` | Schritt 8 | `~/seclab/kap10/`, repository root |
| `app/.trivyignore.yaml.tmpl`, `check-trivyignore.sh` | Schritt 9 | `~/seclab/kap10/app/.trivyignore.yaml`, `~/seclab/kap10/` |
| `ROLLOUT-PLAN-TEMPLATE.md`, `MAIL-TEMPLATE.txt` | Schritt 10 | `~/seclab/kap10/` |
| `uebung/exceptions-eintrag.yaml`, `exception-payment-gateway.yaml` | Übung, Lösung | register entry and PolicyException |

The book computes `EXPIRES` as today + 30 days (`date -u -d '+30 days' +%F` on Linux, `date -u -v+30d +%F` on macOS).
