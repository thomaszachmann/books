# Chapter 14 — Proxy Cache

**Starting state:** Chapter 13 finished, with a registry endpoint
registered.

```bash
HARBOR_PASS=... ./cache-health.sh    # non-zero if any upstream is unhealthy
```

## A project is a proxy cache, or it is not

```
registry_id >= 1   ->  proxy cache for that registry
registry_id unset  ->  an ordinary project
```

There is no toggle, and no conversion in either direction. Create it as
one. Push is refused:

```
denied: can not push artifact to a proxy project: dockerhub
```

## The assumption worth breaking

A proxy cache does **not** degrade into serving what it already holds.
Harbor checks the upstream registry's health before proxying and
refuses when it is not healthy — so an upstream outage stops pulls of
cached images too.

`cache-health.sh` reports exactly that state, per proxy project, because
it is the thing people discover during an outage.

The mitigation has to exist beforehand: replicate the base images that
must always work into an **ordinary** project and pin builds there.

## The library/ rewrite has two conditions

| Condition | |
|---|---|
| upstream type is `docker-hub` | otherwise the path is literal |
| the name after the project has no slash | otherwise the path is literal |

So `dockerhub/alpine` reaches `library/alpine`, and
`dockerhub/bitnami/nginx` is taken as written. Both are correct; the
rule is the slash. The API stores the upstream name, so retention and
quota tooling sees `library/alpine`.

## It grows, and nothing cleans it

Use `nDaysSinceLastPull` rather than a count rule — a cache should keep
what is still in use and drop what one build asked for in March — then
garbage collection on a schedule. Chapter 11.

`proxy_speed_kb` limits Harbor to upstream, not client to Harbor.
