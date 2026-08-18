# Publishing this repository

The repository is complete and committed locally. Two steps remain, and
both need a GitHub session that this machine does not currently have.

## 1. Authenticate

`gh` is not logged in on this machine. Run:

```bash
gh auth login
```

Choose **GitHub.com**, **SSH** (or HTTPS), and authenticate as
`thomaszachmann`.

> The Obsidian vault on this machine pushes to `thedevopszone`. Make sure
> the account you authorise here is `thomaszachmann`, or the repository
> will be created in the wrong place.

## 2. Create and push

**Private** — recommended until the book is published:

```bash
cd ~/Documents/vault-in-practice-code
gh repo create thomaszachmann/vault-in-practice-code \
  --private --source=. --remote=origin --push
```

**Public** — when the book goes on sale, readers need this:

```bash
gh repo create thomaszachmann/vault-in-practice-code \
  --public --source=. --remote=origin --push
```

Switching later is one command:

```bash
gh repo edit thomaszachmann/vault-in-practice-code --visibility public
```

## 3. After it exists

Set the description and topics so it is findable:

```bash
gh repo edit thomaszachmann/vault-in-practice-code \
  --description "Companion code for the book Vault in Practice" \
  --add-topic hashicorp-vault \
  --add-topic openbao \
  --add-topic secrets-management \
  --add-topic devops \
  --add-topic kubernetes
```

## Recommendation

**Private now, public on launch day.** A companion repository that is
public before the book exists gets indexed, forked and quoted without the
text that explains it — and the labs read as a disconnected pile of shell
scripts without their chapters. There is no benefit to publishing early
and a small reputational cost to it.

## Before making it public

- [ ] Confirm `.gitignore` still excludes `init.json`, `data/`, `logs/`
      and `tls/*.pem`
- [ ] Run a secret scan over the full history, not just the worktree
- [ ] Check that no real hostnames or internal addresses crept into the
      compose files
- [ ] Add the book's ISBN and store link to the README
