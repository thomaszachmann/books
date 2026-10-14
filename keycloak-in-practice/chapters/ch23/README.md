# Chapter 23 — Upgrades and Version Skew

Expects: a dump from Chapter 22 (Steps 1 to 4, the compose Keycloak's
data), and Chapter 15's cluster and its Keycloak (Steps 5 and 6, the
operator procedure).

```bash
./chapters/ch23/rehearse.sh backup/db-<stamp>.dump 26.5.2
```

## The rule

**The schema migration is one-way.** A newer Keycloak started against
the database migrates it, and there is no downgrade. So the rollback
plan is not "start the old version again" — it is a database restore,
which means the rollback is as long as Chapter 22's restore and needs
the same credential from Chapter 20.

Rehearse against a copy. The number you want is the migration window,
and it is a property of your data, not of the release notes.

## Order, when the operator is involved

1. the two CRDs
2. the operator — which IS the Keycloak upgrade: the resource names no
   image, so the operator runs the stock image of its own version and
   rolls the StatefulSet by itself

Backwards produces a controller that cannot read fields it expects, and
the error names a schema rather than a version.

Do not set `spec.image` to the stock image on its own. A named image is
started with `--optimized`, and an image nobody ran `kc.sh build` on
crash-loops: "The '--optimized' flag was used for first ever server
start". Pin it with `startOptimized: false` beside it, and delete the
stuck pod by hand if it already crash-loops.

## Step 6, the checks

```bash
source chapters/kcadm.sh
curl -sS "$ISS_K8S/.well-known/openid-configuration" | jq -r .issuer
kubectl wait --for=condition=Ready keycloak/meridian --timeout=600s
curl -sS "$ISS_K8S/protocol/openid-connect/certs" \
  | jq -r '.keys[] | select(.use=="sig") | .kid' | diff - kid-before
```

`kid-before` is written at the start of Step 5.
