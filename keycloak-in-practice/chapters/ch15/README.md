# Chapter 15 — Keycloak on Kubernetes

Expects: the state after Chapter 14 — the compose stack running
(`db`, `keycloak`, `dc`, `client`), the realm `meridian` reading Active
Directory. `kind` and `kubectl` installed (`make check`; versions in
`k8s/VERSIONS.md`). The three Part IV names in your hosts file
(Chapter 15, Step 1).

## Two Keycloaks from here on

| Name | What | Used by |
|---|---|---|
| `https://sso.meridian.test` | the compose Keycloak from Part I–III | everything: kubectl (Ch. 16), the apps (Ch. 17), Vault (Ch. 18–20), backup, Terraform |
| `https://sso-k8s.meridian.test:8443` | the operator's Keycloak in the cluster | Ch. 15, the break-it of Ch. 16, Ch. 21 and 23 |

`kcadm` (from `chapters/kcadm.sh`) talks to the first. `kcadm_k8s`
(same file) talks to the second; `$ISS` and `$ISS_K8S` are their
issuers.

## Order

```bash
./chapters/ch16/authn-config.sh          # empty authentication config
kind create cluster --config k8s/kind/cluster.yaml
kubectl apply -k k8s/ingress-nginx
kubectl wait -n ingress-nginx --for=condition=ready pod \
  -l app.kubernetes.io/component=controller --timeout=240s
make kind-link

kubectl apply -f k8s/base/postgres.yaml
./chapters/ch02/make-certs.sh sso-k8s
kubectl create secret tls keycloak-tls --cert=pki/sso-k8s.crt --key=pki/sso-k8s.key
kubectl create secret generic meridian-ca --from-file=ca.crt=pki/ca.crt
kubectl create secret generic keycloak-admin --from-literal=username=admin \
  --from-literal=password="$(openssl rand -base64 18)"

V=$(grep '^KEYCLOAK_VERSION=' VERSIONS.md | cut -d= -f2)
B=https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/$V/kubernetes
kubectl apply -f $B/keycloaks.k8s.keycloak.org-v1.yml
kubectl apply -f $B/keycloakrealmimports.k8s.keycloak.org-v1.yml
kubectl apply -f $B/kubernetes.yml
kubectl apply -f k8s/base/keycloak.yaml
kubectl wait --for=condition=Ready keycloak/meridian --timeout=300s

./chapters/ch15/export-realm.sh
kubectl apply -f k8s/local/meridian-realm-import.json
kubectl wait --for=condition=Done keycloakrealmimport/meridian --timeout=300s
```

## How the names work

| From | `sso.meridian.test` | `dc.meridian.test` | `sso-k8s.meridian.test` |
|---|---|---|---|
| your laptop | hosts file → 127.0.0.1:443 (compose) | hosts file | hosts file → 127.0.0.1:8443 → node:8443 → ingress |
| pods | CoreDNS → Docker DNS → compose container on `kind` | same | CoreDNS rewrite → node → :8443 → ingress |
| the node / API server | Docker DNS → compose container | same | node `/etc/hosts` → node:8443 → ingress |

`make kind-link` sets up the middle and right columns and is
idempotent. `make up` and `make ad-up` run it again whenever the
cluster exists, because a recreated container leaves the `kind`
network. Run it yourself after restarting the node container.

## The export is a key

`k8s/local/meridian-realm-import.json` holds client secrets, the
directory bind password and the realm's private signing keys. It is in
`.gitignore` and written with mode 600. Kerberos is switched off in the
copy: the keytab and the service principal belong to
`sso.meridian.test`.

## KeycloakRealmImport is an import

It runs once and creates what is not there. It does **not** reconcile,
and deleting and re-applying it does not either: the job logs
`Realm 'meridian' already exists. Import skipped`.

## Step 7 leaves a pod behind

After the hostname break, `kubectl apply -f k8s/base/keycloak.yaml`
fixes the StatefulSet but not the crash-looping `meridian-0`: a
StatefulSet does not replace a pod that never became ready (Kubernetes
calls it a forced rollback). `kubectl delete pod meridian-0`.

## Undo

The cluster is meant to stay until the end of the book (Chapters 16,
17, 21 and 23 use it). If you must:

```bash
kind delete cluster --name meridian
rm -rf k8s/local k8s/kind/authn
```
