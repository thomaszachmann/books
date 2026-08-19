#!/usr/bin/env bash
# What an upgrade will actually do, before you start it.
#
# Harbor migrates forward only. There are no down migrations, so the
# rollback plan is Chapter 22's restore, and that is worth knowing
# before the maintenance window rather than during it.
#
#   ./upgrade-check.sh schema              # where the database is
#   ./upgrade-check.sh migrations [tag]    # every migration file
#   ./upgrade-check.sh pending v2.15.2     # what would run
#   ./upgrade-check.sh certs               # what helm upgrade replaces
#   ./upgrade-check.sh rollback            # the procedure, such as it is
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
DB_CONTAINER="${DB_CONTAINER:-harbor-db}"
DB_NAME="${DB_NAME:-registry}"
DB_USER="${DB_USER:-postgres}"

# The migration files live in the Harbor repo. Reading them there rather
# than shipping a copy means this cannot go stale silently.
list_migrations() {
  TAG="${1:-$(. "$HERE/../../scripts/versions.sh"; echo "$HARBOR_VERSION")}"
  URL="https://api.github.com/repos/goharbor/harbor/contents/make/migrations/postgresql?ref=$TAG"
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" "$URL"
  else
    curl -fsSL "$URL"
  fi | jq -r '.[].name' | sort
}

cmd_migrations() {
  ALL="$(list_migrations "${1:-}")"
  printf '%s\n' "$ALL" | grep '\.up\.sql$' | tail -6
  UP="$(printf '%s\n' "$ALL" | grep -c '\.up\.sql$')"
  DOWN="$(printf '%s\n' "$ALL" | grep -c '\.down\.sql$' || true)"
  echo "up migrations:   $UP"
  echo "down migrations: $DOWN"
  [ "$DOWN" = 0 ] || { echo "down migrations exist now - the book is stale"; exit 1; }
}

cmd_schema() {
  ROW="$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" "$DB_NAME" -tA \
    -c 'SELECT version || " " || dirty FROM schema_migrations' 2>/dev/null \
    || docker exec "$DB_CONTAINER" psql -U "$DB_USER" "$DB_NAME" -tA -F' ' \
       -c 'SELECT version, dirty FROM schema_migrations')"
  VER="${ROW%% *}"; DIRTY="${ROW##* }"
  printf '%-16s %s\n' 'schema version' "$VER"
  printf '%-16s %s\n' 'dirty' "$DIRTY"
  if [ "$DIRTY" = t ] || [ "$DIRTY" = true ]; then
    echo
    echo "A migration did not finish. Read the core log for the original"
    echo "error, then restore Chapter 22's backup. Forcing the version"
    echo "asserts the migration completed, which you cannot know."
    exit 1
  fi
}

# --from lets this run without a database, which is how CI uses it.
cmd_pending() {
  TAG="${1:?a target version, for example v2.15.2}"
  FROM="${FROM:-}"
  if [ -z "$FROM" ]; then
    FROM="$(docker exec "$DB_CONTAINER" psql -U "$DB_USER" "$DB_NAME" -tA \
      -c 'SELECT version FROM schema_migrations')"
  fi
  FROM="$(printf '%s' "$FROM" | tr -d '[:space:]')"
  PENDING="$(list_migrations "$TAG" | grep '\.up\.sql$' | while read -r f; do
    N="${f%%_*}"
    if [ "$((10#$N))" -gt "$((10#$FROM))" ]; then echo "$f"; fi
  done)"
  if [ -z "$PENDING" ]; then
    printf 'no migration files above %04d for %s\n' "$((10#$FROM))" "$TAG"
    echo 'patch upgrade: core will log "No change in schema, skip."'
  else
    echo "would run, in this order:"
    printf '  %s\n' $PENDING
    echo
    echo "downtime: replicas queue on a Postgres advisory lock; they do"
    echo "not migrate concurrently. Plan the window."
  fi
}

# Offline. Two identical renders, and what differs between them is what
# helm upgrade replaces in the cluster.
cmd_certs() {
  CHART_VERSION="${CHART_VERSION:-$(. "$HERE/../../scripts/versions.sh"
    echo "${HARBOR_CHART_VERSION#v}")}"
  A="$(mktemp)"; B="$(mktemp)"
  trap 'rm -f "$A" "$B"' EXIT
  for f in "$A" "$B"; do
    helm template harbor harbor/harbor --version "$CHART_VERSION" \
      --set internalTLS.enabled=true > "$f"
  done
  fail=0
  for k in tls.crt tls.key ca.crt secretKey; do
    VA="$(grep -m1 "^  $k:" "$A" || true)"
    VB="$(grep -m1 "^  $k:" "$B" || true)"
    if [ -z "$VA" ]; then
      printf '%-10s absent\n' "$k"
    elif [ "$VA" = "$VB" ]; then
      printf '%-10s same       taken from values, not generated\n' "$k"
    else
      printf '%-10s REPLACED   regenerated on every upgrade\n' "$k"
    fi
  done
  cat <<'TXT'

Internal certificates are replaced together, so the components still
trust each other. The public one breaks every client that trusted the
old CA - pin it with expose.tls.secretName, or manage the certificate
yourself. secretKey comes straight from the values file: upgrade from a
file that does not carry it and every encrypted credential is lost.
TXT
  exit "$fail"
}

cmd_rollback() {
  cat <<'TXT'
Harbor does not support downgrades.
There are 0 down migrations. helm rollback is not supported.

To go back:
  1  stop Harbor
  2  restore Chapter 22's backup: database, blobs, secrets
  3  reinstall the OLD version against the restored data

Step 3 only works because step 2 restored a database that the old
binary can read. Rolling the image back without the data leaves a
schema newer than the binary, and Harbor migrates forward only.
TXT
}

case "${1:-}" in
  schema)     cmd_schema ;;
  migrations) shift; cmd_migrations "${1:-}" ;;
  pending)    shift; cmd_pending "$@" ;;
  certs)      cmd_certs ;;
  rollback)   cmd_rollback ;;
  *) echo "usage: $0 {schema|migrations|pending|certs|rollback}" >&2; exit 2 ;;
esac
