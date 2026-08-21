# Chapter 1 — Why On-Premises

**State this chapter expects:** none. There is no cluster yet, and that is
deliberate.

## What is here

| Path | What it is |
|---|---|
| `workload/` | An application bundle as it looked after two years in a managed cluster |
| `inventory.sh` | Extracts the external dependencies the book asks you to find by hand first |

## The bundle is deliberately dated

`postgres:16.4`, `cert-manager:v1.16.1` and `ingress-nginx:v1.11.3` are old
on purpose — this is a manifest set somebody has been running, not one you
would write today. `ingress-nginx` in particular was archived by the
Kubernetes project in March 2026, which is the point Chapter 1 makes about
the fifth class of dependency. None of these are pinned in `VERSIONS.md`.

## Two things `inventory.sh` does not find

Both are exercises in the chapter, and both are in the bundle:

1. Dependencies written as bare hostnames rather than URLs — see the
   environment of `workload/deployment.yaml`.
2. A Helm repository **alias** in `workload/operators/Chart.yaml`, resolved
   by the client against the machine's repo list. Not an image, not a
   controller, not a URL, and invisible from the cluster's side.
