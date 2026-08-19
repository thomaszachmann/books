#!/usr/bin/env bash
# Back up Harbor's four stores, in an order that can be defended.
#
# Two independent stores snapshotted at different moments leave a gap.
# Database first means the gap holds orphan blobs, which the next
# garbage collection removes. Blobs first means the gap holds database
# rows whose blobs are missing, which is an artifact that lists and
# cannot be pulled. So: database first, then blobs.
#
#   ./backup.sh plan
#   ./backup.sh quiesce            # read-only ON, GC schedule OFF
#   ./backup.sh run /backup/today
#   ./backup.sh verify /backup/today
#   ./backup.sh unquiesce
#
# verify works offline against a backup directory and is what CI runs.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
DATA="${HARBOR_DATA:-/data}"
HARBOR_DIR="${HARBOR_DIR:-/opt/harbor}"
API="$HERE/../../scripts/harbor-api.sh"

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

cmd_plan() {
  cat <<'TXT'
1  read_only = true
     Blocks pushes. Does NOT block garbage collection: job callbacks
     are on the read-only middleware's skip list.
2  garbage collection schedule = None, and no execution running
     GC deletes blobs. A GC inside the window breaks the backup in
     exactly the way the ordering rule is meant to prevent.
3  database        pg_dump, or a cold copy of /data/database
4  blobs           /data/registry, or the bucket
5  secrets         /data/secret  - the AES key lives here and is not
                   in the database. Without it, replication, proxy
                   cache, LDAP bind and OIDC credentials never decrypt.
6  config          harbor.yml, docker-compose.yml
7  manifest.json   what was taken, and when, so verify can check the
                   order without trusting the operator's memory.
8  read_only = false
TXT
}

cmd_quiesce() {
  "$API" PUT /configurations -d '{"read_only": true}' >/dev/null
  RO="$("$API" GET /configurations | jq -r '.read_only.value')"
  printf '%-16s %s\n' 'read_only' "$RO"
  SCHED="$("$API" GET /system/gc/schedule | jq -r '.schedule.type // "None"')"
  printf '%-16s %s\n' 'gc schedule' "$SCHED"
  RUNNING="$("$API" GET /system/gc | jq '[.[] | select(.job_status
    == "Running" or .job_status == "Pending")] | length')"
  printf '%-16s %s running\n' 'gc executions' "$RUNNING"
  [ "$RO" = true ]      || { echo "read_only did not take"; exit 1; }
  [ "$SCHED" = None ]   || { echo "disable the GC schedule first"; exit 1; }
  [ "$RUNNING" = 0 ]    || { echo "a GC is in flight; wait for it"; exit 1; }
}

cmd_unquiesce() {
  "$API" PUT /configurations -d '{"read_only": false}' >/dev/null
  echo "read_only false"
}

cmd_run() {
  DIR="${1:?a backup directory}"; shift || true
  ORDER=db-first
  [ "${1:-}" = --order ] && { ORDER="${2:?db-first or blobs-first}"; }
  if [ "$ORDER" = blobs-first ] && [ -z "${FORCE_WRONG_ORDER:-}" ]; then
    echo "refusing: blobs-first leaves the database referencing blobs" >&2
    echo "that are not in this backup. See Chapter 22." >&2
    exit 2
  fi
  mkdir -p "$DIR"

  do_db() {
    DB_START="$(now)"
    echo "database   pg_dump registry"
    docker exec harbor-db pg_dump -U postgres registry > "$DIR/database.sql"
    DB_END="$(now)"
  }
  do_blobs() {
    BLOB_START="$(now)"
    echo "blobs      $DATA/registry"
    # _uploads holds in-progress uploads that the registry purges on a
    # schedule. Copying it races with that purge and restores nothing.
    tar -C "$DATA" --exclude='registry/docker/registry/v2/repositories/*/_uploads' \
        -cf "$DIR/registry.tar" registry
    BLOB_END="$(now)"
  }

  if [ "$ORDER" = db-first ]; then do_db; do_blobs; else do_blobs; do_db; fi

  echo "secrets    $DATA/secret"
  tar -C "$DATA" -cf "$DIR/secret.tar" secret
  echo "config     harbor.yml, docker-compose.yml"
  for f in harbor.yml docker-compose.yml; do
    [ -f "$HARBOR_DIR/$f" ] && cp "$HARBOR_DIR/$f" "$DIR/"
  done

  jq -n --arg o "$ORDER" \
        --arg ds "$DB_START" --arg de "$DB_END" \
        --arg bs "$BLOB_START" --arg be "$BLOB_END" \
    '{order: $o,
      database: {file: "database.sql", started_at: $ds, finished_at: $de},
      blobs:    {file: "registry.tar", started_at: $bs, finished_at: $be},
      secrets:  {file: "secret.tar"}}' > "$DIR/manifest.json"
  echo "manifest   $DIR/manifest.json"
}

# Offline. A backup you have not verified is a hypothesis.
cmd_verify() {
  DIR="${1:?a backup directory}"
  fail=0
  ok()  { printf 'ok    %s\n' "$*"; }
  bad() { printf 'FAIL  %s\n' "$*"; fail=1; }

  M="$DIR/manifest.json"
  [ -f "$M" ] || { echo "FAIL  no manifest.json"; exit 1; }

  for f in database.sql registry.tar secret.tar; do
    if [ -s "$DIR/$f" ]; then ok "$f present"; else bad "$f missing or empty"; fi
  done
  if [ -f "$DIR/harbor.yml" ]; then ok "harbor.yml present"
  else bad "harbor.yml missing - the restore has to guess the config"; fi

  # The AES key is a file, not a database row. Everything encrypted with
  # it is unrecoverable without it, and Harbor starts anyway.
  if tar -tf "$DIR/secret.tar" 2>/dev/null | grep -q 'secret/keys/secretkey'; then
    ok "secretkey present"
  else
    bad "secretkey missing - replication, proxy cache, LDAP and OIDC"
    printf '      %s\n' "credentials will not decrypt after a restore"
  fi

  DE="$(jq -r '.database.finished_at' "$M")"
  BS="$(jq -r '.blobs.started_at' "$M")"
  if [ "$DE" = null ] || [ "$BS" = null ]; then
    bad "manifest has no timestamps; the order cannot be checked"
  elif [[ "$DE" > "$BS" ]]; then
    bad "order: the database finished at $DE, after the blobs started"
    printf '      %s\n' "at $BS - the database may reference missing blobs"
  else
    ok "order: database finished before blobs started"
  fi

  exit "$fail"
}

case "${1:-plan}" in
  plan)      cmd_plan ;;
  quiesce)   cmd_quiesce ;;
  unquiesce) cmd_unquiesce ;;
  run)       shift; cmd_run "$@" ;;
  verify)    shift; cmd_verify "$@" ;;
  *) echo "usage: $0 {plan|quiesce|run|verify|unquiesce}" >&2; exit 2 ;;
esac
