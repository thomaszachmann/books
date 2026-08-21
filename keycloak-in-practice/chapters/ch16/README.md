# Chapter 16 — Authenticating kubectl

Expects: Chapter 15's cluster, and the `groups` client scope from
Chapter 8.

**Before you start, find your break-glass kubeconfig and test it.**

```bash
kind get kubeconfig --name meridian > ~/.kube/meridian-breakglass
KUBECONFIG=~/.kube/meridian-breakglass kubectl auth whoami
```

That file authenticates with a client certificate signed by the
cluster's own CA. It does not involve Keycloak, and it is the only way
back from the second half of this chapter. A cluster whose break-glass
path has never been tested does not have one.

## Order

```bash
kind delete cluster --name meridian
kind create cluster --config k8s/kind/cluster-oidc.yaml
./chapters/ch16/trust.sh
kubectl apply -f k8s/base/rbac.yaml
```

The API server reads its trust store at start, so `trust.sh` restarts
it. Wait for the node to be ready again before concluding anything.

## The three strings that must agree

| Where | What |
|---|---|
| `authn-config.yaml` | `issuer.url`, and it must be reachable from the API server |
| The token | `aud` must contain `kubernetes` |
| `rbac.yaml` | the group name, including the `oidc:` prefix |

Any one of them wrong produces "authentication failed" or a bare
"forbidden", and neither names which.
