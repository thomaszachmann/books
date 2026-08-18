# minikube path — Chapter 15

kind and minikube disagree about three things, and Harbor is where the
disagreement stops being academic.

| Concern | kind | minikube |
|---|---|---|
| Ingress | install the controller, map ports at create time | `minikube addons enable ingress` |
| External address | none; the host's own ports | `minikube tunnel`, a real LoadBalancer IP |
| Loading an image | `kind load docker-image` | `minikube image load` |

Start the cluster:

```bash
minikube start -p harbor-lab --cpus 4 --memory 8192
minikube addons enable ingress -p harbor-lab
```

Then, in a second terminal that stays open:

```bash
minikube tunnel -p harbor-lab
```

The tunnel is the part people forget. Without it the ingress has no
address, `docker push` cannot reach it, and the error looks like a
Harbor problem rather than a networking one.
