# Chapter 16 — Kubernetes Foundations

**Starting state:** Docker running. For Lab 16B, the Chapter 2 Vault
container up and unsealed.

**What this chapter builds:** a local cluster (kind or minikube), Vault
installed via Helm, and the `kubernetes` auth method configured both
in-cluster and from outside.

```bash
./cluster-up.sh kind        # or: ./cluster-up.sh minikube
./setup-k8s-auth.sh         # Vault inside the cluster
./setup-external-vault.sh   # Vault outside, the Chapter 2 container
./cluster-down.sh
```

Everything about Kubernetes objects is identical between kind and
minikube. Everything about **networking between the cluster and the host**
differs, which is why both are here.
