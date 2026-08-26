#!/usr/bin/env bash
# Stellt den Zustand her, den die Kapitel-READMEs ab Kapitel 4 als
# Ausgangspunkt annehmen.
#
# Warum es das gibt: Kapitel 3 legt den meridian-Mount im Buch an, und
# ein Leser, der das Buch der Reihe nach durcharbeitet, hat ihn danach.
# Wer nach "make reset" bei einem spaeteren Kapitel einsteigt, hat ihn
# nicht - und bekommt einen 403 auf
# sys/internal/ui/mounts/meridian/..., der wie ein Policy-Problem
# aussieht und keines ist.
#
# Der Mount entstand bisher nur als Nebenwirkung von "|| true"-Zeilen
# in einzelnen Kapitelskripten. Eine Nebenwirkung ist kein
# Ausgangszustand.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
[ -f "$ROOT/.env" ] && source "$ROOT/.env"

: "${VAULT_ADDR:?VAULT_ADDR nicht gesetzt - erst 'source .env'}"
: "${VAULT_TOKEN:?VAULT_TOKEN nicht gesetzt - erst 'source .env'}"

echo "== pruefen =="
if ! vault status >/dev/null 2>&1; then
  echo "  Vault antwortet nicht oder ist versiegelt." >&2
  echo "  Erst: make init && make unseal" >&2
  exit 1
fi
echo "  Vault erreichbar und entsiegelt"

echo "== meridian kv-v2 =="
if vault secrets list -format=json | grep -q '"meridian/"'; then
  echo "  vorhanden"
else
  vault secrets enable -path=meridian -version=2 kv
  echo "  angelegt"
fi

echo "== das Secret aus Kapitel 3 =="
if vault kv get meridian/tracking >/dev/null 2>&1; then
  echo "  vorhanden"
else
  vault kv put meridian/tracking \
    db_user="tracking_svc" \
    db_password="lab-only-not-a-real-password" >/dev/null
  echo "  angelegt"
fi

echo
echo "Ausgangszustand hergestellt. Pruefen mit:"
echo "  vault secrets list"
echo "  vault kv get meridian/tracking"
