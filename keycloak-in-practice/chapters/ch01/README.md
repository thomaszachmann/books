# Chapter 1 — Why Single Sign-On

Three applications, three user databases, and no system that can list a
person's access.

```bash
make ch01
```

Three Apache containers, all running `httpd.conf` from this directory,
each keeping its own password file at `/etc/httpd-users` **inside the
container**. That separation is the chapter: the file is not mounted and
not shared, because three real applications would not share one either.

Apache re-reads the password file on every request, so there is no
reload step. Do not read that as a convenience — it means a removed
account stops working immediately, and the chapter still shows two
applications letting the contractor in.

Ports 8081, 8082, 8083.

```bash
docker compose --profile ch01 down
```
