# Chapter 21 — Clustering, HA, and Sizing

Expects: Chapter 15's cluster and its Keycloak (`sso-k8s.meridian.test:8443`),
running. Everything here happens to that Keycloak; the compose one stays
a single instance.

```bash
source chapters/kcadm.sh
kubectl patch keycloak meridian --type=merge \
  -p '{"spec":{"instances":3}}'
kubectl get pods -l app=keycloak -w          # meridian-0, -1, -2
kubectl logs meridian-2 | grep ISPN000094 | tail -1   # view of (3)
```

The operator handles discovery (`jdbc-ping`, through the database).
Watch the view form before concluding anything about sessions.

## Sizing, in one line

Size for **logins per second**, not requests per second. Token
verification happens in the consumer, offline, against keys it already
holds — those requests never reach Keycloak at all.

```bash
CID=$(kcadm_k8s get clients -r meridian -q clientId=meridian-batch \
  --fields id --format csv --noquotes)
export SECRET=$(kcadm_k8s get clients/$CID/client-secret -r meridian | jq -r .value)
ISS=$ISS_K8S ./chapters/ch21/loadtest.sh 50
```

kind has no metrics API, so `kubectl top` shows nothing. The chapter
reads each pod's CPU counter from `/sys/fs/cgroup/cpu.stat` before and
after the loop instead.

## What survives a restart

Since Keycloak 26, user sessions are written to the database rather than
living only in memory — in `offline_user_session`, with
`offline_flag = '0'` for ordinary ones. A rolling restart no longer logs
everybody out. Verified on the pinned version: Anna's session id
survives `kubectl delete pod meridian-1` and
`kubectl rollout restart statefulset meridian`.

In-progress logins are a different cache and a different answer. The
chapter measures both.

Finish with `instances` back at 1 if your machine is small; Chapter 23
works with either.
