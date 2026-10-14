#!/usr/bin/env bash
# Rehearse an upgrade against a copy of production. Chapter 23.
#
# The schema migration is one-way. There is no downgrade, so the only
# rollback is a database restore - which means the rehearsal is not
# optional, it is the only place you find out how long the outage is.
#
#   ./rehearse.sh backup/db-<stamp>.dump [target-version]
#
# The target defaults to KEYCLOAK_UPGRADE_VERSION in VERSIONS.md. The
# copy stays behind as database 'rehearsal', migrated, for Step 4.
set -euo pipefail

cd "$(dirname "$0")/../.."
DUMP=${1:?usage: rehearse.sh backup/db-<stamp>.dump [target-version]}
eval "$(grep -E '^KEYCLOAK_(UPGRADE_)?VERSION=' VERSIONS.md)"
TARGET=${2:-$KEYCLOAK_UPGRADE_VERSION}
NAME=keycloak-rehearsal
mkdir -p backup
LOG=backup/rehearsal-$TARGET.log
env_of() { grep "^$1=" .env | cut -d= -f2-; }

echo "rehearsing $KEYCLOAK_VERSION -> $TARGET against a copy of $DUMP"

# 1. Ask the new version whether a rolling update is possible. The
#    running server describes itself; the new image judges the
#    description. Exit 0 means rolling, 3 means stop everything first.
# shellcheck disable=SC2016  # expanded by the shell in the container
docker compose exec -T keycloak sh -c '
    set -a; [ -s /run/vault/db.env ] && . /run/vault/db.env; set +a
    exec /opt/keycloak/bin/kc.sh update-compatibility metadata \
      --file=/tmp/compat.json' >/dev/null 2>&1
docker compose cp keycloak:/tmp/compat.json backup/compat.json 2>/dev/null
rc=0
docker run --rm -v "$PWD/backup/compat.json:/tmp/compat.json:ro" \
  "quay.io/keycloak/keycloak:$TARGET" \
  update-compatibility check --file=/tmp/compat.json \
  > backup/compat-check.log 2>&1 || rc=$?
case $rc in
  0) echo "  compatibility: rolling update possible" ;;
  3) echo "  compatibility: rolling update NOT possible - plan downtime"
     grep -o "'[^']*' is incompatible: [^]]*" backup/compat-check.log \
       | sort -u | sed 's/^/    /' ;;
  *) echo "  compatibility: check failed ($rc), see backup/compat-check.log" ;;
esac

# 2. A copy of the database, restored from the dump.
pg() { docker compose exec -T db psql -U keycloak -d postgres -qc "$1"; }
pg 'DROP DATABASE IF EXISTS rehearsal;'
pg 'CREATE DATABASE rehearsal;'
docker compose exec -T db pg_restore -U keycloak -d rehearsal < "$DUMP"
echo "  copy restored as database 'rehearsal'"

# 3. Start the new version against the copy and time it.
#    KC_CACHE=local is not decoration. The copy holds the production
#    nodes' addresses in its JDBC_PING table, and a clustered rehearsal
#    tries to join production with them.
NET=$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' \
      "$(docker compose ps -q db)")
docker rm -f "$NAME" >/dev/null 2>&1 || true
start=$(date +%s)
docker run -d --name "$NAME" --network "$NET" \
  -e KC_DB=postgres \
  -e KC_DB_URL=jdbc:postgresql://db:5432/rehearsal \
  -e KC_DB_USERNAME="$(env_of POSTGRES_USER)" \
  -e KC_DB_PASSWORD="$(env_of POSTGRES_PASSWORD)" \
  -e KC_HOSTNAME=https://sso.meridian.test \
  -e KC_HTTP_ENABLED=true -e KC_PROXY_HEADERS=xforwarded \
  -e KC_CACHE=local \
  "quay.io/keycloak/keycloak:$TARGET" start >/dev/null

echo "  waiting for the migration and the start"
until docker logs "$NAME" 2>&1 | grep -q 'Listening on'; do
  if [ "$(docker inspect -f '{{.State.Running}}' "$NAME")" != true ]; then
    docker logs "$NAME" > "$LOG" 2>&1
    docker rm -f "$NAME" >/dev/null
    echo "  the new version exited - read $LOG" >&2
    exit 1
  fi
  sleep 1
done
end=$(date +%s)
docker logs "$NAME" > "$LOG" 2>&1
docker rm -f "$NAME" >/dev/null

echo
echo "start to ready: $((end - start))s, of which:"
grep -E 'Updating database|Migrating older model|started in' "$LOG" \
  | sed -E 's/^[0-9-]+ ([0-9:]+),[0-9]+ +[A-Z]+ +\[[^]]*\] \(main\) /  \1  /
            s/ on JVM .* started in / started in /; s/\. Listening on.*//
            s/\. Using changelog.*//'
echo
echo "deprecation warnings in this upgrade:"
grep -iE 'deprecat|will be removed|renamed' "$LOG" \
  | sed 's/^/  /' | sort -u | head -20 || echo "  none found"
echo
echo "Full log: $LOG. The migrated copy is database 'rehearsal'."
