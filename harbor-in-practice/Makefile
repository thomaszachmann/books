# Harbor in Practice - companion lab
SHELL := /bin/bash

.PHONY: help check install diagnose teardown vm-up vm-shell vm-down \
        ch01 ch02 ch03 ch04 ch05 ch06 ch07 ch08 ch09 ch10 ch11 ch12 \
        ch13 ch14 ch15 ch16 ch17 ch18 ch19 ch20 ch21 ch22 \
        reset \
        kind-up \
        kind-down \
        mk-up \
        mk-down \
        harbor-up \
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
	@echo "  Chapter 4"
	@echo "  make ch04       walk the token dance by hand"
	@echo ""
	@echo "  Chapter 5"
	@echo "  make ch05       seed members, then probe the boundaries"
	@echo ""
	@echo "  Chapter 6"
	@echo "  make ch06       list robots expiring within 14 days"
	@echo ""
	@echo "  Chapter 7"
	@echo "  make ch07       can auth_mode still be changed?"
	@echo ""
	@echo "  Chapter 8"
	@echo "  make ch08       what a tag actually serves"
	@echo ""
	@echo "  Chapter 9"
	@echo "  make ch09       what would be refused under prevent_vul"
	@echo ""
	@echo "  Chapter 10"
	@echo "  make ch10       which artifacts carry a signature"
	@echo ""
	@echo "  Chapter 11"
	@echo "  make ch11       what the last garbage collection did"
	@echo ""
	@echo "  Chapter 12"
	@echo "  make ch12       quota usage, and what the numbers hide"
	@echo ""
	@echo "  Chapter 13"
	@echo "  make ch13 SRC=.. DST=..   what replication did not copy"
	@echo ""
	@echo "  Chapter 14"
	@echo "  make ch14       can the proxy caches actually serve?"
	@echo ""
	@echo "  Chapters 15 and 16"
	@echo "  make ch15       trust the CA on every node"
	@echo "  make ch16       which namespaces hold a pull secret"
	@echo ""
	@echo "  Chapter 17"
	@echo "  make ch17       is this installation actually HA-ready?"
	@echo ""
	@echo "  Chapter 18"
	@echo "  make ch18       the chart secret hooks and their key names"
	@echo ""
	@echo "  Chapter 19"
	@echo "  make ch19 NS=apps   check a namespace pull secret"
	@echo ""
	@echo "  Chapter 20"
	@echo "  make ch20 REF=hashivault://harbor-signing   check the reference"
	@echo ""
	@echo "  Chapter 21"
	@echo "  make ch21       render k8s/values-ha.yaml and check it"
	@echo ""
	@echo "  Chapter 22"
	@echo "  make ch22            the backup plan"
	@echo "  make ch22 DIR=/backup/today   verify a backup"
	@echo ""
	@echo "  Chapters 2 and 3 - the virtual machine"
	@echo "  make vm-up      launch the Multipass VM"
	@echo "  make vm-shell   shell into it"
	@echo "  make vm-down    stop it, keeping the disk"
	@echo ""
	@echo "  Chapter 15 - Kubernetes"
	@echo "  make kind-up    kind cluster with ingress ports mapped"
	@echo "  make kind-down  remove it"
	@echo "  make mk-up      minikube profile (needs 'minikube tunnel')"
	@echo "  make mk-down    remove it"
	@echo "  make harbor-up  install the chart with your own cert"
	@echo "  make harbor-down  uninstall it"
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

ch04:
	@./chapters/ch04/token-dance.sh

ch05:
	@./chapters/ch05/seed-members.sh
	@./chapters/ch05/probe-permissions.sh

ch06:
	@./chapters/ch06/expiring-robots.sh 14

ch07:
	@./chapters/ch07/check-auth-mode.sh

ch08:
	@./chapters/ch08/index-children.sh
	@./chapters/ch08/untagged.sh

ch09:
	@./chapters/ch09/severity.sh
	@./chapters/ch09/unscanned.sh

ch10:
	@./chapters/ch10/signed-artifacts.sh

ch11:
	@./chapters/ch11/gc-status.sh

ch12:
	@./chapters/ch12/quota-report.sh

ch13:
	@test -n "$(SRC)" -a -n "$(DST)" || \
	  (echo "usage: make ch13 SRC=platform DST=mirror"; exit 2)
	@./chapters/ch13/replication-gap.sh $(SRC) $(DST)

ch14:
	@./chapters/ch14/cache-health.sh

ch15:
	@./chapters/ch15/node-trust.sh kind harbor-lab

ch16:
	@./chapters/ch16/find-pull-secrets.sh

ch17:
	@./chapters/ch17/ha-readiness.sh k8s/values-harbor.yaml

ch18:
	@./chapters/ch18/secret-keys.sh

ch19:
	@test -n "$(NS)" || (echo "usage: make ch19 NS=apps"; exit 2)
	@./chapters/ch19/dockerconfig.sh check $(NS)

ch20:
	@./chapters/ch20/vault-signing.sh ref \
	  $(if $(REF),$(REF),hashivault://harbor-signing)
	@echo ""
	@./chapters/ch20/vault-signing.sh env || true

ch21:
	@. ./scripts/versions.sh; \
	  helm template harbor harbor/harbor \
	    --version "$${HARBOR_CHART_VERSION#v}" \
	    -f k8s/values-ha.yaml > /tmp/harbor-release.yaml
	@./chapters/ch21/render-check.sh /tmp/harbor-release.yaml

ch22:
	@if [ -n "$(DIR)" ]; then \
	  ./chapters/ch22/backup.sh verify "$(DIR)"; \
	else \
	  ./chapters/ch22/backup.sh plan; \
	fi

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
	@./chapters/ch15/install-chart.sh

harbor-down:
	@helm uninstall harbor -n harbor || true

vault-up:
	@echo "Arrives with Chapter 18. See vault/README.md."
	@false
