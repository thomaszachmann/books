# Chapter 20 — The Cold Start

Expects: Chapters 18 and 19.

**Run this before the lab, not after:**

```bash
./chapters/ch20/breakglass.sh create
```

The chapter then produces a deadlock deliberately. The script above is
what ends it, and creating it afterwards is not possible — which is the
lesson, and the reason it is in the README rather than in step seven.

## The distinction the chapter is built on

| Edge | Who uses it | Needs Keycloak? |
|---|---|---|
| Keycloak reads its DB credential from Vault | a process, at boot | no |
| An operator logs in to Vault to fix Keycloak | a human | yes |

The first edge is not a cycle. The second is. Most fear about this
arrangement is aimed at the first, and most outages come from the
second.
