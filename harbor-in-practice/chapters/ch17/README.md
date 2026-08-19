# Chapter 17 — VM or Kubernetes, and What Enterprises Should Do

**This chapter has no lab.** It is the one you could hand to somebody
who will never type any of the rest of the book.

```bash
./ha-readiness.sh                      # a running helm release
./ha-readiness.sh ../../k8s/values-harbor.yaml
```

## The rule

> **One team, one environment, no availability commitment**
> → a virtual machine, with the installer.

> **Multiple clusters, a regulator, or a stated availability target**
> → Kubernetes, with the chart, in a **separate** platform cluster,
> with external PostgreSQL, external Redis and object storage.

> **Never in the cluster it serves.** Not a trade-off.

## Why replicas are not availability

The chart lets seven components scale — `nginx`, `portal`, `core`,
`jobservice`, `registry`, `trivy`, `exporter` — and `database` and
`redis` have **no `replicas` field at all**. They are single instances
by construction.

The components that scale are exactly the stateless ones. Every piece of
state has to leave the installation before more than one Harbor is
anything but decoration. `ha-readiness.sh` checks the three that matter
and exits non-zero while any of them is still inside.

## The four numbers

Get these before choosing the platform. They decide more than it does.

| Number | Decides |
|---|---|
| pulls per day, peak per minute | replicas, redirect setting |
| total bytes, growth per month | the storage backend |
| recovery time committed | whether HA is required at all |
| clusters that pull | whether one Harbor is enough |

If nobody can supply the third, there is no availability requirement
yet, and the virtual machine is correct until there is.

## architecture-decision.md

A template to copy into your own architecture document. Its value is the
last paragraph, which names what would change the decision and how much
of the expensive half is already done.
