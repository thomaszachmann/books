# Chapter 2 — Building Your Lab

Expects: nothing. This is the first chapter that uses the repository.

```bash
make pki
```

Creates `pki/ca.crt`, `pki/sso.crt` and `pki/dc.crt`. Idempotent — an
existing root is reused, because the root is installed in four trust
stores and reissuing it means redoing all four.

Then install `pki/ca.crt` into your operating system trust store **and**
into Firefox, which keeps its own. That second one is the half people
skip.

## The directory server

`ad/` builds a Samba domain controller from Ubuntu rather than pulling a
community image, so that it runs natively on Apple silicon. `VERSIONS.md`
explains the reasoning.

```bash
make ad-up
docker compose exec client kinit administrator
docker compose exec client klist
make ad-down
```

A ticket means the KDC answers and DNS inside the compose network works
— everything Chapter 12 needs, ten chapters early.
