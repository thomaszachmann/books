# Chapter 21 — High Availability and Scaling

**Starting state:** Chapter 20 finished. Most of this needs no cluster —
`helm template` renders locally.

```bash
helm repo add harbor https://helm.goharbor.io
helm template harbor harbor/harbor --version 1.19.2 \
  -f ../../k8s/values-ha.yaml > release.yaml
MAX_CONNS=1024 ./render-check.sh release.yaml
```

## Why a checker at all

Helm does not reject value names it has never heard of. A `--set` can be
accepted and ignored, and both official HA documents contain paths that
are ignored:

| What the documents say | What the chart reads |
|---|---|
| `jobservice.jobLogger` | `jobservice.jobLoggers` — plural, a **list** |
| `…persistentVolumeClaim.jobservice.accessMode` | `…jobservice.**jobLog**.accessMode` |
| `…persistentVolumeClaim.jobservice.storageClass` | `…jobservice.**jobLog**.storageClass` |

Neither produces an error. Render the manifest and check the effect —
that is all `render-check.sh` does, and it is the reason it exists.

## What it checks

1. **Blobs.** An `emptyDir` for `registry-data` is correct with object
   storage and catastrophic with `filesystem`, and the rendered YAML is
   identical in both cases. The check decides on
   `REGISTRY_STORAGE_PROVIDER_NAME`. A PVC with more than one replica
   fails.
2. **Job logs.** More than one replica with a `ReadWriteOnce` job-log
   claim is the `Multi-Attach` failure. Passing needs either the
   database logger or `ReadWriteMany`.
3. **Connections.** `database.maxOpenConns` is **per pod** and covers
   core and exporter. Pods × value against `MAX_CONNS` (default 1024,
   what the internal Postgres ships with).
4. **Scan throughput.** Trivy replicas × `SCANNER_JOB_QUEUE_WORKER_CONCURRENCY`,
   which defaults to **1** and is not exposed by the chart.

```
FAIL  registry: 3 replicas share one PVC
      use object storage, or a ReadWriteMany class
FAIL  database: 4 pods x 900 = 3600 > 1024
      lower database.maxOpenConns or raise max_connections
```

## Two shell traps in the commands

```bash
--set 'jobservice.jobLoggers[0]=database'   # quote it: [0] globs in zsh
--set-string 'trivy.extraEnvVars[0].value=4' # plain --set renders 4, unquoted
```

## The starting point

`k8s/values-ha.yaml` is a rendered-and-checked HA values file: external
Postgres, external Redis with Sentinel, S3 blobs, the database job
logger, and every replica count justified by a number in the chapter. It
does not create the three stores. Read it before you use it.
