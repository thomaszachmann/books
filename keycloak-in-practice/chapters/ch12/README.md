# Chapter 12 — LDAP User Federation

Expects: Chapter 2's `make ad-up` succeeded at least once, and the realm
as Chapter 11 left it (Anna local, in Chapter 7's `logistics` group).

```bash
set -a; . ./.env; set +a      # seed-ad.sh needs AD_ADMIN_PASSWORD
make ad-up
./chapters/ch12/seed-ad.sh
```

Nine users, three groups: `logistics`, `finance`, `contractors` —
Chapter 7's names, lower case, because the `groups` claim carries them
verbatim. `anna` exists in **both** the directory and the realm at this
point, which is deliberate — the chapter uses the collision to show
what a federated user is and what a local one is.

## The things that catch everyone

**Component config values are lists, not strings.** The admin API stores
a component's configuration as a map of string to *array*:

```json
{"bindDn": ["CN=Administrator,CN=Users,DC=meridian,DC=test"]}
```

Passing a bare string is accepted and then ignored, with no error.

**Keycloak is the client here.** It opens the LDAPS connection, so it
needs the Meridian root in the *server's* trust store: every file in
`/opt/keycloak/conf/truststores/`, which `compose.yaml` fills from
`pki/ca.crt`. That is the third of the four trust stores Chapter 2
listed. `conf/truststore.jks` from `make kcadm-init` is the admin CLI's
and plays no part. Without the server's store the sync reports
`0 imported users` and the reason is only in the log.

**The local Anna wins until you delete her.** A realm cannot hold two
users with one username, so the sync skips the directory's `anna`.
Deleting the local one removes her groups, roles, `employee_number`,
password and sessions; the directory's Anna arrives with a new id (a
new `sub`) and the directory's password, `Meridian-Lab-2026`.

**Quote the sync path in zsh:**
`"user-storage/$AD/sync?action=triggerFullSync"` — unquoted, the `?`
is a glob.

## State this chapter leaves

- LDAP provider `meridian-ad` (vendor `ad`, `READ_ONLY`, import on,
  changed-users sync every 60 s — `changedSyncPeriod=60`).
- Mappers: the AD preset, plus `ad-groups` (group-ldap-mapper,
  `groups.dn=CN=Users,...`, groups imported at the top level) and
  `employee-number` (`employeeNumber` → `employee_number`).
- Groups: `/logistics`, `/finance`, `/contractors` from the directory,
  and seventeen built-in AD groups. Chapter 7's `/meridian-freight`
  tree is deleted.
- `/logistics` carries the realm roles `employee` and `dispatcher`.
- `anna` is the directory's user: `logistics`, `MF-4471`, password
  `Meridian-Lab-2026`. Token with `scope=openid groups`:
  `"groups": ["logistics"]`.
- Taking someone out of `logistics` in the directory takes the group
  and the roles away after the next changed-users sync (within a
  minute; before it, Keycloak's cached copy still says `logistics`):

  ```bash
  docker compose exec -T dc samba-tool group removemembers logistics anna
  ```

Disabling someone in the directory (`samba-tool user disable`) refuses
a password login at once; an existing Keycloak session and its refresh
token keep working until that sync. End sessions explicitly with
`kcadm create users/<id>/logout -r meridian`.
