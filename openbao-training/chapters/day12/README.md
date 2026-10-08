# Day 12

**Tag 12: Betrieb – Audit, Metriken, Snapshots, Upgrades**

Starts from Tag 11. Leaves two declarative audit devices (`stdout/`, `datei/` on the PVC `audit`), Prometheus metrics, a snapshot CronJob, and all three Raft nodes on 2.7.1.

The book works in `~/bao-lab/tag12`.

| File | Book step | Goes to |
|---|---|---|
| `values.yaml` | Drill 2 | `~/bao-lab/k8s/values.yaml` — Tag 11's file plus audit, telemetry, log level, **composed** |
| `roll.sh` | Drill 3 | `~/bao-lab/tag12/roll.sh` |
| `snapshot.hcl` | Drill 9 | stdin of `bao policy write snapshot -` |
| `cronjob.yaml` | Drill 9 | `~/bao-lab/tag12/cronjob.yaml` — needs a PVC `openbao-backup` first |
| `values-2.7.1.yaml` | Drill 10 | `~/bao-lab/k8s/values.yaml` after the image tags are set to 2.7.1, **composed** |
| `check.sh` | Kontrollpunkt | `bash check.sh` against that day's lab |

Drill 2 adds `server.logLevel` and `server.auditStorage` under `server:`, the `telemetry` block inside the `listener`, and the `telemetry` and two `audit` stanzas at the end of `server.ha.raft.config`. Drill 10 replaces the two `tag: "2.7.0"` lines with the book's `tag: "2.7.1"`. The CronJob keeps image 2.7.0, as printed; the book says to raise it after the upgrade. Snapshots (`*.snap`) are not included.
