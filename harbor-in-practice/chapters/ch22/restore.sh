#!/usr/bin/env bash
# Restore what backup.sh took, and check the things a restore does not
# fix by itself.
#
#   ./restore.sh /backup/today
#   ./restore.sh /backup/today --wrong-key     # to see what losing the key costs
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
  WRONG_KEY=
  [ "${1:-}" = --wrong-key ] && WRONG_KEY=1

  if [ -n "$WRONG_KEY" ]; then
    # Harbor does not start without the files under /data/secret at
    # all - they are bind-mounted. The quiet failure needs a key that
    # is present and different, which is what a fresh install or a
    # backup script that forgot the file gives you.
    echo "restoring with a DIFFERENT secret key - Chapter 22 step 5." >&2
    echo "Harbor will start. Everything encrypted with the old key -" >&2
    echo "endpoint credentials, LDAP bind, OIDC secrets - will not decrypt." >&2
  elif ! "$HERE/backup.sh" verify "$DIR"; then
    if [ -n "${FORCE_BAD_BACKUP:-}" ]; then
      echo "restoring anyway - FORCE_BAD_BACKUP is set." >&2
      echo "Chapter 22 step 4. Do not do this to anything you need." >&2
    else
      echo "refusing to restore a backup that does not verify" >&2
      echo "FORCE_BAD_BACKUP=1 to override, and read Chapter 22 first." >&2
      exit 2
    fi
  fi

  ( cd "$HARBOR_DIR" && docker compose down )

  echo "config"
  for f in harbor.yml docker-compose.yml; do
    [ -f "$DIR/$f" ] && cp "$DIR/$f" "$HARBOR_DIR/"
  done
  # harbor.yml is the source; everything under common/config is
  # rendered from it. Render again so that nginx, core and the compose
  # file agree - a config from before a change (metrics, say) and a
  # rendered tree from after it leaves nginx looping on a missing
  # upstream. Same flags as the install: a plain prepare drops Trivy.
  ( cd "$HARBOR_DIR" && ./prepare ${PREPARE_FLAGS:---with-trivy} >/dev/null )

  echo "blobs"
  rm -rf "${DATA:?}/registry"
  tar -C "$DATA" -xf "$DIR/registry.tar"

  echo "secrets"
  tar -C "$DATA" -xf "$DIR/secret.tar"
  if [ -n "$WRONG_KEY" ]; then
    cp "$DATA/secret/keys/secretkey" "$DIR/secretkey.original"
    printf '%s' "$(openssl rand -hex 8)" > "$DATA/secret/keys/secretkey"
    echo "  secretkey replaced; the original is in $DIR/secretkey.original"
  fi

  # Postgres must be up to be restored into, and Harbor must not be.
  echo "database"
  # The compose service is 'postgresql'; harbor-db is only the container name.
  ( cd "$HARBOR_DIR" && docker compose up -d postgresql )
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
  '')    echo "usage: $0 <backup-dir> [--wrong-key] | check" >&2; exit 2 ;;
  *)     cmd_restore "$@" ;;
esac
