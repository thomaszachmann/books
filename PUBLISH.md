# Publishing

This repository holds the companion code for every book. It is **private**
until a book is published.

## Making it public

```bash
gh repo edit thomaszachmann/books --visibility public
```

**Recommendation: stay private until the first book is on sale.** Companion
code without the text that explains it reads as a disconnected pile of
shell scripts, and it will be indexed and quoted in that state.

## Before making it public

- [ ] `.gitignore` still excludes `**/data/`, `**/logs/`, `**/tls/*.pem`,
      `**/init.json` and `**/root-ca/`
- [ ] Secret scan over the **full history**, not just the worktree:
      `git log -p --all | grep -E 'hv[sbr]\.|AKIA|BEGIN .*PRIVATE KEY'`
- [ ] No real hostnames or internal addresses in the compose files
- [ ] Each book's README links to its store page and ISBN

## Adding a book

One directory per book, self-contained, with its own `README.md` stating
what to clone and where to start. Add a row to the table in the top-level
`README.md`.

Runtime state belongs in `data/`, `logs/` or `tls/` inside the book's
directory — the root `.gitignore` matches those at any depth.
