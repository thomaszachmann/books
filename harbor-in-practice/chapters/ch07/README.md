# Chapter 07 — Authentication: Database, LDAP, and OIDC

**Starting state:** Chapters 1 to 6 finished — which means your lab has
users, which means it cannot change `auth_mode`. That is the first thing
the chapter demonstrates.

**Run this before anything else, on any installation:**

```bash
./check-auth-mode.sh
```

It exits non-zero when the mode is already frozen, and prints the users
that would have to go first together with the command that exports their
project memberships before you delete them.

**Then:**

```bash
# after removing the users
OIDC_ENDPOINT=https://harbor.meridian.test:5556 \
OIDC_CLIENT_SECRET=dex-lab-secret \
  ./set-oidc.sh
```

## The one thing to take away

Harbor permits a change of `auth_mode` only while no user other than the
built-in `admin` exists:

```
the auth mode cannot be modified as new users have been inserted
into database
```

So connecting Harbor to a directory is a day-one decision. The usual
sequence — bring it up, create a few accounts so people can start, wire
up single sign-on next sprint — produces an installation that cannot be
wired up at all without deleting every user and their memberships.

## config-keys.txt

Every key defined for `PUT /configurations`, extracted from the pinned
swagger. The CI checks `set-oidc.sh` against it. A misspelled key is the
failure worth guarding against: the request can return `200` while the
setting you meant is never applied.
