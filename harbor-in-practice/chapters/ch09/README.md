# Chapter 09 — Scanning with Trivy

**Starting state:** Chapter 8 finished. `platform` has `auto_scan` on.

**What this chapter builds:** a policy that refuses a pull, and the order
of operations that stops it causing an outage.

```bash
./severity.sh                      # the threshold table
./unscanned.sh platform            # non-zero if anything would be refused
./enable-prevent.sh platform high  # refuses to enable until that list is empty
```

## prevent_vul does not mean "block vulnerable images"

It means **block anything I cannot vouch for**, and there are three ways
to fail it:

| Condition | Result |
|---|---|
| no scan report, and the artifact is scannable | refused |
| scan status is not `Success` — running, failed | refused |
| highest finding at or above the threshold | refused |

The first is the one that takes a cluster down. A current, clean image
nobody has scanned is refused, and the error does not mention
vulnerabilities:

```
current image without vulnerability scanning cannot be pulled due to
configured policy in 'Prevent images with vulnerability severity of
"high" or higher from running.'
```

`enable-prevent.sh` exists to make that impossible: it will not set the
policy while `unscanned.sh` reports anything.

## The threshold is inclusive

`severity.sh` encodes the comparison Harbor makes — `>=`, so `high`
blocks `high`. Source it rather than writing your own:

```bash
. ./chapters/ch09/severity.sh
would_block critical high && echo "refused"
```

## Cron has six fields

Harbor parses `Second | Minute | Hour | Dom | Month | Dow`, and the
seconds field must be literally `0` — anything else is rejected with
*the 1st field (indicating Seconds of time) of the cron setting must be
0*. A five-field expression copied from crontab means something else.
