#!/usr/bin/env bash
# Restore from the database dump. Chapter 22.
#
# This is the one that brings back the signing keys, and therefore the
# one that leaves previously issued tokens valid.
set -euo pipefail

cd "$(dirname "$0")/../.."
DUMP=${1:?usage: restore.sh backup/db-<stamp>.dump}

echo "stopping keycloak so nothing writes during the restore"
docker compose stop keycloak

echo "dropping and recreating the database"
docker compose exec -T db psql -U keycloak -d postgres \
  -c 'DROP DATABASE IF EXISTS keycloak;'
docker compose exec -T db psql -U keycloak -d postgres \
  -c 'CREATE DATABASE keycloak;'

echo "restoring"
docker compose exec -T db pg_restore -U keycloak -d keycloak < "$DUMP"

echo "starting keycloak"
docker compose start keycloak

cat <<'NEXT'

Restored. Now decide, deliberately, what to do about sessions: the dump
contained them, so people who were logged in at backup time are logged
in again - including anybody who was logged out since. Chapter 22 says
why clearing them is usually the right default.
NEXT
