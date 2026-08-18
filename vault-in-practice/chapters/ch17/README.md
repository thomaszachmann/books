# Chapter 17 — Delivering Secrets into Pods

**Starting state:** Chapter 16 complete — a cluster with Vault in dev mode,
the `kubernetes` auth method configured, and the `tracking` role.

**What this chapter builds:** the same secret delivered four ways, so you
can see where each one leaves it.

```bash
./deploy-injector.sh     # file in the pod, nothing in etcd
./deploy-vso.sh          # Kubernetes Secret
./deploy-eso.sh          # Kubernetes Secret, vendor-neutral
./compare.sh             # what exists now, and who can read it
./cleanup.sh
```

`compare.sh` is the point of the chapter. Run it after all three.
