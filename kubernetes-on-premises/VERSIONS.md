# Pinned versions

Every lab in *Kubernetes On-Premises* runs against these versions. They are
pinned in one place so that the book, the scripts and the CI cannot drift
apart. Scripts read this file directly:

```bash
eval "$(grep -E '^[A-Z_]+=' VERSIONS.md)"
```

Anything assigned at the start of a line below is the source of truth.
`publishing/check-versions.py` in the book project checks the printed
numbers against it.

```sh
# --- substrate ---------------------------------------------------
ROCKY_VERSION=10.2
ROCKY_MAJOR=10
SSG_PRODUCT=rl10
SSG_CONTENT_VERSION=0.1.81

# --- cluster -----------------------------------------------------
RKE2_VERSION=v1.36.3+rke2r1
K8S_VERSION=1.36.4
CILIUM_VERSION=1.20.1
GATEWAY_API_VERSION=1.6.1
KUBE_VIP_VERSION=1.2.3
METALLB_CHART_VERSION=0.16.1
LONGHORN_VERSION=1.12.1

# --- controls ----------------------------------------------------
CERT_MANAGER_VERSION=1.21.1
KYVERNO_VERSION=1.19.0
KUBE_BENCH_VERSION=0.16.0
TRIVY_VERSION=0.74.0
COSIGN_VERSION=3.1.3
SYFT_VERSION=1.51.0

# --- platform ----------------------------------------------------
PROMETHEUS_VERSION=3.14.0
GRAFANA_VERSION=13.2.0
VELERO_VERSION=1.18.2
FORGEJO_VERSION=16.0.3
POSTGRES_VERSION=18.6

# --- from the earlier books, for the bootstrap -------------------
HARBOR_VERSION=2.15.2
KEYCLOAK_VERSION=26.7.2
OPENBAO_VERSION=2.6.2

# --- comparison chapter only -------------------------------------
TALOS_VERSION=1.13.9
```

## Notes

**RKE2 trails upstream Kubernetes by a patch release or two.** At the time
of pinning, upstream was 1.36.4 and RKE2 shipped 1.36.3. That lag is normal
and is one of the things Chapter 13 weighs when it compares distributions.

**`SSG_PRODUCT` is `rl10`, and that was measured rather than assumed.**
Upstream ComplianceAsCode ships no `rl10` product at all, which suggested
evaluating a Rocky node against the `rhel10` datastream. On a running
Rocky Linux 10.2 host that is wrong: the package is patched downstream and
installs **both** `ssg-rhel10-ds.xml` and `ssg-rl10-ds.xml`, with identical
profile lists — 1061 rules, `bsi` and `stig` included.

Point `oscap` at the Red Hat one and all 211 rules of the `bsi` profile
come back `notapplicable`, because it declares
`cpe:/o:redhat:enterprise_linux:10` and the host is not that. Rocky's
declares both CPEs. Chapter 7 measures this; Chapter 4 warns about it.

AlmaLinux is **not verified**. Upstream its `almalinux9` product lacks the
BSI and STIG profiles entirely, and whether its shipped package rebrands
the Red Hat content the way Rocky's does has not been tested for this
book. Check it on your own system rather than trusting either assumption.

**No `ingress-nginx` pin, deliberately.** `kubernetes/ingress-nginx` was
archived in March 2026. The book uses the Gateway API with Cilium instead;
see Chapter 32. The controller still appears in Chapter 1, in a
deliberately outdated manifest bundle, and is not pinned there.

**Velero is `velero-io/velero`**, not the old `vmware-tanzu` path.

Pinned on 2026-08-21.
