# Vault in Production — companion repository

Book 04 of the *In Practice* series. Every command in the book runs
against this lab.

## The lab is a cluster

Book 1 built a single node and added a cluster in its Chapter 21. This
book starts there: **three nodes, Raft, TLS, from Chapter 1.** Almost
nothing in Day 2 operations is interesting on one node.

Every lab starts from nothing and ends with `make reset`, so any
chapter can be run on its own:

```bash
make reset    # start clean
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

Every lab in the book is also a script here. Each one carries its
findings as comments, and several abort rather than report a number
when their own preconditions are not met.

| | |
|---|---|
| `chapters/ch01/measure.sh` | Lab 1 — three numbers whose value is in the second reading |
| `chapters/ch02/accept.sh` | the seven acceptance checks before the first real secret |
| `chapters/ch10/carry.sh`, `rehearse.sh` | snapshot plus keys, then a timed restore on a clean host |
| `chapters/ch12/` | kind cluster, Helm values, `join.sh`, snapshot CronJob, `restore.sh` |
| `chapters/ch13/` | Postgres, two database roles, blast radius and failure modes |
| `chapters/ch14/` | Vault Agent: the rendered file against the proxy, through an outage |
| `chapters/ch15/audit-loop.sh` | the sole audit device that locks the cluster out |
| `chapters/ch16/lease-growth.sh` | what a lease costs, and the disk that stays full |
| `chapters/ch17/seal-alert.sh`, `slo.sh` | the seal alert that fires on a healthy leader; the indicator that lies |
| `chapters/ch18/name-the-client.sh` | metrics, server log and audit device, asked who did it |
| `chapters/ch19/bench.sh` | where the time goes, with the harness overhead stated |
| `chapters/ch20/bench.sh`, `break.sh` | OpenBao with a SoftHSM seal: PKCS#11 calls per request and per restart |
| `chapters/ch21/wrapping.sh` | response wrapping, the delivery receipt, and one message for three failures |
| `scripts/readiness.sh` | Appendix G, the production readiness review |

Appendix A lists the versions every number was measured with, Appendix
F how to clean up after each chapter, and Appendix G is
`scripts/readiness.sh`.

## Requirements

- Docker, or podman run rootful (`scripts/engine.sh` picks it up; on
  SELinux hosts every mount gets `:z`)
- the Vault CLI 1.18.5, `jq`, `curl`, `openssl`, `make`
- 16 GB of RAM for the chapters that run more than the three nodes
- for Chapter 12 only: kind, kubectl and Helm

Nothing needs a cloud account or costs money.
