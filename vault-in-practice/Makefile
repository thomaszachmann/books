# Vault in Practice - companion lab
SHELL := /bin/bash

.PHONY: help check install diagnose teardown tls up down restart reset seed init unseal env status db-up db-down clean

help:
	@echo "Vault in Practice - lab targets"
	@echo ""
	@echo "  make check     verify required tools are installed"
	@echo "  make install   show how to install what is missing"
	@echo "  make diagnose  work out why the lab is misbehaving"
	@echo "  make teardown  remove everything, including clusters"
	@echo "  make tls       generate the self-signed certificate"
	@echo "  make up        start Vault"
	@echo "  make init      initialise (writes .env)"
	@echo "  make unseal    unseal using .env"
	@echo "  make env       print shell exports"
	@echo "  make status    vault status"
	@echo "  make db-up     start PostgreSQL (Chapter 10)"
	@echo "  make restart   restart Vault (it comes back sealed)"
	@echo "  make reset     DESTROY all data and start over"
	@echo "  make seed      create the state chapters after 3 assume"
	@echo "  make down      stop everything"

check:
	@./scripts/check-prereqs.sh

install:
	@./scripts/install.sh

diagnose:
	@./scripts/diagnose.sh

teardown:
	@./scripts/teardown.sh

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

seed:
	@./scripts/seed-lab.sh

init:
	@./scripts/init-vault.sh

unseal:
	@./scripts/unseal-vault.sh

env:
	@echo "export VAULT_ADDR='https://127.0.0.1:8200'"
	@echo "export VAULT_CACERT='$(PWD)/tls/vault-cert.pem'"
	@if [ -f .env ]; then \
	  echo "source .env"; \
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
	@rm -rf data/* logs/* .env
	@echo "Cleaned."
