#!/usr/bin/env bash
# Schickt Requests im Dauerlauf und zählt Statuscodes (Tag 12).
# Aufruf: drain-test.sh [url] [sekunden]   000 = Verbindungsfehler
set -uo pipefail
url="${1:-http://ha.apps.lab.internal/}"; dur="${2:-60}"
end=$((SECONDS + dur))
while [ $SECONDS -lt $end ]; do
  curl -s -o /dev/null -w '%{http_code}\n' --max-time 2 "$url"
  sleep 0.05
done | sort | uniq -c
