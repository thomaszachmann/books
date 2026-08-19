# Chapter 16 — Consuming Harbor From the Cluster

**Starting state:** Chapter 15 finished. Nodes trust the CA, you can
push from your laptop.

```bash
./chapters/ch06/make-robot.sh platform cluster-pull 90 pull
./pull-secret.sh apps 'robot$platform+cluster-pull' "$SECRET"
./find-pull-secrets.sh
```

## Mind the dollar

A robot is called `robot$project+name`. In **double** quotes a shell
reads `$project` as a variable:

```sh
$ echo "robot$platform+cluster-pull"     # unset variable
robot+cluster-pull                       # the project vanished

$ platform=XYZ
$ echo "robot$platform+cluster-pull"     # worse
robotXYZ+cluster-pull

$ echo 'robot$platform+cluster-pull'     # correct
robot$platform+cluster-pull
```

The pod reports `401 Unauthorized` and says nothing about any of it.
`pull-secret.sh` warns when the name reaches it without a `$`, and reads
the stored username back out of the cluster so you can see what actually
landed.

## Secrets do not cross namespaces

One credential becomes one per namespace, and every new namespace is a
step somebody has to remember. `find-pull-secrets.sh` counts them —
run it after a year and the number is the argument for Chapter 19.

Three places to attach, in increasing blast radius:

```
pod.spec.imagePullSecrets        this pod
serviceAccount.imagePullSecrets  every pod using that account
node configuration               every pod on the node
```

## Being able to pull is not being allowed to run

Harbor's signature policy checks only that a signature exists — Chapter
10. The check that answers *is this ours* runs at admission, against a
key you configured. Start with `failureAction: Audit`, read the policy
reports for a week, then `Enforce`.

`mutateDigest: true` rewrites the admitted reference from the tag to the
verified digest, so manifests stay readable and what runs is pinned.
That closes the question Chapter 8 left open.
