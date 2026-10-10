# Gateway API zum Anfassen — Companion Code

Working code for the labs in **Gateway API zum Anfassen** by Thomas Zachmann. It is a
German-language, hands-on training camp for the Kubernetes Gateway API, subtitled
*Von kind auf dem Laptop zu RKE2 auf Proxmox*. The book has fifteen days (Tag 0–14) and
two appendices. Parts A and B (Tag 0–7) run on a kind cluster on the laptop, with
Envoy Gateway as the main implementation. Parts C and D (Tag 8–14) build a highly
available RKE2 cluster on Proxmox with Cilium as the second implementation, then cover
policies, observability, upgrades, an ingress-nginx migration and eight disaster drills.

> **Status: free edition, October 2026.** These files are copied unchanged from the
> manuscript's `code/` folder. The book's preface says it was *getestet mit Gateway API
> v1.6, Envoy Gateway v1.9.2, kind 0.33 (Kubernetes 1.37) und cloud-provider-kind
> 0.12.0*. Days 8–14 need Proxmox, a multi-node RKE2 cluster and ARP on a real network.
> The book says none of that can be reproduced in kind. The outputs printed for those
> days come from the official documentation or from static checks (`tofu validate`,
> `ansible-lint`, `helm template`, `kubeconform`), and were **not** produced live.
> There are two exceptions, Tag 12, Drill 8 and the `ingress2gateway` runs of Tag 13. See
> [`VERSIONS.md`](VERSIONS.md#what-the-book-says-was-checked) for each day.
> Book: [PDF](https://github.com/thomaszachmann/books/releases/download/gateway-api-training-2026.10/Gateway-API-zum-Anfassen.pdf) · [EPUB](https://github.com/thomaszachmann/books/releases/download/gateway-api-training-2026.10/Gateway-API-zum-Anfassen.epub) (free, CC BY-NC-ND 4.0)

> **Auf Deutsch:** Dieses Verzeichnis enthält den Begleitcode zum Buch
> *Gateway API zum Anfassen* – ein Trainingslager zum Mitmachen mit 15 Tagen (Tag 0–14)
> und zwei Anhängen. Zuerst geht es mit kind und Envoy Gateway auf dem Laptop los, danach
> folgt ein hochverfügbarer RKE2-Cluster mit Cilium auf Proxmox, und am Ende stehen
> Desaster-Drills. Die Dateien stammen unverändert aus dem `code/`-Ordner des Manuskripts.
> Die Tage 8–14 hat das Buch nur statisch geprüft. Ihre Ausgaben sind nicht live
> erzeugt. Alle Passwörter sind Laborwerte. Schlüssel, Tokens, Kubeconfigs und
> OpenTofu-State liegen hier nicht.

> **This repository is not a shortcut.** The book's first training rule is *Tippen,
> nicht kopieren. Jeder Befehl einmal selbst.* Most files in `code/` are printed in full
> in the book and are meant to be typed. Use this repository to check your work, to get
> the files the book only references, and to recover when something is broken.

---

## The lab lives in `~/gw-lab`, not here

Every path in the book is under `~/gw-lab`. Tag 0 creates `~/gw-lab/code/demo` for
everything that several days need, plus one directory per day, `~/gw-lab/tag01` …
`~/gw-lab/tag14`, for the day's own files. Later chapters expect the companion code
under **`~/gw-lab/code/`**. For example, Tag 4 applies
`~/gw-lab/code/tag04/secure-backend.yaml`, Tag 7 applies `~/gw-lab/code/tag07/rbac.yaml`,
and `tag12/upgrade-eg.sh` reads its values files from `~/gw-lab/code`. So `code/` here
maps one-to-one to `~/gw-lab/code/`:

| Here | In the lab | Book days | What it is |
|---|---|---|---|
| `code/demo/` | `~/gw-lab/code/demo/` | Tag 0–2 create it; it is used again on Tag 3, Tag 9, every `conds.sh`/`gw-ip.sh` call, and Anhang B | The kind cluster, namespaces, demo apps, GatewayClass `eg`, Gateway `infra/web`, Route `shop`, and helper scripts. All of these are typed in the book except `up.sh` and `down.sh` (see below) |
| `code/tag04/` | `~/gw-lab/code/tag04/` | Tag 4; `lab-ca.yaml` is used again on Tag 9 and in Anhang B | TLS: lab CA, HTTPS listeners, redirect, TLSRoute, BackendTLSPolicy. `secure-backend.yaml` is only referenced in the book; the others are typed into `~/gw-lab/tag04` |
| `code/tag05/` | `~/gw-lab/code/tag05/` | Tag 5 | Canary, header canary, blue-green, `measure.sh`, `rollout.sh`, `switch.sh`. All typed into `~/gw-lab/tag05` |
| `code/tag06/` | `~/gw-lab/code/tag06/` | Tag 6 | GRPCRoute, TCPRoute, UDPRoute and their backends. All typed into `~/gw-lab/tag06`, plus `listeners-patch.sh`, which is not in the book (see below) |
| `code/tag07/` | `~/gw-lab/code/tag07/` | Tag 7; `payments-api.yaml` and `refgrant-backend.yaml` are used again on Tag 14 and in Anhang B | Multi-tenancy: RBAC, `allowedRoutes`, ReferenceGrant, ListenerSet. `rbac.yaml`, `gateway-mandanten.yaml` and `payments-api.yaml` are only referenced in the book; the others are typed into `~/gw-lab/tag07` |
| `code/infra-proxmox/` | `~/gw-lab/code/infra-proxmox/` | Tag 8 | `pve-prep.sh` for the Proxmox host, OpenTofu for six VMs (`bpg/proxmox`) |
| `code/infra-rke2/` | `~/gw-lab/code/infra-rke2/` | Tag 8, Tag 9 (Drill 3) | Ansible: RKE2 HA, Cilium `HelmChartConfig`, kube-vip |
| `code/tag09/` | `~/gw-lab/code/tag09/` | Tag 9; `gateway-web.yaml` is used again on Tag 14 | LB-IPAM, Envoy Gateway and Cilium gateways, DNS snippets (dnsmasq/Pi-hole, Unbound), ACME DNS-01 template |
| `code/tag10/` | `~/gw-lab/code/tag10/` | Tag 10; `eg-values.yaml` is used again on Tag 12 and Tag 14 | Envoy Gateway policies, Redis, Keycloak |
| `code/tag11/` | `~/gw-lab/code/tag11/` | Tag 11; `envoyproxy-telemetry.yaml` is used again on Tag 12 | kube-prometheus-stack values, monitors, rules, Jaeger, `dashboards.sh` |
| `code/tag12/` | `~/gw-lab/code/tag12/` | Tag 12; the scripts are used again on Tag 14 and in Anhang A | HA values, upgrade, certificate and CRD checks, config export |
| `code/tag13/` | `~/gw-lab/code/tag13/` | Tag 13 | ingress-nginx legacy setup, inventory, migrated routes, parallel check |

On Tag 8 to Tag 13 the book works **inside** these directories (for example
`cd ~/gw-lab/code/tag10`) and prints most of the files with `cat` rather than having you
type them.

There are no directories for Tag 1, 2, 3 and 14 or for the appendices. Their files, the
Kontrollpunkt scripts `check.sh` of Tags 11–14, and everything in Anhang B
(`~/gw-lab/pruefung`) are typed in the book and are not in this repository.

Tag 0, Drill 3 copies this directory right after creating `~/gw-lab`:

```bash
git clone https://github.com/thomaszachmann/books.git ~/books 2>/dev/null || git -C ~/books pull
cp -R ~/books/gateway-api-training/code/. ~/gw-lab/code/
```

If you skipped it, do it before Tag 4, the first day that applies a file from
`~/gw-lab/code/tag04` that the book does not print. The copy overwrites files you have already typed into `~/gw-lab/code/demo` with
identical ones. It does not touch `~/gw-lab/tagNN`. Then start with Tag 0 in the book.

---

## Requirements

macOS or Linux. Parts A and B need Docker with about 4 CPUs and 8 GB RAM for the Docker
VM, plus about 3 GB of disk (Tag 0). Parts C and D need a Proxmox VE 9.x host with
about 18 vCPU, 36 GB RAM and 300 GB disk for six VMs (Tag 8). They also need a home
network where you can run a DNS server for `*.apps.lab.internal`.

| Needed | From |
|---|---|
| `kind`, `kubectl`, `helm`, `jq`, `cloud-provider-kind`, Docker | Tag 0 |
| `grpcurl` (installed on Tag 0) | Tag 6 |
| `openssl`, `curl`, `dig` | Tag 0 / Tag 4 |
| Proxmox VE 9.x, `ssh`/`scp` to the host, `tofu` (OpenTofu), `ansible`, `ansible-lint` | Tag 8 |
| A DNS server in the home network (dnsmasq/Pi-hole or Unbound); `/etc/hosts` works without wildcards | Tag 9 |
| `htpasswd` | Tag 10 |
| `egctl` (on macOS use Homebrew; the book warns that the raw Darwin binary is unsigned and gets killed on Apple Silicon) | Tag 11, 12, 14 |
| `yq`, `cmctl` | Tag 12, 13, 14 |
| `go`, only to run the Gateway API conformance suite yourself (in a throwaway cluster) | Tag 12 |
| `ingress2gateway` | Tag 13 |

The RKE2 days use fixed lab addresses: `10.10.20.0/24`, API VIP `10.10.20.10`, nodes
`.11–.13` and `.21–.23`, and the LoadBalancer pool `.100–.120`. They are written into
`infra-proxmox/variables.tf`, `infra-rke2/group_vars/all.yml` and
`infra-rke2/inventory.yml`, and into several files in `tag09` … `tag13`. Search for
`10.10.20.` if your network is different.

See [`VERSIONS.md`](VERSIONS.md) for the versions the book was written against.

---

## Versions

| Component | Version |
|---|---|
| Gateway API (Experimental channel, from the Envoy Gateway chart) | v1.6.1 |
| Envoy Gateway (Helm chart `gateway-helm`) | v1.9.2 |
| cert-manager | v1.21.2 |
| kind / Kubernetes (kind default node image) | 0.33.0 / v1.37.0 |
| cloud-provider-kind | 0.12.0 |
| RKE2 | v1.36.5+rke2r1 |
| Cilium (RKE2 chart) | 1.20 |

The book points out that the Envoy Gateway v1.9 compatibility matrix lists Kubernetes
1.33–1.36. It says the book runs on kind's default 1.37.0 *ohne Auffälligkeiten*. To
stay inside the matrix, set `image: kindest/node:v1.36.x` per node in
`demo/kind-gw-lab.yaml`.

---

## Layout

```
README.md  VERSIONS.md  ERRATA.md
code/
  demo/           kind-gw-lab.yaml, namespaces.yaml, shop-v1.yaml, shop-v2.yaml,
                  payments.yaml, gatewayclass.yaml, gateway.yaml, route-shop.yaml,
                  gw-ip.sh, conds.sh, up.sh, down.sh                 Tag 0–2
  tag04/          lab-ca, gateway-https, routes-https, https-redirect,
                  secure-backend, tlsroute, secure-api, backend-tls  TLS
  tag05/          canary-weights, canary-header, blue-green, qa-canary,
                  measure.sh, rollout.sh, switch.sh                  canary, blue-green
  tag06/          payments-v2, grpcroute, l4-echo, tcproute, udproute,
                  listeners-patch.sh                                 gRPC, TCP, UDP
  tag07/          rbac, gateway-mandanten, rogue, payments-api, checkout-route,
                  refgrant-backend, shop-cert, refgrant-secret,
                  listenerset                                        multi-tenancy
  infra-proxmox/  pve-prep.sh, main.tf, variables.tf, versions.tf,
                  outputs.tf, inventory.tftpl,
                  terraform.tfvars.example                           Tag 8: VMs
  infra-rke2/     site.yml, ansible.cfg, inventory.yml, requirements.yml,
                  group_vars/all.yml, roles/{common,rke2_server,
                  rke2_agent}                                        Tag 8: RKE2
  tag09/          lb-ipam, lb-test, envoyproxy-web, gateway-web,
                  gateway-cilium, routes, dnsmasq-apps.conf,
                  unbound-apps.conf, acme-dns01                      gateways on RKE2
  tag10/          eg-values, redis, envoyproxy-web, ctp-web, btp-shop-*,
                  routes-tag10, sp-admin, keycloak, keycloak-backend,
                  sp-api-jwt, sp-portal-oidc, sp-cors                policies
  tag11/          kps-values, monitors, beta-route, envoyproxy-telemetry,
                  jaeger, rules, dashboards.sh                       observability
  tag12/          eg-ha-values, envoyproxy-ha, route-ha, drain-test.sh,
                  crd-check.sh, upgrade-eg.sh, cert-check.sh,
                  export-gw-config.sh                                HA, operations
  tag13/          ingress-nginx-values, legacy-ingress, inventory.sh,
                  routes-migrated, parallel-check.sh, traefik-ingress,
                  challenge-regex                                    migration
```

---

## Files that are not printed in the book

The book prints most files in full: as heredocs to type on Tags 0–7, or with `cat` on
Tags 8–13. These are the exceptions.

- **`demo/up.sh`, `demo/down.sh`.** Tag 0, Drill 8 mentions them. `up.sh` rebuilds the
  lab to the state after Tag 2: kind cluster, Envoy Gateway v1.9.2 (override with
  `EG_VERSION`), demo apps, GatewayClass `eg`, Gateway `infra/web` and Route
  `shop/shop`. It prints `GW_IP` at the end. `cloud-provider-kind` must already be
  running in a second terminal. `down.sh` deletes the cluster. Both accept `CLUSTER`
  (default `gw-lab`). Anhang B starts a fresh lab with `up.sh`, followed by cert-manager
  and two files from `tag04` and `tag07`.
- **`tag04/secure-backend.yaml`, `tag07/rbac.yaml`, `tag07/gateway-mandanten.yaml`,
  `tag07/payments-api.yaml`.** The book prints only an excerpt or nothing at all, and
  applies them from `~/gw-lab/code/…`.
- **`tag06/listeners-patch.sh`.** This one is *not* mentioned anywhere in the book. It is
  an extra helper for Tag 6. It runs the three `kubectl patch` commands from Tag 6,
  Drills 1, 5 and 6, in one go, with the same values. They add the listeners
  `https-grpc` (443, `grpc.gw.localtest.me`, certificate `grpc-gw-tls`), `tcp` (9100)
  and `udp` (9200) to Gateway `infra/web`. Use it to catch up when you start Tag 6 on a
  rebuilt lab. It needs the state after Tag 4 (cert-manager and the lab CA issuer on the
  Gateway), or `grpc-gw-tls` will not be issued. Run it only once, because it appends
  listeners and does not replace them. After Tag 7, `gateway-mandanten.yaml` defines all
  seven listeners itself.
- **Some Ansible and OpenTofu files** (`infra-proxmox/versions.tf`, `outputs.tf`,
  `infra-rke2/ansible.cfg`, `roles/*/tasks`, `roles/*/handlers`). The book shows only
  their effect or excerpts.

---

## Running the scripts

- Tag 1 puts `~/gw-lab/code/demo` on the `PATH`
  (`export PATH="$HOME/gw-lab/code/demo:$PATH"`). After that, `gw-ip.sh` and `conds.sh`
  work from any directory.
- `tag05/*.sh` run from `~/gw-lab/tag05` in the book, against the Tag 4 HTTPS setup.
  `measure.sh` reads the lab CA from `$CA`, which defaults to `~/gw-lab/tag04/lab-ca.crt`.
- `tag11/dashboards.sh` runs from `~/gw-lab/code/tag11`. It downloads the dashboards
  into `./dashboards/`.
- `tag12/upgrade-eg.sh <version>` only prints the CRD diff. Add `--apply` to run the
  upgrade. It expects the values files under `~/gw-lab/code/tag10` and
  `~/gw-lab/code/tag12`.
- `tag12/export-gw-config.sh <dir>` writes into the current directory. The book runs it
  from `~/gw-lab/tag12` (Tag 12) and `~/gw-lab/tag14` (Tag 14).

**Files the labs change or create in here.** On Tag 8, `tofu output -raw inventory`
overwrites `infra-rke2/inventory.yml`. Tag 8 also creates `terraform.tfvars`, a `.bak`
copy, `lab.plan`, `.terraform/` and the OpenTofu state in `infra-proxmox/`. On Tag 9,
`sed -i.bak` changes `cilium_gateway_class_create` in `infra-rke2/group_vars/all.yml`
from `auto` to `"true"`. This repository holds the value from before that change. Tag 10
writes `.htpasswd` into `tag10/`. Tag 12 downloads `eg-report.yaml` and can clone
`gateway-api/` in `tag12/`. Tag 13 writes `i2gw-*` files into `tag13/`.
[`.gitignore`](.gitignore) keeps all of these out of Git if you work inside a clone.

---

## Safety

Everything here is for a lab and is **not** safe for production. The book's sixth rule
is *Lab-Werte bleiben im Lab*. All passwords in the book and in these files are lab
values:

- `lab-admin-1234`: Keycloak bootstrap admin, and Basic Auth user `admin` on Tag 10
- `lab-pass-1234`: Keycloak user `thomas`
- `lab-api-secret-1234`, `lab-portal-secret-1234`: client secrets
- `rke2-lab-token-1234`: the fallback in `group_vars/all.yml` if `RKE2_TOKEN` is not set.
  Tag 8 sets it with `openssl rand -hex 32`.

Keycloak runs in dev mode without a database. The OpenTofu provider uses
`insecure = true` for the self-signed Proxmox certificate. The lab CA comes from a
self-signed cert-manager issuer.

No Proxmox API token, no kubeconfig, no private key and no state is committed. The
Proxmox token is read from `TF_VAR_pve_api_token` in your shell (Tag 8). The RKE2
kubeconfig goes to `~/.kube/rke2-lab.yaml`. The Cloudflare token for the optional
DNS-01 challenge of Tag 9 goes from an environment variable into a cluster secret.

---

## Licence

Code is MIT — see [`LICENSE`](../LICENSE). The text of the book is not covered by that
licence and is not included here.

Kubernetes is a project and trademark of the Linux Foundation. Envoy and Envoy Gateway
are projects of the Cloud Native Computing Foundation. Cilium is a project of the Cloud
Native Computing Foundation. RKE2 is a SUSE / Rancher project. Proxmox is a trademark of
Proxmox Server Solutions GmbH. Docker is a trademark of Docker, Inc. OpenTofu is a
project of the Linux Foundation. This repository is an independent publication and is
not affiliated with, authorized by, or endorsed by any of them.
