#!/usr/bin/env bash
# The three things Harbor can tell you, and the gaps between them.
#
# Metrics answer "how much". Webhooks answer "something happened", for
# ten of the fourteen event topics. The audit log answers "who did
# that", including the four deletions no webhook covers.
#
#   ./observe.sh endpoints    # what metrics.enabled turns on
#   ./observe.sh events       # the ten, and the four without a webhook
#   ./observe.sh inventory    # exporter: projects, quotas, queues
#   ./observe.sh traffic      # core: requests by operation and code
#   ./observe.sh audit        # forwarding, and whether it is reachable
#
# events reads Harbor's source rather than a copy, so it cannot go
# stale quietly. It is what CI checks.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
API="$HERE/../../scripts/harbor-api.sh"

fetch() {
  URL="https://raw.githubusercontent.com/goharbor/harbor/$1/$2"
  curl -fsSL "$URL"
}

# Reads the port and path out of the rendered chart rather than
# printing what this script believes them to be.
cmd_endpoints() {
  CHART="${CHART_VERSION:-$(. "$HERE/../../scripts/versions.sh"
    echo "${HARBOR_CHART_VERSION#v}")}"
  R="$(helm template harbor harbor/harbor --version "$CHART" \
       --set metrics.enabled=true 2>/dev/null)"
  PORT="$(printf '%s' "$R" | grep -m1 'METRIC_PORT' \
          | sed 's/.*: *//; s/"//g')"
  PATH_="$(printf '%s' "$R" | grep -m1 'METRIC_PATH' \
           | sed 's/.*: *//; s/"//g')"
  SM=disabled
  printf '%s' "$R" | grep -q 'kind: ServiceMonitor' && SM=enabled

  printf '%-12s :%s%-9s %s\n' \
    core       "$PORT" "$PATH_" "traffic: http_request_total, duration" \
    registry   "$PORT" "$PATH_" "distribution's own metrics" \
    jobservice "$PORT" "$PATH_" "task_total, task_process_time_seconds" \
    exporter   "$PORT" "$PATH_" "inventory: projects, quotas, queues"
  printf '%-12s %-16s %s\n' \
    serviceMonitor "$SM" "needs monitoring.coreos.com/v1"
  cat <<'TXT'

metrics.enabled is false by default and turns on all four at once.
TXT
}

# Nineteen topics exist; ten of them can drive a webhook. The nine
# that cannot are the creations and deletions people want alerts on,
# plus COMMON_API, which is how everything else reaches the audit log.
cmd_events() {
  TAG="${1:-$(. "$HERE/../../scripts/versions.sh"; echo "$HARBOR_VERSION")}"
  ALL="$(fetch "$TAG" src/controller/event/topic.go \
    | grep -oE 'Topic[A-Za-z]+ += +"[A-Z_]+"' \
    | sed -E 's/.*"([A-Z_]+)"/\1/' | sort -u)"
  HOOKED="$(fetch "$TAG" src/pkg/notification/notification.go \
    | sed -n '/eventTypes := \[\]string{/,/}/p' \
    | grep -oE 'event\.Topic[A-Za-z]+' | sed 's/event\.//' \
    | while read -r c; do
        fetch "$TAG" src/controller/event/topic.go \
          | grep -oE "$c += +\"[A-Z_]+\"" | sed -E 's/.*"([A-Z_]+)"/\1/'
      done | sort -u)"
  echo "webhook events:  $(printf '%s\n' "$HOOKED" | grep -c .)"
  printf '  %s\n' $HOOKED
  echo
  echo "no webhook, audit log only:"
  MISSING="$(comm -23 <(printf '%s\n' "$ALL") <(printf '%s\n' "$HOOKED"))"
  printf '  %s\n' $MISSING
}

cmd_inventory() {
  URL="${EXPORTER_URL:?the exporter metrics URL, for example
    http://127.0.0.1:8001/metrics}"
  curl -fsS "$URL" | grep -E '^harbor_(up|health|project_|statistics_|task_)' \
    | grep -v '^#'
}

cmd_traffic() {
  URL="${CORE_METRICS_URL:?the core metrics URL}"
  curl -fsS "$URL" | grep '^harbor_core_http_request_total' | sort -t' ' -k2 -rn \
    | head -15
}

# Forwarding is syslog over TCP, and a failed dial falls back to stdout
# after one error line. With skip_audit_log_database on, that is the
# whole audit trail going to container logs.
cmd_audit() {
  CFG="$("$API" GET /configurations)"
  EP="$(printf '%s' "$CFG" | jq -r '.audit_log_forward_endpoint.value // ""')"
  SKIP="$(printf '%s' "$CFG" | jq -r '.skip_audit_log_database.value // false')"
  PULL="$(printf '%s' "$CFG" | jq -r '.pull_audit_log_disable.value // false')"
  printf '%-28s %s\n' audit_log_forward_endpoint "${EP:-<none>}"
  printf '%-28s %s\n' skip_audit_log_database "$SKIP"
  printf '%-28s %s\n' pull_audit_log_disable "$PULL"
  [ -n "$EP" ] || { echo "not forwarding; the database is the record"; exit 0; }
  HOST="${EP%%:*}"; PORT="${EP##*:}"
  if nc -z -w3 "$HOST" "$PORT" 2>/dev/null; then
    printf '%-28s %s\n' reachable yes
  else
    printf '%-28s %s\n' reachable NO
    echo "   audit records are going to core's stdout instead."
    if [ "$SKIP" = true ]; then
      echo "   skip_audit_log_database is on: nowhere else has them."
    fi
    exit 1
  fi
}

case "${1:-}" in
  endpoints) cmd_endpoints ;;
  events)    shift; cmd_events "${1:-}" ;;
  inventory) cmd_inventory ;;
  traffic)   cmd_traffic ;;
  audit)     cmd_audit ;;
  *) echo "usage: $0 {endpoints|events|inventory|traffic|audit}" >&2; exit 2 ;;
esac
