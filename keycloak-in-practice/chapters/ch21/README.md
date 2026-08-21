# Chapter 21 — Clustering, HA, and Sizing

Expects: Chapter 15's cluster.

```bash
kubectl patch keycloak meridian --type=merge \
  -p '{"spec":{"instances":3}}'
kubectl get pods -l app=keycloak -w
```

The operator handles discovery. Watch the logs for the cluster view
forming before concluding anything about sessions.

## Sizing, in one line

Size for **logins per second**, not requests per second. Token
verification happens in the consumer, offline, against keys it already
holds — those requests never reach Keycloak at all.

```bash
SECRET=<the meridian-batch secret> ./chapters/ch21/loadtest.sh 50
```

## What survives a restart

Since Keycloak 26, user sessions are written to the database rather than
living only in memory. A rolling restart no longer logs everybody out —
which was the single most common operational complaint about earlier
versions, and is worth verifying on your pinned version rather than
trusting a blog post.

In-progress logins are a different cache and a different answer. The
chapter measures both.
