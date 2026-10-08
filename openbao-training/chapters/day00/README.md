# Day 0

**Tag 0: Das Trainingsgelände aufbauen**

Starts from nothing. Leaves `bao`, `kind`, `kubectl`, `helm`, `jq` and OpenSSL 3 on the PATH, the directories `~/bao-lab/{tag01..tag06,tls,k8s}` and three shell helpers in `~/.zshrc`.

The book works in `~/bao-lab`.

| File | Book step | Goes to |
|---|---|---|
| `lab-helfer.zsh` | Drill 5 | appended to `~/.zshrc` (`cat lab-helfer.zsh >> ~/.zshrc`) |
| `check.sh` | Kontrollpunkt | **`source check.sh`** in your interactive shell — `labenv` is a shell function and is invisible to a child process |
| `challenge/baoup.zsh` | Challenge, Lösung | a shell function for `~/.zshrc` — `source` it, do not execute it |

No files are written by Drills 1–4; they install tools and create `~/bao-lab`. Drill 1 also appends one line to `~/.zshrc` that puts Homebrew's keg-only `openssl@3` ahead of `/usr/bin/openssl` (LibreSSL).
