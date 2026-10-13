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

## The tree, without the console

Step 3 is done in the admin console on purpose. To rebuild the same
`meridian-browser` flow after a reset, or to see what the clicks were:

```bash
./chapters/ch10/build-flow.sh      # builds, does not bind
kcadm update realms/meridian -r meridian -s browserFlow=meridian-browser
```

## State this chapter leaves

- `meridian-browser` **bound** as the realm's browser flow (Chapter 13
  adds Kerberos to it), with `Level 1` (password), `Level 2` (OTP,
  requested with `acr_values=gold`) and the role-conditional 2FA
  subflow for `payments-approver`
- realm attribute `acr.loa.map` = `{"gold":"2","silver":"1"}`
- Anna: no OTP credential, no `payments-approver` — she logs in with a
  password, and her tokens carry `"acr": "silver"`

## Codes without a phone

```bash
./chapters/ch10/totp.py '<the base32 secret Keycloak showed you>'
```

The secret appears after **Unable to scan?**, in groups of four; quote
it with the spaces.

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
