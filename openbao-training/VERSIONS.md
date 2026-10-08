# Versions

The versions *OpenBao zum Anfassen* was written against, as the book
states them. Nothing here is pinned by a script. The book asks you to
install current tools (Homebrew or the official release pages, Tag 0) and
to check `bao version` first when an output differs.

## OpenBao

| Component | Version | Day |
|---|---|---|
| `bao` CLI | 2.7.1 | 0 |
| Dev server (`bao server -dev`) | 2.7.1 (the CLI binary) | 1–6, 13 (self-init) |
| Cluster image `quay.io/openbao/openbao` | **2.7.0** | 8–11 |
| Cluster image after the rolling upgrade | **2.7.1** | 12 |
| Agent image of the injector (`injector.agentImage.tag`) | 2.7.0, then 2.7.1 | 11, 12 |
| Unsealer image (`bao-unsealer`) | 2.7.0 — stays there | 10 |
| Snapshot CronJob image | 2.7.0 as printed; the book says to raise it after Tag 12 | 12 |
| Helm chart `openbao/openbao` | **0.30.2** (app version v2.7.1) | 8–14 |
| Injector image (chart default) | `docker.io/hashicorp/vault-k8s:1.7.2` | 11, 12 |

The chart's default would be 2.7.1 everywhere. The values files pin 2.7.0
on purpose, so that Tag 12 has a real upgrade. `day12/values-2.7.1.yaml` is
the state after that upgrade.

## Tools

| Tool | Expectation in the book | Day |
|---|---|---|
| `helm` | v3 or v4; the book's output shows v4.1.1 | 0, 8 |
| `kind` | the book's output shows v0.32.0 | 0, 7 |
| `kubectl` | the book's output shows v1.36.3 | 0, 7 |
| `jq` | the book's output shows 1.8.2 | 0 |
| Docker | the book's output shows 29.2.1 | 0, 4, 7 |
| OpenSSL | **3.x**; Tag 14, Szenario 7 needs **≥ 3.4** (`x509 -not_before/-not_after`) | 7, 14 |
| OpenTofu | any current `tofu`; provider `hashicorp/vault` `~> 5.0` (the book's drift test names 5.12) | 13 |
| External Secrets Operator | current chart, API `external-secrets.io/v1` | 11 |

macOS ships LibreSSL as `/usr/bin/openssl` (3.3.6 on the test machine). It
rejects `-addext` (Tag 7, Drill 3), `-verify_hostname` and `-verify_ip`
(Tag 7, Drill 5) and `-not_before` (Tag 14, Szenario 7). Tag 0 installs
`openssl@3` and puts it first on the `PATH`; its Kontrollpunkt checks for
OpenSSL 3.

## Images the labs pull

| Image | Tag in the book | Day |
|---|---|---|
| `postgres` | `16` | 4 |
| `quay.io/openbao/openbao` | `2.7.0`, `2.7.1` | 8–14 |
| `busybox` | `1.36` | 11 |
| kind node image | kind's default | 7 |

## How this was checked

| Check | Result |
|---|---|
| `bash -n` on every `.sh`, `zsh -n` on the two `.zsh` fragments | all pass |
| YAML / JSON parse | all pass |
| `bao policy fmt` (2.7.1) on a copy of every policy | all 17 valid; seven are not in `fmt` layout (one-line blocks in `bao-admin.hcl` and `wettkampf.hcl`, aligned `=`) — left as printed |
| `helm template openbao openbao/openbao --version 0.30.2` with every values file | all render; service names `openbao`, `openbao-active`, `openbao-standby`, `openbao-internal`, ConfigMap `openbao-config`, `updateStrategy: OnDelete` |
| Unsealer config from the rendered ConfigMap, `bao` 2.7.1 | starts on pebbledb, init 1/1, transit key and periodic orphan token as on Tag 10 |
| Raft config of Tag 8 from the rendered ConfigMap, local single node with the book's lab CA | starts sealed (exit 2), init 5/3, unseal, Raft leader |
| Raft config of Tag 12 (2.7.1) with the transit seal against the local unsealer | init with recovery keys, seal type `transit`, audit devices `stdout/` and `datei/`, unauthenticated metrics, restart auto-unseals, snapshot holds `meta.json state.bin SHA256SUMS SHA256SUMS.sealed` |
| Self-init config of Tag 13 | static seal, initialised, `admin` logs in with `bao-admin` |
| Tag 14 on a local Raft node in Tag 13's state (policy `bao-admin`, OpenTofu applied as `admin`) | `vorbereitung.sh` and the `bao` steps of Szenarien 4, 5, 6 and 8 run as `wettkampf`; Szenario 5's `-force` restore into a fresh node, then login and `kv get`; `tofu plan -detailed-exitcode` exits 0 after Szenario 6 and after the clean-up |
| Tag 14, Szenario 7 with OpenSSL 3.6.4 and Tag 7's `openbao.ext` | expired certificate carries all ten SANs, `Verify return code: 10`; renewed certificate verifies for `openbao-2.openbao-internal` after `SIGHUP` |
| `tofu validate` on `tofu/main.tf`, with and without the challenge fragment | valid |
| `kubeconform` on `agent-pod.yaml`, `cronjob.yaml`, ESO manifests | valid |

For the local runs, ports, file paths and the transit address were
rewritten in a scratch copy and `service_registration "kubernetes"` was
dropped. Nothing was run in a Kubernetes cluster.
