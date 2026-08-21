# Chapter 3 — Running Keycloak

Expects: `make pki` has run and `pki/` holds a root and `sso.crt`.

```bash
make up
make kcadm-init
make kcadm-login
make realm
```

`make up` starts PostgreSQL, waits for it to be healthy, then starts
Keycloak in **production mode** — `start`, not `start-dev`. The command
line is in `compose.yaml` and every option there is discussed in the
chapter.

The first start takes longer than later ones: Keycloak runs a build
because build options changed, then creates its schema.

## Where things are

| What | Where |
|---|---|
| Keycloak | `https://sso.meridian.test` |
| Health and metrics | `https://sso.meridian.test:9000` |
| Admin console | `https://sso.meridian.test/admin` |

Health is on 9000 and not on 443. That is not a mistake in this file;
see the chapter.
