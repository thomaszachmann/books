#!/usr/bin/env bash
# Rehearse an upgrade against a copy of production. Chapter 23.
#
# The schema migration is one-way. There is no downgrade, so the only
# rollback is a database restore - which means the rehearsal is not
# optional, it is the only place you find out how long the outage is.
set -euo pipefail

cd "$(dirname "$0")/../.."
DUMP=${1:?usage: rehearse.sh backup/db-<stamp>.dump [target-version]}
TARGET=${2:-}
[ -n "$TARGET" ] || TARGET=$(grep '^KEYCLOAK_VERSION=' VERSIONS.md | cut -d= -f2)

echo "rehearsing upgrade to $TARGET against a copy of $DUMP"

docker compose exec -T db psql -U keycloak -d postgres \
  -c 'DROP DATABASE IF EXISTS rehearsal;' >/dev/null
docker compose exec -T db psql -U keycloak -d postgres \
  -c 'CREATE DATABASE rehearsal;' >/dev/null
docker compose exec -T db pg_restore -U keycloak -d rehearsal < "$DUMP"
echo "  copy restored"

start=$(date +%s)
docker run --rm --network "$(docker compose ps -q db >/dev/null \
    && docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' \
       "$(docker compose ps -q db)")" \
  -e KC_DB=postgres \
  -e KC_DB_URL="jdbc:postgresql://db:5432/rehearsal" \
  -e KC_DB_USERNAME="$(grep '^POSTGRES_USER=' .env | cut -d= -f2)" \
  -e KC_DB_PASSWORD="$(grep '^POSTGRES_PASSWORD=' .env | cut -d= -f2)" \
  -e KC_HOSTNAME=https://sso.meridian.test \
  -e KC_HEALTH_ENABLED=true \
  "quay.io/keycloak/keycloak:$TARGET" \
  start --optimized=false --http-enabled=true 2>&1 \
  | tee /tmp/rehearsal.log &
PID=$!

echo "  waiting for the migration to finish"
until grep -qiE 'listening on|running the server in development' \
      /tmp/rehearsal.log 2>/dev/null; do
  sleep 2
  kill -0 $PID 2>/dev/null || { echo "  the server exited"; break; }
done
end=$(date +%s)
kill $PID 2>/dev/null || true

echo
echo "migration window: $((end - start))s"
echo
echo "deprecation warnings in this upgrade:"
grep -iE 'deprecat|will be removed|renamed' /tmp/rehearsal.log \
  | sed 's/^/  /' | sort -u | head -20 || echo "  none found"
echo
echo "The copy is still there as database 'rehearsal'. Drop it when done."
