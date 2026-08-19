#!/usr/bin/env bash
# Assert what a rendered Harbor release actually does, not what the
# values file was supposed to say.
#
# Helm does not reject value names it has never heard of, so a --set can
# be accepted and ignored. The only way to know a setting took effect is
# to read the manifest it produced.
#
#   helm template harbor harbor/harbor --version 1.19.2 \
#     -f my-values.yaml > release.yaml
#   ./render-check.sh release.yaml
#   MAX_CONNS=200 ./render-check.sh release.yaml
#
# Reads stdin if no file is given. Exits non-zero on any failure.
set -euo pipefail

SRC="${1:--}"
MANIFEST="$(cat -- "$SRC")"
MAX_CONNS="${MAX_CONNS:-1024}"

fail=0
ok()   { printf 'ok    %s\n' "$*"; }
bad()  { printf 'FAIL  %s\n' "$*"; fail=1; }
note() { printf '      %s\n' "$*"; }

# Replicas for one component, from its Deployment or StatefulSet.
replicas_of() {
  printf '%s' "$MANIFEST" | awk -v c="$1" '
    /^---/            { indoc = 0; comp = "" }
    $0 ~ "component: " c { comp = c }
    /^  replicas:/    { if (comp == c) { print $2; exit } }
  '
}

# The volume source for a named volume, as one word.
volume_kind() {
  printf '%s' "$MANIFEST" | awk -v v="$1" '
    $0 ~ "^      - name: " v "$" { hit = 1; next }
    hit { gsub(/[: ]/, "", $1); print $1; exit }
  '
}

value_of() {
  printf '%s' "$MANIFEST" | grep -m1 -E "^  $1:" | sed 's/.*: *//; s/"//g'
}

# 1. Blobs. An emptyDir is right for object storage and catastrophic for
#    filesystem storage, and the rendered YAML looks the same either way,
#    so decide it on the registry config instead.
REG_REPLICAS="$(replicas_of registry)"
REG_VOL="$(volume_kind registry-data)"
STORAGE="$(value_of REGISTRY_STORAGE_PROVIDER_NAME)"
if [ "$STORAGE" = filesystem ]; then OBJECT_STORE=no; else OBJECT_STORE=yes; fi
case "$REG_VOL:$OBJECT_STORE" in
  emptyDir:yes) ok "registry: ${STORAGE} storage, no volume needed" ;;
  emptyDir:no)  bad "registry: emptyDir with filesystem storage"
                note "blobs do not survive a pod restart" ;;
  persistentVolumeClaim:*)
    if [ "${REG_REPLICAS:-1}" -gt 1 ]; then
      bad "registry: ${REG_REPLICAS} replicas share one PVC"
      note "use object storage, or a ReadWriteMany class"
    else
      ok "registry: one replica on a PVC"
    fi ;;
  *) bad "registry: could not determine the volume for registry-data" ;;
esac

# 2. Job logs. The file logger writes to a volume; the database logger
#    does not. Two replicas and a ReadWriteOnce claim is the Multi-Attach
#    failure from this chapter.
JS_REPLICAS="$(replicas_of jobservice)"
JS_VOL="$(volume_kind job-logs)"
JS_MODE="$(printf '%s' "$MANIFEST" \
  | awk '/name: harbor-jobservice$/{h=1} h && /ReadWrite/{print $2; exit}')"
if [ "$JS_VOL" = emptyDir ]; then
  ok "jobservice: logs are not on a shared volume"
elif [ "${JS_REPLICAS:-1}" -gt 1 ] && [ "$JS_MODE" != "ReadWriteMany" ]; then
  bad "jobservice: ${JS_REPLICAS} replicas, job log claim is ${JS_MODE:-unset}"
  note "set jobservice.jobLoggers[0]=database, or ReadWriteMany at"
  note "persistence.persistentVolumeClaim.jobservice.jobLog.accessMode"
else
  ok "jobservice: log volume matches the replica count"
fi

# 3. Connections. maxOpenConns is per pod and covers core and exporter.
CORE_REPLICAS="$(replicas_of core)"
OPEN="$(value_of POSTGRESQL_MAX_OPEN_CONNS)"
EXPORTER_REPLICAS="$(replicas_of exporter)"
if [ -n "$OPEN" ]; then
  PODS=$(( ${CORE_REPLICAS:-1} + ${EXPORTER_REPLICAS:-0} ))
  TOTAL=$(( PODS * OPEN ))
  if [ "$TOTAL" -gt "$MAX_CONNS" ]; then
    bad "database: ${PODS} pods x ${OPEN} = ${TOTAL} > ${MAX_CONNS}"
    note "lower database.maxOpenConns or raise max_connections"
  else
    ok "database: ${PODS} pods x ${OPEN} = ${TOTAL} <= ${MAX_CONNS}"
  fi
else
  bad "database: POSTGRESQL_MAX_OPEN_CONNS not found in the manifest"
fi

# 4. Scan throughput. The adapter's queue worker defaults to 1 and the
#    chart does not expose it, so more jobservice workers only lengthen
#    the queue.
TRIVY_REPLICAS="$(replicas_of trivy)"
CONC="$(printf '%s' "$MANIFEST" \
  | grep -A1 'SCANNER_JOB_QUEUE_WORKER_CONCURRENCY' \
  | grep -m1 'value:' | sed 's/.*: *//; s/"//g' || true)"
ok "trivy: ${TRIVY_REPLICAS:-0} replicas x ${CONC:-1} concurrent scans"

exit "$fail"
