# Chapter 14 — Identity Brokering

Expects: Chapter 6 finished. The directory from Chapters 12 and 13 is
not needed and can stay down — which is itself the chapter's argument.
If you did Chapter 13, its Step 3 must have raised the *Identity
Provider Redirector* above *Kerberos*; otherwise `kc_idp_hint=corp`
lands on the password form.

```bash
./chapters/ch14/upstream.sh
```

## The one that bites

The brokering endpoint is
`/realms/<realm>/broker/<alias>/endpoint`, and the **alias** is part of
it. Decide the alias, register that exact URI at the upstream provider,
then create the identity provider. In the other order the first login
fails at the far end, in somebody else's log.

## And the one that surprises

Disabling a user upstream does nothing while they still have a session
in `meridian`: the Cookie execution answers before the broker is asked.
Log them out of `meridian` and the next login fails upstream with
*Account is disabled, contact your administrator.*

## State this chapter leaves

- Realm `meridian-corp`: client `keycloak-broker`, user `jonas` /
  `Upstream-2026` (enabled).
- In `meridian`: identity provider `corp` (OIDC, `syncMode=FORCE`,
  first broker login flow `first broker login`), and the shadow user
  `jonas` linked to it.
- Exercise 14.4 undone: no `auto-link` flow, no `ceo`, no `mallory`.

## Undo

```bash
source chapters/kcadm.sh
kcadm delete identity-provider/instances/corp -r meridian
kcadm delete realms/meridian-corp
```
