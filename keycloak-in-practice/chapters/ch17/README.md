# Chapter 17 — Applications in the Cluster

Expects: Chapter 16's cluster, and the `groups` client scope.

```bash
kubectl create secret generic meridian-ca --from-file=ca.crt=pki/ca.crt
kubectl apply -f k8s/base/grafana.yaml
kubectl apply -f k8s/base/wiki-proxied.yaml
```

## Three shapes of application

| Shape | Example | What you configure |
|---|---|---|
| Speaks OIDC well | Grafana, ArgoCD | Issuer, client, scopes, claim-to-role |
| Speaks OIDC with a twist | Harbor | The above, plus a CLI credential |
| Does not speak it | the Chapter 1 wiki | A proxy, plus a network policy |

The third row's network policy is not optional. Without it, any pod in
the cluster reaches the application directly and the proxy has
authenticated nobody.

## Harbor, from Book Two

If you worked through *Harbor in Practice*, the registry you built is
the best thing to point at this realm. The settings and the one
consequence that surprises people are in the chapter.
