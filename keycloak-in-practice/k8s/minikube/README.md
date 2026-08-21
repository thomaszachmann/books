# minikube

The differences from kind, which are the reason this book uses both.

```bash
minikube start -p meridian --cpus=4 --memory=8g
minikube -p meridian addons enable ingress
```

| Problem | kind | minikube |
|---|---|---|
| Ingress controller | manual, plus `extraPortMappings` | `addons enable ingress` |
| Reaching it by name | host port mapping | `minikube tunnel`, or the node IP in hosts |
| Trusting a private CA on the node | `docker cp` into the node | `minikube ssh`, then `update-ca-certificates` |

The third row is the one that matters in Chapter 16, where the API
server — not your browser — has to trust the certificate.

With minikube, point `sso.meridian.test` at the value of
`minikube -p meridian ip` rather than at `127.0.0.1`.
