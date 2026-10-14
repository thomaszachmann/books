# minikube

The differences from kind, which are the reason this book uses both.
The labs were run on kind; this is what changes on minikube. The
minikube commands were not run for this edition of the book - treat
them as a map, not as tested output.

```bash
minikube start -p meridian --cpus=4 --memory=8g \
  --extra-config=apiserver.authentication-config=/etc/kubernetes/authn/config.yaml \
  --mount --mount-string="$PWD/k8s/kind/authn:/etc/kubernetes/authn"
minikube -p meridian addons enable ingress
```

| Problem | kind | minikube |
|---|---|---|
| Ingress controller | manual, plus `extraPortMappings` and a host port of 8443 | `addons enable ingress`, on the node's 443 |
| Reaching it by name | host port 8443 | `minikube tunnel`, or the node IP in hosts |
| The compose names inside the cluster | `make kind-link` (Docker network `kind`) | not on the same Docker network: point `sso.meridian.test` and `dc.meridian.test` at the host in CoreDNS |
| The API server trusting a private CA | `certificateAuthority` in the config | the same |

Because the minikube ingress listens on 443, not 8443, change the
hostname in `k8s/base/keycloak.yaml` to
`https://sso-k8s.meridian.test` and use that URL wherever the book
writes `:8443`.
