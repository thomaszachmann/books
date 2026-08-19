# Chapter 15 — Harbor on Kubernetes

**Starting state:** Chapter 14 finished. `certs/` holds the CA and
server certificate from Chapter 2.

```bash
make kind-up                        # or: make mk-up  + minikube tunnel
# install an ingress controller - the KIND-specific manifest
./install-chart.sh
./node-trust.sh kind harbor-lab     # or: minikube harbor-lab
```

## Three things must be true before a pod can pull

```
1. the name resolves     on the NODE, not on your laptop
2. the CA is trusted     by the node's container runtime
3. a credential exists   in the pod's namespace   <- Chapter 16
```

Making Harbor work from your laptop proves nothing about the cluster.
`docker pull` uses your daemon and your trust store; a pod's pull uses
the node's runtime and the node's trust store. The failure is
`ImagePullBackOff` with `x509: certificate signed by unknown authority`,
several layers away from its cause.

`node-trust.sh` does the second one for both distributions.

## Three chart defaults this repo overrides

| Default | Why |
|---|---|
| `certSource: auto` | generates a certificate nothing trusts |
| `secretKey: "not-a-secure-key"` | shipped value, must be exactly 16 chars |
| registry PVC `5Gi` | not a registry-sized volume |

## The chart version has no `v`

`Chart.yaml` reads `version: 1.19.2`, `appVersion: 2.15.2`. The `v` in
`VERSIONS.md` is the Git tag convention, and `helm --version v1.19.2`
finds nothing. `install-chart.sh` strips it:

```sh
CHART_VERSION="${HARBOR_CHART_VERSION#v}"
```

## kind and minikube are nothing alike here

| | kind | minikube |
|---|---|---|
| ingress controller | the KIND-specific manifest | `addons enable ingress` |
| external address | host ports, mapped at create time | `minikube tunnel` |
| node trust store | `docker cp` into the node container | `minikube cp` |

Without `minikube tunnel` running, the ingress `ADDRESS` stays empty and
nothing works. That is the most common minikube question and it is not a
Harbor question.
