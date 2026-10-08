# Day 8

**Tag 8: HA-Installation mit Helm – 3 Pods, Raft**

Starts from Tag 7. Leaves the Helm release `openbao` (chart `openbao/openbao` 0.30.2, image 2.7.0): three pods on three workers, Raft storage, TLS, sealed and uninitialised.

The book works in `~/bao-lab/k8s`.

| File | Book step | Goes to |
|---|---|---|
| `values.yaml` | Drill 3 | `~/bao-lab/k8s/values.yaml` |
| `check.sh` | Kontrollpunkt | `bash check.sh` against that day's lab |

`values-default.yaml` and `rendered.yaml` (Drills 2 and 4) are output of `helm show values` / `helm template` and are not included.
