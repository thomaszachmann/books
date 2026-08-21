# Chapter 15 — Keycloak on Kubernetes

Expects: a cluster. `kind` users start with the config in this
repository; minikube users see `k8s/minikube/README.md`.

```bash
kind create cluster --config k8s/kind/cluster.yaml
kubectl apply -f k8s/base/postgres.yaml
kubectl create secret tls keycloak-tls \
  --cert=pki/sso.crt --key=pki/sso.key
kubectl apply -f k8s/base/keycloak.yaml
```

The certificate is the one from Chapter 2. Nothing new is issued, which
is the point: the name and the trust were decided once.

## KeycloakRealmImport is an import

It runs once and creates what is not there. It does **not** reconcile:
change the realm in the console and re-apply the manifest, and nothing
is corrected. Treating it as GitOps is the most common mistake with the
operator, and the failure is silent — the resource reports success.

Chapter 24 uses Terraform for the declarative path and says why.

## Undo

```bash
kubectl delete -f k8s/base/keycloak.yaml
kind delete cluster --name meridian
```
