# Chapter 01 — Why a Private Registry

**Starting state:** Docker installed. Nothing else.

**What this chapter builds:** nothing permanent. It runs the reference
registry in one container to show what a registry is, and then walks the
four questions to show what this one cannot answer.

Harbor is not installed until Chapter 3. That is deliberate.

```bash
./plain-registry.sh     # steps 2 to 5
./move-tag.sh           # step 6, the point of the chapter
docker stop plain-registry
```

Nothing here is idempotent by accident: `plain-registry.sh` starts the
container with `--rm`, so stopping it removes everything you pushed.
That is step 9, and it is the fourth failure arriving uninvited.
