# Chapter 13 — Kerberos and Desktop SSO

Expects: Chapter 12 finished — the directory running (`make ad-up`),
the LDAP provider `meridian-ad`, and Chapter 10's `meridian-browser`
flow bound.

```bash
set -a; . ./.env; set +a      # make-keytab.sh uses AD_ADMIN_PASSWORD
./chapters/ch13/make-keytab.sh
```

That creates `keycloak-svc` in the directory, registers
`HTTP/sso.meridian.test` on it, forces AES keys, and exports
`pki/keycloak.keytab`. Keycloak sees it as
`/opt/keycloak/conf/pki/keycloak.keytab` through the `./pki` mount.

## The things that catch everyone

**The provider switch changes your flows.** Setting
`allowKerberosAuthentication` on `meridian-ad` sets the *Kerberos*
execution to `ALTERNATIVE` in every browser flow that has one — the
bound `meridian-browser` and the built-in `browser`.

**A hint must come before a ticket.** With *Kerberos* above the
*Identity Provider Redirector*, a browser without a ticket gets a `401`
page that submits itself, and `kc_idp_hint` is lost on the way. The
chapter raises the redirector above Kerberos; Chapter 14 depends on it.

**Inspecting the keytab.** Keycloak's image has no `klist` and the
client box does not mount `pki/`. Copy it over first:

```bash
docker compose cp pki/keycloak.keytab client:/tmp/keycloak.keytab
docker compose exec -T client klist -ke /tmp/keycloak.keytab
```

**RC4.** If the keytab holds only `arcfour` keys, the script warns; a
modern JDK refuses them.

## State this chapter leaves

- `meridian-ad` with Kerberos on (`MERIDIAN.TEST`,
  `HTTP/sso.meridian.test@MERIDIAN.TEST`, keytab above, `debug` on —
  turn it off once it works).
- `meridian-browser`, top level: Cookie, Identity Provider Redirector,
  Kerberos, Organization, forms (Chapter 10's level subflows) — all
  `ALTERNATIVE`.
- A Kerberos login gives `acr: "silver"`, even when `acr_values=gold`
  is requested.
- A login without a ticket — any `curl` from your laptop — first gets
  `401` with `WWW-Authenticate: Negotiate` and a self-submitting form;
  POST that form's `ACTION` to reach the password form.

## Undo

```bash
source chapters/kcadm.sh
AD=$(kcadm get components -r meridian -q name=meridian-ad \
       --fields id --format csv --noquotes)
kcadm update components/$AD -r meridian \
  -s 'config.allowKerberosAuthentication=["false"]'
```

That also sets the *Kerberos* execution back to `DISABLED` in both
browser flows, as switching it on set it to `ALTERNATIVE`. The
redirector stays where Step 3 moved it, which is harmless.
