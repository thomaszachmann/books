# Chapter 11 — Authorization Services, and When Not to Use Them

Expects: Chapter 8 finished; `meridian-api` exists.

Enabling authorization services on a client creates a **Default
Resource** and a **Default Permission** that together allow everything
to any authenticated user. That is convenient for a first look and it is
the reason a first evaluation always says yes.

Delete them before concluding anything:

```bash
source chapters/kcadm.sh
API=$(kcadm get clients -r meridian -q clientId=meridian-api \
        --fields id --format csv --noquotes)
kcadm get clients/$API/authz/resource-server/policy --fields name
```

## Undo

This chapter is additive and reversible. To put the client back:

```bash
kcadm update clients/$API -r meridian \
  -s authorizationServicesEnabled=false
```

That discards the whole authorization configuration for the client —
resources, policies and permissions together. There is no partial undo,
which is worth knowing before you build a policy model here rather than
in your own service.
