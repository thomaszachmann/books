# Chapter 16 — Authenticating kubectl

Expects: Chapter 15's cluster, still running; the `groups` client scope
from Chapter 8; Anna in the Active Directory group `logistics`
(Chapter 12). For Step 3, the `oidc-login` kubectl plugin
(`kubectl krew install oidc-login`, Appendix A).

**Before you start, make your break-glass kubeconfig and test it.**

```bash
kind get kubeconfig --name meridian > ~/.kube/meridian-breakglass
KUBECONFIG=~/.kube/meridian-breakglass kubectl auth whoami
```

That file authenticates with a client certificate signed by the
cluster's own CA. It does not involve Keycloak. The cluster is never
recreated in this chapter, so the file stays valid to the end of the
book.

## Order

```bash
source chapters/kcadm.sh
# Step 1: client `kubernetes` in the compose Keycloak, groups as default
./chapters/ch16/authn-config.sh "$ISS"       # Step 2, reloads in ~10 s
kubectl apply -f k8s/base/rbac.yaml         # Step 5
```

`authn-config.sh` writes `k8s/kind/authn/config.yaml`, which the node
mounts. The API server reloads it by itself and logs
`"reloaded authentication config"`; the Meridian root travels inline as
`certificateAuthority`, so the node's trust store is never touched and
nothing is restarted.

## Break it and back (Steps 6 to 9)

```bash
./chapters/ch16/authn-config.sh "$ISS_K8S"   # trust only the cluster's Keycloak
kubectl delete keycloak meridian            # the outage
KUBECONFIG=~/.kube/meridian-breakglass kubectl apply -f k8s/base/keycloak.yaml
./chapters/ch16/authn-config.sh "$ISS"       # back to the compose Keycloak
```

Finish with the compose issuer and the cluster's Keycloak running:
Chapters 17 to 20 use the first, 21 and 23 the second.

## The three strings that must agree

| Where | What |
|---|---|
| `k8s/kind/authn/config.yaml` | `issuer.url`, reachable from the API server |
| The token | `aud` must contain `kubernetes`, `typ` must be `ID` |
| `rbac.yaml` | the group name, including the `oidc:` prefix |
