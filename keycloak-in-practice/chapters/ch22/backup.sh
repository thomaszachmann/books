#!/usr/bin/env bash
# Two backups of the same system, which are not the same thing.
# Chapter 22.
#
#   realm export   the configuration, as JSON, human-readable
#   database dump  the system, including the signing keys
#
# The chapter's whole argument is that only one of them is a backup.
set -euo pipefail

cd "$(dirname "$0")/../.."
OUT=${OUT:-backup}
REALM=${REALM:-meridian}
mkdir -p "$OUT"
STAMP=$(date -u +%Y%m%dT%H%M%SZ)

echo "realm export -> $OUT/realm-$REALM-$STAMP.json"
# kc.sh export is a second Keycloak process beside the running one, and
# it needs the database credential too. From Chapter 20 that is not in
# the environment but in the file Vault Agent renders, so read it if it
# is there. To a single file the users go into the same file; the
# export refuses "realm_file" unless it writes a directory.
# The log goes to a file: on failure it is the only explanation, and a
# backup script that fails quietly is worse than none.
# shellcheck disable=SC2016  # expanded by the shell in the container
if ! docker compose exec -T keycloak sh -c '
    set -a; [ -s /run/vault/db.env ] && . /run/vault/db.env; set +a
    exec /opt/keycloak/bin/kc.sh export --realm "$1" \
      --users same_file --file /tmp/realm.json' export "$REALM" \
    > "$OUT/export-$STAMP.log" 2>&1; then
  echo "realm export failed; the last lines of $OUT/export-$STAMP.log:" >&2
  tail -5 "$OUT/export-$STAMP.log" >&2
  exit 1
fi
docker compose cp "keycloak:/tmp/realm.json" \
  "$OUT/realm-$REALM-$STAMP.json"

echo "database dump  -> $OUT/db-$STAMP.dump"
docker compose exec -T db pg_dump -U keycloak -Fc keycloak \
  > "$OUT/db-$STAMP.dump"

cat <<NEXT

Both written. Before trusting either, answer these from the files
themselves rather than from documentation:

  Are user credentials in the realm export?
    grep -c credentials $OUT/realm-$REALM-$STAMP.json

  Are client secrets, or are they masked?
    grep -o '"secret" : "[^"]*"' $OUT/realm-$REALM-$STAMP.json | head

  Are the realm's signing keys in it?
    grep -c privateKey $OUT/realm-$REALM-$STAMP.json

The answers depend on your version and on the export mode. That is why
this script prints the commands instead of the answers.
NEXT
