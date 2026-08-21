# Vault in Production — companion repository

Book 02 of the *In Practice* series. Every command in the book runs
against this lab.

## The lab is a cluster

Book 1 built a single node and added a cluster in its Chapter 21. This
book starts there: **three nodes, Raft, TLS, from Chapter 1.** Almost
nothing in Day 2 operations is interesting on one node.

```bash
make up       # generate certs and configs, start three nodes
make init     # initialise, once
make unseal   # unseal all three
. ./scripts/vault-env.sh
make status
```

| Node | Port |
|---|---|
| `vip-vault-1` | 8210 |
| `vip-vault-2` | 8220 |
| `vip-vault-3` | 8230 |

The container names carry a `vip-` prefix so this lab and Book 1's can
run side by side without fighting over names.

## What is generated, what is committed

`cluster/tls/`, `cluster/config/`, `cluster/data*/` and `cluster/init.json`
are produced by `scripts/cluster-up.sh` and `make init`. They are **not**
committed — the monorepo's `.gitignore` covers them. `cluster/init.json`
holds five unseal keys and a root token, which is exactly what Chapter 7
tells you never to do outside a lab.

## Chapters

| | |
|---|---|
| `chapters/ch01/measure.sh` | Lab 1 — the three measurements whose value is in the second reading |

The rest arrive with their chapters.

## Requirements

Docker, `jq`, `openssl`, and about 2 GB of RAM for the three nodes. Two
later chapters want kind or minikube; two more want a cloud account and
will say so.
