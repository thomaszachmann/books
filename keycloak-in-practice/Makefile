# Keycloak in Practice - lab targets.
# Every target is something a chapter asks you to run. `make help` lists
# them; `make check` tells you whether this machine is ready.

SHELL := /bin/bash
COMPOSE := docker compose
KCADM := $(COMPOSE) exec -T keycloak /opt/keycloak/bin/kcadm.sh
REALM ?= meridian

-include VERSIONS.mk
export          # so docker compose sees the pins

.DEFAULT_GOAL := help

.PHONY: help
help:  ## List the targets
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

VERSIONS.mk: VERSIONS.md
	@grep -E '^[A-Z_]+=' $< > $@

.PHONY: check
check:  ## Verify this machine has what the book needs
	@bash chapters/check.sh

.PHONY: pki
pki:  ## Chapter 2: root CA and the server certificate
	@bash chapters/ch02/make-certs.sh

# docker compose interpolates from the shell and from .env, and reads
# neither VERSIONS.md nor VERSIONS.mk. `export` above covers make; this
# target covers a reader who types docker compose directly, which the
# book does from Chapter 3.
# Phony on purpose. As a file target with .env.example as a
# prerequisite, make skips it whenever .env already exists and is newer
# - which is exactly what happens when a reader follows the front matter
# and types `cp .env.example .env` first. The pins are then never
# appended, docker compose interpolates empty strings, and the failure
# arrives later as an image with no tag. The recipe is idempotent, so
# running it every time costs nothing.
.PHONY: env
env:  ## Create .env and append the pinned versions to it
	@[ -f .env ] || cp .env.example .env
	@grep -q '^# --- pinned' .env || { \
	  printf '\n# --- pinned versions, from VERSIONS.md. Do not edit. ---\n' \
	    >> .env; \
	  grep -E '^[A-Z_]+=' VERSIONS.md >> .env; \
	  echo "appended pinned versions to .env"; }

.PHONY: up
up: env pki  ## Start the database and Keycloak
	$(COMPOSE) up -d db keycloak client

.PHONY: down
down:  ## Remove the containers, keep the data
	$(COMPOSE) --profile ad --profile ch01 --profile vault down

.PHONY: clean
clean:  ## Remove the containers AND the data. Keeps pki/
	$(COMPOSE) --profile ad --profile ch01 --profile vault down -v
	@rm -f VERSIONS.mk tokens.json assertion.xml authn.xml req.enc

.PHONY: clean-pki
clean-pki:  ## Also throw away the CA. Four trust stores to redo
	rm -rf pki

.PHONY: ad-up
ad-up: env  ## Chapter 2 step 8, and Chapters 12 to 14
	$(COMPOSE) --profile ad up -d --build dc client
	@echo "The first start provisions the domain and takes a minute."

.PHONY: ad-down
ad-down:  ## Put the directory away again
	$(COMPOSE) --profile ad stop dc

.PHONY: kcadm-init
kcadm-init:  ## Chapter 3 step 6: truststore, then log the CLI in
	$(COMPOSE) exec -T keycloak keytool -importcert \
	  -alias meridian-root -noprompt \
	  -file /opt/keycloak/conf/ca.crt \
	  -keystore /opt/keycloak/conf/truststore.jks \
	  -storepass changeit 2>/dev/null || true
	$(KCADM) config truststore --trustpass changeit \
	  /opt/keycloak/conf/truststore.jks
	@echo "Now: make kcadm-login"

.PHONY: kcadm-login
kcadm-login:  ## Authenticate the admin CLI (prompts for the password)
	$(COMPOSE) exec keycloak /opt/keycloak/bin/kcadm.sh \
	  config credentials --server $(KC_HOSTNAME) \
	  --realm master --user $${KC_BOOTSTRAP_ADMIN_USERNAME:-admin}

.PHONY: realm
realm:  ## Chapter 3 step 7: create the realm
	$(KCADM) create realms -f - < realms/$(REALM).json

.PHONY: realm-reset
realm-reset:  ## Delete the realm and import it again
	-$(KCADM) delete realms/$(REALM)
	$(MAKE) realm

.PHONY: vault-up
vault-up: env  ## Part V: bring Vault up beside Keycloak
	$(COMPOSE) --profile vault up -d vault
	@echo "Vault: http://localhost:8200  root token: root"

.PHONY: vault-down
vault-down:  ## Put Vault away again
	$(COMPOSE) --profile vault stop vault

.PHONY: ch01
ch01: env  ## Chapter 1: three applications, three user databases
	$(COMPOSE) --profile ch01 up -d
