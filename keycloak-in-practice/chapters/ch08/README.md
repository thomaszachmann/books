# Chapter 8 — Tokens, Claims, and Mappers

Expects: Chapters 6 and 7 finished.

Two things happen here. The audience mapper fixes the `aud: account`
that Chapter 4 left deliberately broken — Chapter 7's roles hid it
through *audience resolve*, and Step 0 makes it visible again — and the
group mapper adds the claim Chapter 16 cannot work without.

`employee_number` must be declared in the realm's **user profile**
before Keycloak stores it; unmanaged attributes are dropped without an
error (Step 4).

`../ch04/decode-token.sh id` decodes the ID token, `payload` the access
token.

Then the token is made too large on purpose:

```bash
docker compose --profile ch08 up -d proxy
./chapters/ch08/inflate.sh 200
# log in again, then send the token through the proxy
./chapters/ch08/inflate.sh 200 --undo
```

`inflate.sh` puts the roles on a client of its own, `inflate-demo`, in
one partial import, so it takes about half a minute; `--undo` deletes
that client and the roles with it.

`nginx.conf` sets `large_client_header_buffers 4 4k`, which is half
nginx's default and is what plenty of gateways ship with. The failure is
a **400**, not a 431, and the body says nothing about tokens.
