# Publishing

This repository holds the companion code for every book.

**It is public.** The gate below was passed when *Vault in Practice* went on
sale; the repository was opened accordingly. What follows is kept as the
standing checklist, because it applies to every new book directory and to
every commit — not only to the one moment the switch was flipped.

```bash
gh repo edit thomaszachmann/books --visibility public   # already done
```

The reason for the original gate still holds and is worth remembering:
companion code without the text that explains it reads as a disconnected
pile of shell scripts, and it will be indexed and quoted in that state.
That is why every directory's README says which book it belongs to, and
why the top-level README now links to the store pages.

## Standing checklist

- [ ] `.gitignore` still excludes `**/data/`, `**/logs/`, `**/tls/*.pem`,
      `**/init.json` and `**/root-ca/`
- [ ] Secret scan over the **full history**, not just the worktree:
      `git log -p --all | grep -E 'hv[sbr]\.|AKIA|BEGIN .*PRIVATE KEY'`
- [ ] No real hostnames or internal addresses in the compose files
- [x] Each book's README links to its store page and ISBN
      — done 2026-09-03 for *Vault in Practice*; the other four have no
      store page yet and carry an em dash in the table
- [x] **Commit identity.** The books appear under the pen name, so the
      commits should too. Set per repository, not globally:
      `git config user.name "Thomas Zachmann"` and
      `git config user.email "thomas@zachmann.work"`.
      Done 2026-09-03 for this repository. Check with
      `git log --format='%an <%ae>' | sort | uniq -c` before publishing a
      new book directory.

      **The 30 older commits keep the real name — decided, not overlooked.**
      They were made before the identity was set per repository. Rewriting
      them would mean a force-push over a public history and would break
      every clone, for a gain that does not justify it. The GitHub
      contributor list therefore shows a second account beside the pen
      name. If that is ever to change, the route is `git filter-repo` with
      a mailmap, a bare clone as a backup, and a preview of the affected
      commits first.

## Adding a book

One directory per book, self-contained, with its own `README.md` stating
what to clone and where to start. Add a row to the table in the top-level
`README.md`.

Runtime state belongs in `data/`, `logs/` or `tls/` inside the book's
directory — the root `.gitignore` matches those at any depth.


## Scan log

Keeping the result means the next scan compares against something.

**2026-09-03** — full history, 138 commits, 30,924 diff lines.

| | |
|---|---|
| GitHub / OpenAI / AWS / Slack tokens, JWTs | none |
| Private keys in the history | none |
| `hv[sbr].` hits | 10, all deliberate lab fixtures (`hvs.NEVERVALID123`, `hvs.notarealwrappingtoken`, four-character prefix checks from `cut -c1-4`) and this file's own scan command |
| `password=` hits | 36, all lab values (`db_password=v2secret`, `before-rotation`, `after-rotation`, `inject-me`) |
| Internal addresses | 23, all the book's own lab networks `10.44.0.0/24` and `10.45.0.0/24` |

Two things in the **working tree**, neither in the history:

- `**/tls/*.pem` — private keys for the Vault and Keycloak labs. Covered by
  the committed `.gitignore` (line 5). Safe.
- `keycloak/.env` — was covered **only by an uncommitted** `.gitignore`
  change. That is now committed, so the protection survives a
  `git checkout .gitignore`. It did not before.