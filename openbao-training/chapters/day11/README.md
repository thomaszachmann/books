# Day 11

**Tag 11: Workloads anbinden – Kubernetes-Auth, External Secrets Operator, Agent Injector**

Starts from Tag 10. Leaves the namespace `webshop` with the ServiceAccount `webshop`, Kubernetes auth with the role `webshop`, the External Secrets Operator syncing `webshop-config`, the Agent Injector, and the pod `webshop-agent`.

The book works in `~/bao-lab/tag11`.

| File | Book step | Goes to |
|---|---|---|
| `webshop-read.hcl` | Drill 4 | stdin of `bao policy write webshop-read -` |
| `eso.yaml` | Drill 6 | `~/bao-lab/tag11/eso.yaml` (SecretStore + ExternalSecret) |
| `values.yaml` | Drill 8 | `~/bao-lab/k8s/values.yaml` — Tag 10's file with the injector enabled, **composed** |
| `agent-pod.yaml` | Drill 9 | `~/bao-lab/tag11/agent-pod.yaml` |
| `check.sh` | Kontrollpunkt | `bash check.sh` against that day's lab |
| `challenge/externalsecret-webshop-all.yaml` | Challenge, Lösung | stdin of `kubectl apply -f -` |

The namespace, the ServiceAccount and the secret `openbao-ca` are created imperatively with `kubectl create`; the book has no manifest for them, so there is none here. `k8s-ca.crt` (Drill 3) is not included.
