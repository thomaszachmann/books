#!/usr/bin/env bash
# Stop the lab and delete its state.
#
# Warum das nicht einfach "rm -rf cluster/data*" ist:
#
# Vault legt cluster/dataN/raft im Container an, als der Benutzer
# "vault" (UID 100), mit Modus 0700. Auf dem Host gehoert das
# Verzeichnis dann irgendeinem fremden Konto - auf Ubuntu zeigt
# "stat" dort "dhcpcd" - und der aufrufende Benutzer darf es weder
# betreten noch loeschen:
#
#   rm: cannot remove 'cluster/data1/raft': Permission denied
#
# Vorher brach make reset genau hier ab. Das Tueckische daran war
# nicht der Fehler, sondern was er hinterliess: init.json war schon
# geloescht, die Raft-Verzeichnisse nicht. "make up && make init"
# lief danach auf altem Zustand weiter und das Labor verhielt sich
# unerklaerlich.
#
# Geloescht wird deshalb aus einem Wegwerf-Container heraus, der als
# root laeuft und dieselben Verzeichnisse gemountet bekommt. Das
# braucht kein sudo auf dem Host und funktioniert unter Docker wie
# unter rootful podman.
set -euo pipefail

cd "$(dirname "$0")/.."
. ./scripts/engine.sh

$COMPOSE down -v >/dev/null 2>&1 || true

TARGETS="data1 data2 data3 init.json"

# Schneller Weg: was dem Host-Benutzer gehoert, ist gleich weg.
for t in $TARGETS; do rm -rf "cluster/$t" 2>/dev/null || true; done
rm -rf logs/* 2>/dev/null || true

# Was uebrig ist, gehoert dem Container. Aus einem Container loeschen.
leftover=""
for t in $TARGETS; do [ -e "cluster/$t" ] && leftover="$leftover $t"; done

if [ -n "$leftover" ]; then
  $ENGINE run --rm \
    -v "$PWD/cluster:/reset${VAULT_MOUNT_OPT:-}" \
    docker.io/library/alpine:3.20 \
    sh -c 'cd /reset && rm -rf data1 data2 data3 init.json' \
    >/dev/null 2>&1 || true
fi

# Laut scheitern statt halb aufraeumen.
still=""
for t in $TARGETS; do [ -e "cluster/$t" ] && still="$still cluster/$t"; done

if [ -n "$still" ]; then
  echo "reset unvollstaendig, uebrig:$still" >&2
  echo "Das Labor ist jetzt in einem gemischten Zustand - 'make up'" >&2
  echo "wuerde auf altem Raft-Zustand weiterlaufen. Von Hand mit" >&2
  echo "erhoehten Rechten entfernen, dann erneut versuchen." >&2
  exit 1
fi

echo "Gone. 'make up' starts over."
