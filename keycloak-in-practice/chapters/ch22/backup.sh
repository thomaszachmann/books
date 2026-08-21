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
docker compose exec -T keycloak /opt/keycloak/bin/kc.sh export \
  --realm "$REALM" --users realm_file \
  --file "/tmp/realm.json" >/dev/null 2>&1
docker compose cp "keycloak:/tmp/realm.json" \
  "$OUT/realm-$REALM-$STAMP.json"

echo "database dump  -> $OUT/db-$STAMP.sql"
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
