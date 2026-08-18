# Vault in Practice - companion lab
SHELL := /bin/bash

.PHONY: help check tls up down restart reset init unseal env status db-up db-down clean

help:
	@echo "Vault in Practice - lab targets"
	@echo ""
	@echo "  make check     verify required tools are installed"
	@echo "  make tls       generate the self-signed certificate"
	@echo "  make up        start Vault"
	@echo "  make init      initialise (writes init.json)"
	@echo "  make unseal    unseal using init.json"
	@echo "  make env       print shell exports"
	@echo "  make status    vault status"
	@echo "  make db-up     start PostgreSQL (Chapter 10)"
	@echo "  make restart   restart Vault (it comes back sealed)"
	@echo "  make reset     DESTROY all data and start over"
	@echo "  make down      stop everything"

check:
	@./scripts/check-prereqs.sh

tls:
	@./tls/generate-certs.sh

up:
	@docker compose -f docker-compose.yml up -d vault
	@./scripts/wait-for-vault.sh

down:
	@docker compose -f docker-compose.yml down

restart:
	@docker compose -f docker-compose.yml restart vault
	@./scripts/wait-for-vault.sh

reset:
	@./scripts/reset-lab.sh

init:
	@./scripts/init-vault.sh

unseal:
	@./scripts/unseal-vault.sh

env:
	@echo "export VAULT_ADDR='https://127.0.0.1:8200'"
	@echo "export VAULT_CACERT='$(PWD)/tls/vault-cert.pem'"
	@if [ -f init.json ]; then \
	  echo "export VAULT_TOKEN='$$(jq -r .root_token init.json)'"; \
	fi

status:
	@VAULT_ADDR=https://127.0.0.1:8200 \
	 VAULT_CACERT=$(PWD)/tls/vault-cert.pem \
	 vault status || true

db-up:
	@docker compose -f docker-compose.yml up -d postgres
	@echo "PostgreSQL is starting. Chapter 10 continues from here."

db-down:
	@docker compose -f docker-compose.yml stop postgres

clean: down
	@rm -rf data/* logs/* init.json
	@echo "Cleaned."
