# Chapter 19 — Robot Accounts in Vault

**Starting state:** Chapter 18 finished. ESO installed, a store points
at Vault.

```bash
./dockerconfig.sh build 'robot$platform+cluster-pull' "$SECRET"
./dockerconfig.sh check apps
```

## Fourteen copies become one write

Put the robot in Vault once; a `ClusterExternalSecret` materialises it
into every labelled namespace. A new namespace opts in by carrying the
label, and rotation is one write instead of fourteen edits.

## Two fields that are not what they look like

| Field | Status |
|---|---|
| `namespaceSelectors` | list of label selectors, ORed. **Use this** |
| `namespaceSelector` | singular. **Deprecated** |
| `namespaces` | list of names. **Deprecated** |

Both deprecated forms still work and neither warns. They are in most
examples online, which is how they reach new manifests.

And the outer field is spelt differently from the inner one:

```
refreshTime:      on ClusterExternalSecret
refreshInterval:  on ExternalSecret
```

An unknown field is dropped silently, so writing `refreshInterval` at
the outer level means the default is in effect and nothing says so.

## Emit the auth field

containerd reads `auth`; Docker's client reads `username`/`password` and
builds `auth` itself. Emit only the latter and a laptop keeps working
while the cluster stops — the worst split, because the person debugging
it can pull. `dockerconfig.sh check` fails when `auth` is missing or
does not match.

## What this does not fix

- the robot still expires — Chapter 6, ninety days
- revocation still is not immediate: up to 30 minutes of bearer token,
  plus the refresh interval, plus a running pod that never re-reads
- every labelled namespace can pull everything that robot can. The
  fan-out distributes a credential; it does not authorise anything
