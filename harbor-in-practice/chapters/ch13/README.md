# Chapter 13 — Replication

**Starting state:** Chapter 12 finished.

```bash
HARBOR_PASS=... ./replication-gap.sh platform mirror
```

## One field decides the direction

```
src_registry set   ->  PULL   this Harbor fetches from there
dest_registry set  ->  PUSH   this Harbor sends to there
```

"This Harbor" is always one end. There is no policy between two remote
registries, so a policy lives on whichever Harbor can open the
connection — which in an air-gapped topology is the inside one,
pulling.

## Replication copies artifacts, and only artifacts

| Thing | Replicated |
|---|---|
| artifacts, their tags, index children | yes |
| scan results | no |
| project members, robot accounts | no |
| retention, immutability, quota | no |
| signature | **only if a filter matched it** |

`replication-gap.sh` compares the two ends on everything in that list
that is not an artifact, because "the image is there" gets mistaken for
"the second site is equivalent".

## Where signatures are lost

A cosign signature is an artifact in the same repository whose tag is
derived from the digest it signs. A policy filtered to `release-*` will
not match it. Harbor's transfer understands indexes and copies their
children; it has no notion of accessories, so nothing pulls a signature
along because it belongs to something.

Prove it at the destination rather than counting:

```bash
cosign verify --key cosign.pub <destination reference>
```

`no matching signatures` is a stronger answer than any count.
