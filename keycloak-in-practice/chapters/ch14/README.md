# Chapter 14 — Identity Brokering

Expects: Chapter 6 finished. The directory from Chapters 12 and 13 is
not needed and can stay down — which is itself the chapter's argument.

```bash
./chapters/ch14/upstream.sh
```

## The one that bites

The brokering endpoint is
`/realms/<realm>/broker/<alias>/endpoint`, and the **alias** is part of
it. Decide the alias, register that exact URI at the upstream provider,
then create the identity provider. In the other order the first login
fails at the far end, in somebody else's log.

## Undo

```bash
source chapters/kcadm.sh
kcadm delete identity-provider/instances/corp -r meridian
kcadm delete realms/meridian-corp
```
