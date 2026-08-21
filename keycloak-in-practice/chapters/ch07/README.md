# Chapter 7 — Users, Groups, and Roles

Expects: Chapter 6 finished; `meridian-api` exists.

The rule this chapter builds:

> Users get groups. Groups get roles. Roles are not assigned to users
> directly.

Step 6 breaks it on purpose so that the cost is visible, and then undoes
it. If you stopped reading in the middle, check:

```bash
source chapters/kcadm.sh
kcadm get users -r meridian -q username=anna --fields id
kcadm get users/<id>/role-mappings/realm --fields name
```

`contractor` should not be there.

## Two things that surprise people

Roles inherit downward through nested groups; membership does not
aggregate upward. `groups/<id>/members` lists direct members only.

Group membership is not in the token. It takes a mapper, which is
Chapter 8, and Chapter 16 is where it stops being optional.
