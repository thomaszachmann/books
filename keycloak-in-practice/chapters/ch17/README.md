# Chapter 17 — Applications in the Cluster

Expects: Chapter 16's state — the cluster, `make kind-link` done, the
API server trusting `sso.meridian.test`. The names
`grafana.meridian.test` and `wiki.meridian.test` in your hosts file
(Chapter 15, Step 1). The directory running (`make ad-up`).

All three applications use the compose Keycloak, `sso.meridian.test`.
The browser reaches them at port 8443, through the cluster's ingress.

```bash
source chapters/kcadm.sh
./chapters/ch02/make-certs.sh grafana wiki
kubectl create secret tls grafana-tls --cert=pki/grafana.crt --key=pki/grafana.key
kubectl create secret tls wiki-tls --cert=pki/wiki.crt --key=pki/wiki.key
# Step 1: client grafana (+ groups scope), then
kubectl apply -f k8s/base/grafana.yaml
# Step 2: Harbor, Keycloak side
./chapters/ch17/harbor-client.sh
# Step 4: client wiki (+ groups scope), the proxy's secret, then
kubectl apply -f k8s/base/wiki-proxied.yaml
# On the Wire: the hole first, then
kubectl apply -f k8s/base/wiki-netpol.yaml
```

## Three shapes of application

| Shape | Example | What you configure |
|---|---|---|
| Speaks OIDC well | Grafana, ArgoCD | Issuer, client, scopes, claim-to-role |
| Speaks OIDC with a twist | Harbor | The above, plus a CLI credential |
| Does not speak it | the Chapter 1 wiki | A proxy, plus a network policy |

## Harbor, from Book Two

`harbor-client.sh` registers the client (`/c/oidc/callback`, `groups`
as a default scope) and prints the three values that Book Two's
`chapters/ch07/set-oidc.sh` (repository `harbor-in-practice`) needs.
Harbor's core must reach `sso.meridian.test` and trust the Meridian
root; a Harbor in a kind cluster on the same Docker network gets the
name from `make kind-link`. Harbor refuses to switch to OIDC while it
has local users - Book Two, Chapter 7.

## Chapter 1's three numbers

The chapter ends by disabling `dmorel` in Active Directory once and
timing what happens in Grafana, the wiki and kubectl. Enable him again
afterwards:

```bash
docker compose exec dc samba-tool user enable dmorel
```
