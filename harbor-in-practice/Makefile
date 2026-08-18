# Harbor in Practice - companion lab
SHELL := /bin/bash

.PHONY: help check install diagnose teardown vm-up vm-shell vm-down \
        ch01 ch02 ch03 reset kind-up kind-down mk-up mk-down harbor-up \
        harbor-down \
        vault-up versions

help:
	@echo "Harbor in Practice - lab targets"
	@echo ""
	@echo "  make check      verify required tools are installed"
	@echo "  make install    show how to install what is missing"
	@echo "  make versions   print the pinned versions"
	@echo "  make diagnose   work out why the lab is misbehaving"
	@echo "  make teardown   remove the VM, both clusters, everything"
	@echo ""
	@echo "  Chapter 1"
	@echo "  make ch01       the plain registry, and moving a tag"
	@echo ""
	@echo "  Chapter 2"
	@echo "  make ch02       certificates for the registry"
	@echo "  make reset      wipe Harbor data, keep VM and certs"
	@echo ""
	@echo "  Chapter 3"
	@echo "  make ch03       verify the installer before running it"
	@echo ""
	@echo "  Chapters 2 and 3 - the virtual machine"
	@echo "  make vm-up      launch the Multipass VM"
	@echo "  make vm-shell   shell into it"
	@echo "  make vm-down    stop it, keeping the disk"
	@echo ""
	@echo "  Chapter 15 - Kubernetes"
	@echo "  make kind-up    kind cluster with ingress ports mapped"
	@echo "  make mk-up      minikube profile (needs 'minikube tunnel')"
	@echo "  make harbor-up  install the Harbor chart"
	@echo ""
	@echo "  Part VI"
	@echo "  make vault-up   bring up Vault beside Harbor"

check:
	@./scripts/check-prereqs.sh

install:
	@./scripts/install.sh

versions:
	@grep -E '^[A-Z_]+=' VERSIONS.md

diagnose:
	@./scripts/diagnose.sh

teardown:
	@./scripts/teardown.sh

ch01:
	@cd chapters/ch01 && ./plain-registry.sh && ./move-tag.sh

ch02:
	@test -n "$(IP)" || (echo "usage: make ch02 IP=192.168.64.7"; exit 2)
	@./chapters/ch02/make-certs.sh $(IP)

ch03:
	@./chapters/ch03/verify-installer.sh offline

reset:
	@./scripts/reset-lab.sh

vm-up:
	@./scripts/vm-up.sh

vm-shell:
	@multipass shell $$(grep -E '^VM_NAME=' VERSIONS.md | cut -d= -f2)

vm-down:
	@multipass stop $$(grep -E '^VM_NAME=' VERSIONS.md | cut -d= -f2)

kind-up:
	@kind create cluster --config k8s/kind/kind-cluster.yaml
	@echo "Now install an ingress controller. Chapter 15, step 3."

kind-down:
	@kind delete cluster --name harbor-lab

mk-up:
	@minikube start -p harbor-lab --cpus 4 --memory 8192
	@minikube addons enable ingress -p harbor-lab
	@echo "Leave 'minikube tunnel -p harbor-lab' running in another shell."

mk-down:
	@minikube delete -p harbor-lab

harbor-up:
	@echo "Arrives with Chapter 15."
	@false

harbor-down:
	@helm uninstall harbor -n harbor || true

vault-up:
	@echo "Arrives with Chapter 18. See vault/README.md."
	@false
