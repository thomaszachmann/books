# Pinned versions

Every lab in *Harbor in Practice* runs against these versions. They are
pinned in one place so that the book, the scripts and the CI cannot drift
apart. Scripts read this file directly:

```bash
eval "$(grep -E '^[A-Z_]+=' VERSIONS.md)"
```

Anything assigned at the start of a line below is the source of truth.

```sh
HARBOR_VERSION=v2.15.2
HARBOR_CHART_VERSION=v1.19.2
TRIVY_VERSION=v0.74.0
COSIGN_VERSION=v3.1.3
KIND_VERSION=v0.32.0
MINIKUBE_VERSION=v1.38.1
HELM_VERSION=v4.2.4
ESO_CHART_VERSION=2.9.0
UBUNTU_SERIES=24.04
VM_NAME=harbor
VM_CPUS=4
VM_MEMORY=8G
VM_DISK=60G
```

## Why these

**Harbor v2.15.2**, released 2026-07-02. Pinned to a patch release rather
than a minor, because the book prints expected output and a minor release
changes it. The installer is published as
`harbor-offline-installer-v2.15.2.tgz` together with a
`.sigstore.json` bundle — Chapter 3 verifies that bundle before running
anything, which is the first thing in the book that is a security control
rather than a convenience.

**Chart v1.19.2** is the Helm chart, versioned separately from Harbor
itself. Confusing the two is the most common Harbor upgrade mistake, and
Chapter 23 is about not making it.

Note the form. The chart's own `Chart.yaml` reads `version: 1.19.2` and
`appVersion: 2.15.2` — no `v` on either. The `v` here is the Git tag
convention, and `helm --version v1.19.2` finds nothing. Scripts that
pass this value to Helm must strip it:

```sh
helm install harbor harbor/harbor --version "${HARBOR_CHART_VERSION#v}"
```

**Helm v4.x.** Note the major version. Chapter 15 says where the commands
differ from Helm 3, because most Harbor material online predates it.

**Two Kubernetes distributions**, kind and minikube, as in Book One. They
disagree about ingress, load balancers and image loading, and Harbor is
where that disagreement stops being academic.

**Vault** is not pinned here. Part VI brings it up with `make vault-up`
and pins it then; nothing in Parts I to V needs it.

## When these go stale

The CI runs the labs weekly against **both** the versions above and the
current latest. A failure against latest opens an issue; it does not turn
this repository red, because the book is written against the pin.

Differences found after publication are recorded in `ERRATA.md`.
