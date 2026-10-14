# Chapter 9 — Sessions, SSO, and Logout

Expects: Chapter 8 finished.

```bash
docker compose --profile ch09 up -d logout-sink
docker compose logs -f logout-sink
```

The sink must be reachable **from the Keycloak container**, which is why
its back-channel URL is `http://logout-sink:8000/logout` and not
`localhost`. Back-channel means server to server; your laptop is not
involved, and configuring it as though it were is the usual first
mistake.

Every `kcadm` call about sessions needs `-r meridian`; without it the
CLI asks `master`.

After an administrator's logout, `userinfo` refuses the old access
token (Keycloak checks the session) while the API from Chapter 4, which
validates offline, still serves it until `exp`. That difference is
Step 4.

`GET /last` returns the most recent logout token, so you can decode it
without copying from a log:

```bash
docker compose exec -T client curl -sS http://logout-sink:8000/last \
  | ./chapters/ch04/decode-token.sh payload -
```
