#!/usr/bin/env bash
# Restore what backup.sh took, and check the things a restore does not
# fix by itself.
#
#   ./restore.sh /backup/today
#   ./restore.sh /backup/today --skip-secret   # to see what that costs
#   ./restore.sh check
#
# The restore refuses a backup that does not pass verify. A backup you
# cannot verify is not a backup you should restore onto a live machine.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
DATA="${HARBOR_DATA:-/data}"
HARBOR_DIR="${HARBOR_DIR:-/opt/harbor}"
API="$HERE/../../scripts/harbor-api.sh"

# Three of these are named in Harbor's own Velero limitations. The
# fourth is one you set yourself in step 1 and nothing unsets.
cmd_check() {
  printf '%-22s %s\n' 'read_only' \
    "$("$API" GET /configurations | jq -r '.read_only.value')"
  echo "  must be false before anyone can push again"
  echo
  echo "expected after a restore that skipped Redis:"
  echo "  every session ended            - people log in again"
  echo "  tasks stuck 'in progress'      - stop them in the portal"
  echo "  pull counts moved backwards    - held in memory, synced late"
  echo
  echo "prove the blobs, not just the database:"
  echo "  docker pull <repo>@sha256:<digest recorded before the backup>"
  echo "  a tag proves the database; only a digest proves the blobs"
}

cmd_restore() {
  DIR="${1:?a backup directory}"; shift || true
  SKIP_SECRET=
  [ "${1:-}" = --skip-secret ] && SKIP_SECRET=1

  if [ -n "$SKIP_SECRET" ]; then
    echo "restoring WITHOUT $DATA/secret - Chapter 22 step 4." >&2
    echo "Harbor will start. Replication, proxy cache, LDAP bind and" >&2
    echo "OIDC credentials will not decrypt." >&2
  else
    "$HERE/backup.sh" verify "$DIR" || {
      echo "refusing to restore a backup that does not verify" >&2; exit 2; }
  fi

  ( cd "$HARBOR_DIR" && docker compose down )

  echo "config"
  for f in harbor.yml docker-compose.yml; do
    [ -f "$DIR/$f" ] && cp "$DIR/$f" "$HARBOR_DIR/"
  done

  echo "blobs"
  rm -rf "${DATA:?}/registry"
  tar -C "$DATA" -xf "$DIR/registry.tar"

  if [ -z "$SKIP_SECRET" ]; then
    echo "secrets"
    tar -C "$DATA" -xf "$DIR/secret.tar"
  fi

  # Postgres must be up to be restored into, and Harbor must not be.
  echo "database"
  ( cd "$HARBOR_DIR" && docker compose up -d harbor-db )
  until docker exec harbor-db pg_isready -U postgres >/dev/null 2>&1; do
    sleep 1
  done
  docker exec -i harbor-db psql -U postgres -c \
    'DROP DATABASE IF EXISTS registry' >/dev/null
  docker exec -i harbor-db psql -U postgres -c \
    'CREATE DATABASE registry' >/dev/null
  docker exec -i harbor-db psql -U postgres registry < "$DIR/database.sql" >/dev/null

  ( cd "$HARBOR_DIR" && docker compose up -d )
  echo
  echo "up. now run: $0 check"
}

case "${1:-}" in
  check) cmd_check ;;
  '')    echo "usage: $0 <backup-dir> [--skip-secret] | check" >&2; exit 2 ;;
  *)     cmd_restore "$@" ;;
esac
