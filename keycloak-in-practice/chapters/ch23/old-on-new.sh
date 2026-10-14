#!/usr/bin/env bash
# Start the version you are running against the copy rehearse.sh
# migrated. Chapter 23, Step 4.
#
# The question is what a "rollback by redeploying the old image" does.
# The answer is printed as the old server's own warnings, and as the
# HTTP status of its discovery document once it is up.
set -euo pipefail

cd "$(dirname "$0")/../.."
eval "$(grep -E '^KEYCLOAK_VERSION=' VERSIONS.md)"
OLD=${1:-$KEYCLOAK_VERSION}
NAME=keycloak-old-on-new
env_of() { grep "^$1=" .env | cut -d= -f2-; }

docker compose exec -T db psql -U keycloak -d postgres -Atc \
  "select 1 from pg_database where datname = 'rehearsal'" | grep -q 1 \
  || { echo "no database 'rehearsal' - run rehearse.sh first" >&2; exit 1; }

NET=$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' \
      "$(docker compose ps -q db)")
docker rm -f "$NAME" >/dev/null 2>&1 || true
echo "starting $OLD against the migrated copy"
docker run -d --name "$NAME" --network "$NET" \
  -e KC_DB=postgres \
  -e KC_DB_URL=jdbc:postgresql://db:5432/rehearsal \
  -e KC_DB_USERNAME="$(env_of POSTGRES_USER)" \
  -e KC_DB_PASSWORD="$(env_of POSTGRES_PASSWORD)" \
  -e KC_HOSTNAME=https://sso.meridian.test \
  -e KC_HTTP_ENABLED=true -e KC_PROXY_HEADERS=xforwarded \
  -e KC_CACHE=local \
  "quay.io/keycloak/keycloak:$OLD" start >/dev/null

until docker logs "$NAME" 2>&1 | grep -q 'Listening on'; do
  if [ "$(docker inspect -f '{{.State.Running}}' "$NAME")" != true ]; then
    echo "it refused to start:"; docker logs "$NAME" 2>&1 | tail -5
    docker rm -f "$NAME" >/dev/null; exit 0
  fi
  sleep 1
done
docker logs "$NAME" 2>&1 | grep -E ' (WARN|ERROR) ' \
  | sed -E 's/^.*\(main\) //' | fold -s -w 68 | sed 's/^/  /'
code=$(docker compose exec -T client curl -sS -o /dev/null -w '%{http_code}' \
  "http://$NAME:8080/realms/meridian/.well-known/openid-configuration")
echo "  it is up, and serves the realm: HTTP $code"
docker rm -f "$NAME" >/dev/null
