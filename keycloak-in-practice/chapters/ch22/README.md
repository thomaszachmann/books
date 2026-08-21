# Chapter 22 — Backup, Restore, and Disaster Recovery

Expects: a realm with users, clients and at least one issued token.

```bash
./chapters/ch22/backup.sh
```

Two files, and only one of them is a backup. The script deliberately
prints the questions rather than the answers, because what an export
contains depends on the version and the mode — and an operator who
checked on their own version knows something an operator who read a blog
post does not.

## The test that settles it

Note a token's `kid` before you destroy anything. After each restore,
compare. If the `kid` changed, the realm's signing keys did not survive,
and every token ever issued — including every offline token — is now
invalid.

```bash
./chapters/ch04/decode-token.sh header < tokens.json | jq -r .kid
```
