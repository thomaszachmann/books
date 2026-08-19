# Chapter 08 — Artifacts, Tags, and OCI

**Starting state:** Chapter 7 finished, on database authentication.

**What this chapter builds:** nothing permanent. It is about what Harbor
actually stores, which is artifacts and not images.

```bash
# a single-platform push, the way it happens by accident
docker push harbor.meridian.test/platform/single:1.0

# a whole index, copied rather than built
docker buildx imagetools create \
  --tag harbor.meridian.test/platform/multi:1.0 alpine:3.20

./index-children.sh platform multi 1.0
./untagged.sh platform
```

## The number that surprises people

`alpine:3.20` is an index with **sixteen** children for **eight**
platforms. The other eight are attestation manifests — provenance and
SBOM documents attached by the build, with
`platform.architecture: "unknown"`. They are real artifacts and they
occupy real space.

`index-children.sh` separates the two counts, because a report that
gives one number is answering a question nobody asked.

## Why untagged.sh does not just list untagged artifacts

Two groups land in that list and only one is a question:

| Group | What it is |
|---|---|
| child | a platform or attestation manifest of an index — supposed to be untagged |
| ORPHAN | an artifact that lost its tags — this is the one to look at |

A cleanup that treats them as one group deletes the platform-specific
manifests out from under working images. Both scripts read a fixture
through `INDEX_JSON` / `ARTIFACTS_JSON`, which is how the CI tests them
without a Harbor.
