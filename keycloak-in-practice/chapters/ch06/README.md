# Chapter 6 — Realms, Clients, and Scopes

Expects: Chapter 4 finished; `meridian-portal` exists.

The chapter creates a second realm to demonstrate what a realm does not
share, then deletes it again in Exercise 6.1. Nothing later in the book
depends on `northwind` existing.

```bash
source chapters/kcadm.sh
kcadm get keys -r meridian | jq -r '.keys[] | select(.use=="SIG") | .kid'
```

`meridian-api` is created here with every flow disabled. That is not an
oversight — an API does not log anybody in. Chapter 8 gives it an
audience so that tokens can name it.
