# Chapter 12 — LDAP User Federation

Expects: Chapter 2's `make ad-up` succeeded at least once.

```bash
make ad-up
./chapters/ch12/seed-ad.sh
```

Nine users, three groups. `anna` exists in **both** the directory and
the realm at this point, which is deliberate — the chapter uses the
collision to show what a federated user is and what a local one is.

## The two things that catch everyone

**Component config values are lists, not strings.** The admin API stores
a component's configuration as a map of string to *array*:

```json
{"bindDn": ["CN=Administrator,CN=Users,DC=meridian,DC=test"]}
```

Passing a bare string is accepted and then ignored, with no error.

**Keycloak is the client here.** It opens the LDAPS connection, so it
needs the root from Chapter 2 in *its* truststore — the one
`make kcadm-init` created. This is the third of the four trust stores
Chapter 2 listed, and the first time it is Keycloak doing the trusting
rather than being trusted.
