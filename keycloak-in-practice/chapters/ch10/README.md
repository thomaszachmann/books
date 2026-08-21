# Chapter 10 — Authentication Flows and MFA

Expects: Chapter 9 finished.

Built-in flows cannot be edited. Copy first, then bind — and know how to
bind back before you change anything:

```bash
source chapters/kcadm.sh
kcadm get realms/meridian --fields browserFlow
```

Write that value down. If a flow change locks everyone out, that command
in reverse is the way back, and it is run against the `master` realm's
administrator, which is why Chapter 6 insisted that realm keep its job.

## Codes without a phone

```bash
./chapters/ch10/totp.py <the base32 secret Keycloak showed you>
```

Standard library only, and verified against the RFC 6238 test vectors —
secret `GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ`, which is the ASCII string
`12345678901234567890` in Base32:

| Unix time | Expected |
|---|---|
| 59 | `287082` |
| 1111111109 | `081804` |

```bash
./chapters/ch10/totp.py GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ --at 59
```

If codes are rejected, check the clock in the Keycloak container before
anything else — TOTP is the clock plus a secret, and a container whose
host slept is the usual cause.
