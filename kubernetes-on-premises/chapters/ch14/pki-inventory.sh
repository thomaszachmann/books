#!/usr/bin/env bash
# Jedes zertifikat des clusters, mit aussteller und ablauf.
#
# Ausgabe ist CSV, damit sie in die nachweismappe kann:
#   ./pki-inventory.sh > evidence/ch14/pki-inventory.csv
#
# Was dabei auffaellt und der grund fuer dieses skript ist: es sind
# FUENF eigenstaendige CAs, keine hierarchie. Und es gibt genau
# zwei laufzeiten - 365 tage fuer jedes blatt, 3650 fuer jede CA.
# Beides hat niemand entschieden, es kam mit der distribution.
set -uo pipefail

DIRS="${DIRS:-/var/lib/rancher/rke2/server/tls /var/lib/rancher/rke2/agent}"
SUDO="${SUDO:-sudo}"

x() { $SUDO openssl x509 -in "$1" -noout "$2" 2>/dev/null; }

echo "file,subject,issuer,is_ca,not_after,days"
for d in $DIRS; do
  $SUDO test -d "$d" || continue
  $SUDO find "$d" -maxdepth 2 -name '*.crt' 2>/dev/null | sort | while read -r f; do
    sub=$(x "$f" -subject | sed 's/.*CN *= *//')
    iss=$(x "$f" -issuer  | sed 's/.*CN *= *//')
    nb=$(x "$f" -startdate | cut -d= -f2)
    na=$(x "$f" -enddate   | cut -d= -f2)
    [ -z "$na" ] && continue
    ca=no; $SUDO openssl x509 -in "$f" -noout -text 2>/dev/null \
      | grep -q 'CA:TRUE' && ca=yes
    [ "$sub" = "$iss" ] && iss=self
    days=$(( ( $(date -d "$na" +%s) - $(date -d "$nb" +%s) ) / 86400 ))
    printf '%s,%s,%s,%s,%s,%s\n' \
      "$(basename "$f")" "$sub" "$iss" "$ca" \
      "$(date -d "$na" +%F)" "$days"
  done
done
