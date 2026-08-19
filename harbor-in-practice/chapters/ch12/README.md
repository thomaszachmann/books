# Chapter 12 — Quotas and Storage Backends

**Starting state:** Chapter 11 finished.

```bash
./quota-report.sh 80        # non-zero if any project is above 80%
```

## One resource: storage, in bytes

There is no artifact or tag count limit. Requests for "no more than 50
tags" are answered by retention — Chapter 11 — not by a quota.

`-1` means unlimited, and unlimited is negative, so any comparison
against a threshold has to filter it out first. Same trap as robot
expiry in Chapter 6.

## The condition that explains everything

> A blob upload consumes quota **only if that blob is not already
> associated with this project.**

| Situation | Charged |
|---|---|
| same layer, second image, same project | no |
| same layer, different project | **yes, again** |

So a project's usage is far below the sum of its artifacts' sizes, and
the sum across projects is **above** the disk. Neither number is wrong.
Plan capacity on the disk; set limits on the projects.

## The storage decision is made once

Six drivers: `filesystem` (default), `s3`, `azure`, `gcs`, `swift`,
`oss`. Changing the driver moves no data — Harbor comes up healthy,
empty and unable to serve anything that already exists. Treat it as a
migration, not a setting.

`redirect.disable` is the setting to know: by default a client pulling
from object storage is redirected to the store and fetches the bytes
itself. Disable it when clients cannot reach the store, and accept that
Harbor becomes the data plane for every layer of every pull.
