# Where Harbor runs — architecture decision

Copy this into your own architecture document and fill it in. The value
is in the last paragraph: it names the decision, the reason, the thing
that would change it, and how much of the expensive half is already
done.

---

## Decision

Harbor runs on **<a dedicated virtual machine | a separate platform
cluster>**, outside the Kubernetes clusters it serves, with PostgreSQL
and object storage provided by **<...>**.

## Why not in the workload cluster

The registry supplies the images required to rebuild a cluster. A
registry inside that cluster is unavailable at precisely the moment it
is needed:

```
cluster down -> need images to bring it up -> images are in a
registry -> the registry was in the cluster
```

No configuration escapes this. Either the registry is elsewhere, or
recovery depends on a copy elsewhere — in which case the registry was
not the authoritative source.

## Availability

High availability is **<implemented | not implemented>**, because
**<a recovery-time commitment of ... exists | no recovery-time
commitment exists for this service>**.

If a commitment is agreed, the migration path is a platform cluster with
the Harbor Helm chart. Three things are mandatory alongside it and
**<are already in place | are not yet in place>**:

| | Status |
|---|---|
| external PostgreSQL | |
| external Redis | |
| object storage | |

Run `./ha-readiness.sh` to fill that table from the installation rather
than from memory.

## The four numbers this decision rests on

| Number | Value | Decides |
|---|---|---|
| Pulls per day, peak per minute | | replicas, redirect setting |
| Total bytes, growth per month | | storage backend |
| Recovery time committed | | whether HA is required at all |
| Clusters that pull | | whether one Harbor is enough |

## What would change this decision

- a stated recovery-time commitment where there is none today
- a second site or regulator requiring a copy in another failure domain
- growth that makes the current storage backend the binding constraint
- the registry entering the admission path for every pod, which changes
  what its availability means
