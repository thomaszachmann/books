# LLMs auf Kubernetes zum Anfassen — Companion Code

Working code for the labs in **LLMs auf Kubernetes zum Anfassen** by Thomas
Zachmann — a German-language, hands-on training camp for running language
models on Kubernetes: sixteen days (Tag 0–15) and two appendices. Part A
(Tag 1–5) runs on the laptop in kind, with llama.cpp on the CPU, LiteLLM as
the gateway and Open WebUI as the chat. Parts B–D build an RKE2 cluster of
six VMs on Proxmox with OpenTofu and Ansible, pass an NVIDIA GPU through to
one of them, and run vLLM, a production LiteLLM, Open WebUI with Keycloak
and RAG on Qdrant, and a code assistant on it. Tag 15 ends with eight
disaster drills.

> **Status: free edition, October 2026.** The files below are the
> manuscript's `code/` folder, unchanged. The book says it was tested with
> kind 0.33, kubectl 1.37, Helm 4.3 and llama.cpp `server-b11515`. From
> Tag 3 on it marks outputs it did not run live: LiteLLM 1.104.2 and Open
> WebUI 0.11.4 were run against a local proxy and `open-webui serve`, not
> rolled out in kind. Parts B–D (Proxmox, RKE2, GPU) have **not** been run
> end-to-end: the book checked the Proxmox and GPU commands against the
> official documentation and validated the Kubernetes parts with
> `helm template`, `kubeconform` and `kubectl apply --dry-run=server`.
> Book: [PDF](https://github.com/thomaszachmann/books/releases/download/llm-kubernetes-training-2026.10/LLMs-auf-Kubernetes-zum-Anfassen.pdf) · [EPUB](https://github.com/thomaszachmann/books/releases/download/llm-kubernetes-training-2026.10/LLMs-auf-Kubernetes-zum-Anfassen.epub) (free, CC BY-NC-ND 4.0)

> **Auf Deutsch:** Dieses Verzeichnis enthält den Begleitcode zum Buch
> *LLMs auf Kubernetes zum Anfassen* — ein Trainingslager zum Mitmachen mit
> 16 Tagen (Tag 0–15) und zwei Anhängen: erst kind auf dem Laptop, dann
> RKE2 mit sechs VMs auf Proxmox, eine durchgereichte GPU, vLLM, LiteLLM,
> Open WebUI mit Keycloak und RAG, ein Code-Assistent und am Ende acht
> Desaster-Drills. Die Dateien sind der Ordner `code/` aus dem Manuskript,
> unverändert. Proxmox-, GPU- und Cluster-Teile sind laut Buch gegen die
> offizielle Doku geprüft, aber nicht live getestet. Alle Passwörter sind
> Laborwerte; Tokens, Kubeconfigs und Zugangsdaten liegen hier nicht.

> **This repository is not a shortcut.** The book's first rule is *Tippen,
> nicht kopieren* — type every command once yourself. Files the book prints
> in full are meant to be typed; use this copy to check your work and to
> recover when something is broken. Files the book only references or
> excerpts (most of Tag 13 and 14) are meant to be used from here.

---

## The lab lives in `~/ki-lab`, not here

Every path the book prints is under `~/ki-lab`. Tag 0, Drill 3 creates
`~/ki-lab/code` and one directory per day of Part A (`tag01` … `tag05`);
later days add `tag11`, `tag13`, `tag14`, `tag15` and `pruefung`. Tag 0, Drill 3
creates `~/ki-lab/code` and then copies this directory into it:

```bash
git clone https://github.com/thomaszachmann/books.git ~/books 2>/dev/null || git -C ~/books pull
cp -R ~/books/llm-kubernetes-training/code/. ~/ki-lab/code/
```

`cp -R …/code/.` merges into the existing `~/ki-lab/code`. Where a drill writes a file with
`cat > ~/ki-lab/code/… <<'EOF'`, it overwrites the copy with the same
content.

| Here (`code/…`) | Day | In the book |
|---|---|---|
| `kind-lab/` | 1, 2 | `~/ki-lab/code/kind-lab/` — kind cluster `ki-lab`, `up.sh`/`down.sh`/`preload.sh`, namespaces, quota (Tag 1 challenge), the finished `llamacpp.yaml` of Tag 2 |
| `vllm-basics/` | 3 | `~/ki-lab/code/vllm-basics/` — `sizing.py`, GPU manifest template for Tag 11, optional CPU vLLM, production-stack values |
| `litellm/` | 4 (and 14, Drill 5) | `~/ki-lab/code/litellm/` — LiteLLM in kind with Postgres, embedding server, Helm alternative (challenge) |
| `open-webui/` | 5 | `~/ki-lab/code/open-webui/` — chart values for kind, `smoke.sh` |
| `infra-proxmox/host/` | 6 | **On the Proxmox host**, as `/root/01-tofu-user.sh` … `/root/04-gpu-host.sh` |
| `infra-proxmox/` (rest) | 7 (and 15, Szenario 7) | `~/ki-lab/code/infra-proxmox/` — OpenTofu project for the six VMs |
| `infra-rke2/` | 7–10, 15 | `~/ki-lab/code/infra-rke2/` — inventory (Tag 7), Ansible roles and `site.yml` (Tag 8), `platform/` (Tag 9), `nvidia_host` and `gpu.yml` (Tag 10), etcd-to-S3 (Tag 15) |
| `gpu/` | 10 (and 15, Drill 6) | `~/ki-lab/code/gpu/` — GPU Operator values, time-slicing, smoke test, DRA |
| `vllm/` | 11 (and 14, 15, Anhang B) | `~/ki-lab/code/vllm/` — `kv-sizing.py`, `vllm-chat`, ServiceMonitor, KEDA |
| `litellm-prod/` | 12 (and 13, 14) | `~/ki-lab/code/litellm-prod/` — LiteLLM HA with CloudNativePG, Redis, ESO |
| `chat-rag/` | 13 | `~/ki-lab/code/chat-rag/` — `vllm-embed`, Qdrant, Keycloak, Open WebUI, `rag_check.py`, three fictional documents |
| `code-llm/` | 14 (and 13, Drill 2) | `~/ki-lab/code/code-llm/` — `vllm-code`, LiteLLM entries, Continue and Tabby, NetworkPolicies, `code_eval.py` |
| `ops/` | 15 (and Anhang B) | `~/ki-lab/code/ops/` — dashboard generator, alerts, Velero, restore probe, `wettkampf-check.sh` |
| `pruefung/` | Anhang B | The book writes it to `~/ki-lab/pruefung/pruefung.sh` and names `code/pruefung/pruefung.sh` as its source |

Then start with Tag 0 in the book. It installs the tools, sizes Docker,
creates `~/ki-lab` and the Python venv, and checks whether your Proxmox
host can pass a GPU through.

---

## Requirements

Part A needs a laptop with Docker (macOS with Colima or Docker Desktop, or
Linux). Parts B–D need a Proxmox VE 9.x host with IOMMU and an NVIDIA GPU.
The book's hardware assumptions (Vorwort and Tag 0):

| Lab | Minimum | Recommended |
|---|---|---|
| Laptop (Part A) | 4 CPU, 8 GB RAM for Docker, 20 GB free | 6 CPU, 12 GB RAM, 60 GB free |
| Proxmox base (Part B) | 16 cores, 64 GB RAM, 600 GB SSD | DL380 class, 128 GB RAM |
| GPU host (Part C/D) | NVIDIA GPU with 16 GB VRAM, VT-d/IOMMU | L4, RTX 4000 Ada or RTX 4090 |
| Network | one bridge `vmbr0` | own VLAN for Kubernetes |

The six VMs of Tag 7 need 36 vCPU (overcommittable), 88 GB RAM and 580 GB
disk together. Without a GPU you get through Tag 9 completely; Tag 10–15
need the GPU VM.

| Tools | Needed from |
|---|---|
| `docker` (Colima or Docker Desktop), `kind`, `kubectl`, `helm`, `jq`, `curl`, `python3` with venv, `dig` | Tag 0 |
| `kubeconform` | Tag 3 |
| `openssl` | Tag 5 |
| `tofu` (OpenTofu), `ssh-agent` with an ed25519 key | Tag 7 |
| `ansible`, `ansible-lint` | Tag 7, 8 |
| `htpasswd` | Tag 9 (challenge) |
| `bao` and a running OpenBao | Tag 12, Drill 8 (optional) |
| VS Code with Continue (Tabby optional) | Tag 14 |
| `velero` CLI, a second machine with Docker for Garage S3 | Tag 15 |

Accounts and keys you bring yourself: a Hugging Face read token (Tag 11 —
Qwen is not gated, so the secret is optional), a Mistral API key for the
fallback of Tag 12 (a dummy value works; only the fallback drill fails).

See [`VERSIONS.md`](VERSIONS.md) for the versions the book was written
against.

---

## Versions

| Component | Version |
|---|---|
| kind / kubectl / Helm | 0.33 / 1.37 / 4.3 |
| llama.cpp image | `server-b11515` |
| vLLM | v0.31.0 |
| LiteLLM (pip, image, chart) | 1.104.2 |
| Open WebUI / chart | 0.11.4 / 16.6.0 |
| RKE2 | v1.36.4+rke2r1, upgraded to v1.36.5+rke2r1 on Tag 8 |
| NVIDIA GPU Operator | v26.7.1 |
| Velero / chart | 1.18 / 12.2.1 |

Full list with the day each version appears: [`VERSIONS.md`](VERSIONS.md).

---

## Layout

```
README.md  VERSIONS.md  ERRATA.md
code/
  kind-lab/      kind-config, namespaces, up/down/preload,
                 quota, llamacpp.yaml                         Tag 1, 2
  vllm-basics/   sizing.py, vllm-gpu, vllm-cpu, stack values  Tag 3
  litellm/       config, litellm, postgres, llamacpp-embed,
                 values-helm                                  Tag 4
  open-webui/    values-kind, smoke.sh                        Tag 5
  infra-proxmox/ host/01-04 scripts                           Tag 6
                 *.tf, cloud-init/, tfvars example, lock file Tag 7
  infra-rke2/    inventory.yaml                               Tag 7
                 ansible.cfg, group_vars/, roles/rke2_*,
                 site.yml, upgrade/plans.yaml                 Tag 8
                 platform/ (Cilium LB, Traefik, cert-manager,
                 Longhorn, local-path, kube-prometheus-stack) Tag 9
                 roles/nvidia_host, gpu.yml                   Tag 10
  gpu/           operator values, time-slicing, smoke, DRA    Tag 10
  vllm/          kv-sizing.py, vllm-chat, monitoring, KEDA    Tag 11
  litellm-prod/  config, values, CNPG, Redis, ESO             Tag 12
  chat-rag/      vllm-embed, Qdrant, Keycloak, Open WebUI,
                 owui-db, rag_check.py, docs/                 Tag 13
  code-llm/      vllm-code, LiteLLM entries, Continue, Tabby,
                 netpol, code_eval.py                         Tag 14
  ops/           make_dashboard.py, ki-alerts, Velero,
                 backup-test, wettkampf-check.sh              Tag 15
  pruefung/      pruefung.sh                                  Anhang B
```

Anhang A (cheat sheet) creates no files.

---

## How the files were made

All 95 files are the manuscript's `code/` folder, copied unchanged — not
extracted from the chapters and not retyped:

- 63 files are byte-identical to a code block the book prints in full
  (`cat > file <<'EOF'`).
- `kind-lab/namespaces.yaml` is the Tag 1 block plus one header comment.
  `kind-lab/llamacpp.yaml` combines the PVC, Deployment, probes and Service
  of Tag 2 into one file, as the book says at the end of Drill 8.
- 28 the book prints only in part or names by path: everything in
  `chat-rag/` and `code-llm/`, `kind-lab/down.sh` and `preload.sh`,
  `litellm/litellm.yaml`, `postgres.yaml` and `llamacpp-embed.yaml`,
  `vllm-basics/vllm-gpu.yaml` and `vllm-cpu.yaml`,
  `gpu/gpu-operator-driver-values.yaml`, and `ops/ki-alerts.yaml`,
  `velero-values.yaml` and `backup-test.yaml`.
- Two are generated artefacts the book shows: `infra-rke2/inventory.yaml`
  (output of `tofu output -raw ansible_inventory`, Tag 7, Drill 7) and
  `infra-proxmox/.terraform.lock.hcl` (written by `tofu init` for
  `bpg/proxmox` 0.116.0). Your own `tofu init` and Drill 7 overwrite them.
- `code-llm/continue-config.yaml` and `code-llm/tabby-config.toml` hold the
  placeholders `__HOME__` and `__LITELLM_TABBY_KEY__`; Tag 14 renders them
  with `sed`.

**State of the files.** Each file is in the state of the day that
introduces it. Later days edit four of them in place, and those edits are
not in this copy:

| File | Edited on | What the book changes |
|---|---|---|
| `infra-rke2/group_vars/all.yml` | Tag 8, Drill 7; Tag 15, Drill 5 | `rke2_version` to `v1.36.5+rke2r1`; appended etcd-S3 variables |
| `infra-rke2/roles/rke2_server/templates/config.yaml.j2` | Tag 15, Drill 5 | appended `etcd-s3` block |
| `litellm-prod/config.yaml` | Tag 13, Drill 2; Tag 14, Drill 4 | entries `embed` and `code` from `code-llm/litellm-models-code.yaml`, prompt-logging settings |
| `vllm/vllm-chat.yaml` | Tag 14, Drill 2 (checked again in Anhang B) | `--max-model-len=8192`, `--gpu-memory-utilization=0.50`, `--kv-cache-dtype=fp8` |

Nothing is invented. Differences found while comparing the folder with the
chapters are listed in [`ERRATA.md`](ERRATA.md); the code follows the
manuscript anyway.

Left out on purpose:

- `hallo.py` (Tag 0, Drill 6) — the reader writes it into `~/ki-lab/code`.
- The shell helpers `ask` and `askt` that Tag 0 appends to `~/.zshrc`, and
  the day files under `~/ki-lab/tagNN/` (`echo.yaml`, `pvc-test.yaml`,
  `pvc.yaml`, `probes.yaml`, `rag_negativ.py`, `fim.json` and the rendered
  `stack.yaml`, `helm.yaml`, `owui.yaml`).
- Anything that holds a secret or that the labs generate: `pve.env`,
  `rke2-token.env`, the kubeconfig `rke2.yaml`, `lab-ca.crt`,
  `s3-backup.cred`, `oidc-client-secret.txt`, `terraform.tfvars`, plan
  files, OpenTofu state, `ki-plattform.json`, `/etc/garage/garage.toml` on
  the S3 host. [`.gitignore`](.gitignore) keeps them out if you work in
  this directory.
- Secrets the book creates imperatively with `kubectl create secret`
  (`litellm-secrets`, `litellm-pg`, `owui-secrets`, `hf-token`,
  `litellm-env`, `qdrant-auth`, `keycloak-admin`, `tabby-config`,
  `velero-s3`, `longhorn-auth`, …).

---

## Running the scripts

There is no `check.sh` per day: each *Kontrollpunkt* is printed in its
chapter. The scripts here:

- `kind-lab/up.sh` builds the kind cluster idempotently and runs
  `preload.sh`; `PRELOAD=0 ./up.sh` skips the image preload. `down.sh`
  deletes the cluster — and the model cache with it.
- `open-webui/smoke.sh`: `PASS=lab-admin-1234 ./smoke.sh` against
  `http://chat.ki.localtest.me`.
- `vllm-basics/sizing.py`, `vllm/kv-sizing.py`: plain `python3`, they read
  the model's `config.json` from Hugging Face.
- `chat-rag/rag_check.py` and `code-llm/code_eval.py` need the venv from
  Tag 0 (`openai`, plus `qdrant-client` for `rag_check.py`) and the
  environment variables the chapters set (`LITELLM_URL`, `LITELLM_KEY`,
  `QDRANT_URL`, `QDRANT_API_KEY`, `SSL_CERT_FILE`).
- `chat-rag/keycloak-setup.sh` prints the OIDC client secret on stdout; Tag
  13 redirects it into `oidc-client-secret.txt`.
- `ops/wettkampf-check.sh` ends every scenario of Tag 15;
  `pruefung/pruefung.sh` needs `PRUEF_KEY` (Anhang B). Both expect the
  kubeconfig at `~/ki-lab/rke2.yaml`.

---

## Safety

Everything here is for a lab and is **not** safe for production as it
stands. All passwords and keys in the book and in these files are lab
values — among them `sk-lab-master-1234`, `sk-lab-salt-1234`,
`lab-pg-1234`, `lab-redis-1234`, `lab-admin-1234`, `lab-grafana-1234`,
`lab-qdrant-key-1234`, `lab-kc-admin-1234`, the Keycloak users
`lab-<name>-1234` and the RKE2 fallback token `rke2-lab-token-1234`. The
book's rule: *Lab-Werte bleiben im Lab*; real tokens (`HF_TOKEN`, API keys)
come only from environment variables or secrets.

Deliberate lab shortcuts the book marks as such: `--kubelet-insecure-tls`
for metrics-server in kind, `pve_insecure = true` for the self-signed
Proxmox certificate, Keycloak in dev mode, a self-signed lab CA whose key
lives in the cluster, and Ingress-NGINX in kind, which upstream
discontinued in March 2026. The LiteLLM fallback of Tag 12 sends prompts to
the Mistral API — outside your network; Tag 12's challenge shows how to
switch it off per key.

No token, kubeconfig or credential file is committed; the labs create them
in `~/ki-lab`.

---

## Licence

Code is MIT — see [`LICENSE`](../LICENSE). The text of the book is not
covered by that licence and is not included here.

Kubernetes is a registered trademark of the Linux Foundation; OpenTofu is
a project of the Linux Foundation. Proxmox is a trademark of Proxmox Server
Solutions GmbH. NVIDIA is a trademark of NVIDIA Corporation. Docker is a
trademark of Docker, Inc. This repository is an independent publication
and is not affiliated with, authorized by, or endorsed by any of them or by
the other projects and vendors it uses.
