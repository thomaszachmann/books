# Chapter 3

**Kapitel 3: Gespiegelte Bezugsquellen als einziger Bezugsweg (Harbor, Nexus, Artifactory)**

Starts from Chapter 0. Leaves Nexus (stopped) with proxies for Docker Hub, PyPI, Debian and npm, and `localhost:5001/demo-app:1.0.0-mirror` built with `--network=none`.

| File | Book step | Goes to |
|---|---|---|
| `docker-hub.json` | Schritt 5 | `~/seclab/kap03/` |
| `pypi-proxy.json` | Schritt 6 | `~/seclab/kap03/` |
| `apt-proxy.json`, `nexus.sources` | Schritt 7 | `~/seclab/kap03/` |
| `npm-proxy.json` | Schritt 8 | `~/seclab/kap03/` |
| `pip.conf` | Schritt 9 | `~/seclab/kap03/` (copied into `demo-app/` in Schritt 10) |
| `demo-app/Dockerfile.mirror` | Schritt 11 | `~/seclab/kap03/demo-app/` |
| `uebung/apt-security.json`, `nexus.sources`, `maven-proxy.json` | Übung, Lösung | `~/seclab/kap03/` |

The Nexus admin password `lab-nexus-123` is a lab value set via the REST API in Schritt 3.
