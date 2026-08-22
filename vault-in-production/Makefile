.DEFAULT_GOAL := help

help:
	@echo "Vault in Production - lab"
	@echo
	@echo "  make up       three nodes, uninitialised and sealed"
	@echo "  make init     initialise the cluster (once)"
	@echo "  make unseal   unseal all three"
	@echo "  make env      the lines to paste into your shell"
	@echo "  make status   what each node thinks it is"
	@echo "  make down     stop, keep the data"
	@echo "  make reset    stop and delete everything"

up:
	@./scripts/cluster-up.sh

init:
	@./scripts/init-cluster.sh

unseal:
	@./scripts/unseal-cluster.sh

env:
	@echo ". ./scripts/vault-env.sh"

status:
	@for p in 8210 8220 8230; do \
	  printf "  %s  " $$p; \
	  VAULT_ADDR=https://127.0.0.1:$$p VAULT_CACERT=$$PWD/cluster/tls/cert.pem \
	    vault status -format=json 2>/dev/null \
	    | jq -r '"\(.sealed|if . then "sealed  " else "unsealed" end)  \(if .sealed then "-" elif .is_self then "leader" else "standby" end)"' \
	    || echo "no answer"; \
	done

down:
	@./scripts/cluster-down.sh

reset:
	@. ./scripts/engine.sh && $$COMPOSE down -v 2>/dev/null || true
	@rm -rf cluster/data1 cluster/data2 cluster/data3 cluster/init.json logs/*
	@echo "Gone. 'make up' starts over."
