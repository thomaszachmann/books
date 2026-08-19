# Chapter 05 — Projects, Members, and RBAC

**Starting state:** Chapter 4 finished. `platform` exists.

**What this chapter builds:** four users, one of each interesting role,
and a walk along the boundaries between them.

```bash
./seed-members.sh                 # four users, four roles, idempotent
./probe-permissions.sh            # the status code each role gets
./roles.sh                        # the table, from the source
```

`roles.sh` is also a library. Source it rather than writing your own
comparison:

```bash
. ./chapters/ch05/roles.sh
may_push 4 && echo "maintainers push"
```

**Do not compare role IDs.** They are the order the roles were added,
not a ranking: in order of power the list runs 1, 4, 2, 3, 5. A check
like `[ "$role" -le 2 ]` meaning "may push" makes every maintainer
read-only, and nothing anywhere says so.
