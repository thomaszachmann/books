# Chapter 11 — Immutability, Retention, and Garbage Collection

**Starting state:** Chapter 10 finished, signature policies off.

**What this chapter builds:** an immutability rule, a retention policy,
and the garbage collection that is the only one of the three that
changes the disk.

```bash
./retention-preview.sh <policy-id>   # ALWAYS before running it for real
./gc-status.sh                       # what the last collection did
```

## Three mechanisms, one of which frees space

```
delete a tag       -> a pointer goes away
delete an artifact -> the manifest goes, blobs are orphaned
garbage collection -> the blobs go, and the disk moves
```

Stopping after line one or two is every "we deleted things and the disk
is still full" ticket.

## Retention rules only say what to KEEP

All seven templates have the action `retain`:

| Template | Keeps |
|---|---|
| `latestPushedK` | the K most recently pushed |
| `latestPulledN` | the N most recently pulled |
| `latestActiveK` | the K most recently pushed or pulled |
| `lastXDays` | anything pushed in the last X days |
| `nDaysSinceLastPush` | anything pushed within N days |
| `nDaysSinceLastPull` | anything pulled within N days |
| `always` | everything the selector matches |

There is no delete action. **Whatever no rule retains is removed** —
including the release from March that is running in production and has
not been pushed since. Read every policy that way round.

## Garbage collection defaults

| Parameter | Default |
|---|---|
| `delete_untagged` | **true** |
| `time_window` | **2 hours** |
| `workers` | 1 |
| `dry_run` | false |

`time_window` is a safety margin, not a tuning option: a blob uploaded
four minutes ago may belong to a push whose manifest is not written yet.

`delete_untagged` does not destroy multi-architecture images. Harbor
refuses to delete an artifact another artifact references —
*the deleting artifact is referenced by others* — and the collection
logs the refusal and continues. `gc-status.sh` counts those so they
read as protection rather than as failure.
