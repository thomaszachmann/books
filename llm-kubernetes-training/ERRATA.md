# Errata

Differences between the book and the code in this directory, and between
the book and later releases of the software. Each entry names the day, the
step, and what to do instead.

The files here were copied **unchanged** from the manuscript's `code/`
folder; nothing was improved on the way.

## Corrections made while extracting

None. The files were copied unchanged from the manuscript's `code/` folder.

`hallo.py` (Tag 0, Drill 6) is not included on purpose: the reader writes
it with `cat > ~/ki-lab/code/hallo.py`.

## Differences between the chapters and `code/`

Found while comparing the folder with the chapters. The code follows the
manuscript; nothing was changed.

1. **Tag 1, Drill 2** — `kind-lab/namespaces.yaml` has one header comment
   that the printed block does not have. Otherwise identical.
2. **Tag 6** — the book writes the host scripts to `/root/01-tofu-user.sh`
   … `/root/04-gpu-host.sh` on the Proxmox host and runs them there. Here
   they are in `infra-proxmox/host/`, as the chapter says; copy them to the
   host, they do not belong in `~/ki-lab/code` on the laptop.
3. **Anhang B** — the book writes `pruefung.sh` to
   `~/ki-lab/pruefung/pruefung.sh`; here it is `pruefung/pruefung.sh`
   (the book names that path as the source).
4. **Tag 8, 14, 15** — four files are in the state of the day that
   introduces them; the in-place edits of later days are not in them
   (`infra-rke2/group_vars/all.yml`,
   `infra-rke2/roles/rke2_server/templates/config.yaml.j2`,
   `litellm-prod/config.yaml`, `vllm/vllm-chat.yaml`). See
   [`README.md`](README.md#how-the-files-were-made).
5. **Tag 1 / Tag 11** — Tag 1 says the same namespaces are used on RKE2
   later, and `namespaces.yaml` calls itself "Teil A und Teil B-D
   identisch". On RKE2 the book never applies it: Tag 11 to 14 create
   `ki-models`, `ki-gateway`, `ki-chat` and `ki-code` with
   `kubectl create namespace`,
   without the `ki-lab/layer` labels. Nothing in `code/` selects on those
   labels, so either way works.

## Fixed in the manuscript (2026-10-10)

The book was corrected before this release; the PDF and EPUB in the release contain the fixes.

1. **Tag 0, Drill 3** — names this repository as the source of the
   companion code and shows how to copy it to `~/ki-lab/code`. Before,
   it only said "aus dem Begleitmaterial". It also no longer claims that
   the chapters print every file in full; 28 files are only excerpted.
2. **Tag 3, Drill 5** — says that `vllm-basics/vllm-cpu.yaml` uses the
   x86 image `vllm/vllm-openai-cpu:v0.31.0` and that on an ARM Mac you
   change the `image:` line to `v0.31.0-arm64` first.

## Open

None reported yet.

## Format

**Tag N, Drill M** — since `<component> <version>`, `<what changed>`.
The step as printed reads `<old>`; use `<new>` instead.
