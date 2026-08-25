#!/usr/bin/env bash
# Die zertifikatsmetrik, die es nicht gibt.
#
# kube-prometheus-stack bringt 155 alarmregeln mit, acht davon mit
# "certificate" im namen. Gemessen, worauf sie schauen:
#
#   KubeClientCertificateExpiration
#     -> apiserver_client_certificate_expiration_seconds
#        = die zertifikate der CLIENTS, die sich anmelden
#   KubeletClientCertificateExpiration
#     -> kubelet_certificate_manager_client_ttl_seconds
#        = das kubelet-eigene, das ohnehin automatisch rotiert
#
# Nicht abgedeckt: das serverzertifikat des apiservers, die
# etcd-zertifikate, der front-proxy. Also genau die, die kapitel 15
# rotiert und kapitel 16 nicht widerrufen kann. Fuer die gibt es
# ueberhaupt keine metrik - man muss sie selbst erzeugen.
#
# Ausgabe geht in das textfile-verzeichnis des node-exporter. Der
# liest es beim naechsten scrape ein, ohne neustart und ohne dienst.
#
#   ./cert-expiry-exporter.sh            schreibt die .prom-datei
#   ./cert-expiry-exporter.sh --stdout   zeigt sie nur an
#
# Als systemd-timer stuendlich, oder aus cron. Haeufiger lohnt nicht:
# ein zertifikat laeuft nicht zwischen zwei laeufen ab, wenn der
# alarm bei sieben tagen greift.
set -uo pipefail

DIRS="${DIRS:-/var/lib/rancher/rke2/server/tls /var/lib/rancher/rke2/agent}"
OUT="${OUT:-/var/lib/node-exporter/textfile}"
NAME="${NAME:-cert_expiry.prom}"
SUDO="${SUDO:-sudo}"
STDOUT=0; [ "${1:-}" = "--stdout" ] && STDOUT=1

command -v openssl >/dev/null || { echo "fehlt: openssl" >&2; exit 2; }

erzeuge() {
  echo "# HELP cert_expiry_seconds Sekunden bis zum ablauf des zertifikats"
  echo "# TYPE cert_expiry_seconds gauge"
  echo "# HELP cert_expiry_scrape_ok 1 wenn der exporter durchgelaufen ist"
  echo "# TYPE cert_expiry_scrape_ok gauge"
  JETZT=$(date +%s)
  N=0
  for d in $DIRS; do
    $SUDO test -d "$d" || continue
    # -maxdepth 2, weil rke2 die agent-zertifikate eine ebene tiefer
    # ablegt. Tiefer zu suchen findet trust-bundles der distribution.
    for f in $($SUDO find "$d" -maxdepth 2 -name '*.crt' 2>/dev/null | sort); do
      # Bundles enthalten mehrere zertifikate. Fuer die faelligkeit
      # zaehlt das erste - alles andere ist die kette darueber.
      ENDE=$($SUDO openssl x509 -in "$f" -noout -enddate 2>/dev/null \
             | cut -d= -f2)
      [ -z "$ENDE" ] && continue
      TS=$(date -d "$ENDE" +%s 2>/dev/null) || continue
      SUB=$($SUDO openssl x509 -in "$f" -noout -subject 2>/dev/null \
            | sed 's/.*CN *= *//; s/[",\\]//g' | head -c 60)
      CA=$($SUDO openssl x509 -in "$f" -noout -text 2>/dev/null \
           | grep -c "CA:TRUE")
      printf 'cert_expiry_seconds{datei="%s",cn="%s",ca="%s"} %s\n' \
        "$(basename "$f")" "${SUB:-unbekannt}" \
        "$([ "$CA" -gt 0 ] && echo true || echo false)" \
        "$((TS - JETZT))"
      N=$((N+1))
    done
  done
  echo "cert_expiry_count $N"
  echo "cert_expiry_scrape_ok 1"
}

if [ "$STDOUT" = "1" ]; then
  erzeuge
  exit 0
fi

$SUDO test -d "$OUT" || { echo "kein textfile-verzeichnis: $OUT" >&2
  echo "node-exporter braucht --collector.textfile.directory" >&2; exit 1; }

# Auf RHEL-artigen hosts muss das verzeichnis container_file_t sein,
# sonst liest der node-exporter es nicht - und meldet das nur in
# seinem eigenen log und in node_textfile_scrape_error, nicht als
# fehlende datei. Der fehler sieht aus wie "die metrik gibt es nicht".
if command -v getenforce >/dev/null && [ "$(getenforce)" = "Enforcing" ]; then
  KTX=$($SUDO ls -Zd "$OUT" 2>/dev/null | awk '{print $1}')
  case "$KTX" in
    *container_file_t*) ;;
    *) echo "WARNUNG: $OUT hat den SELinux-typ:" >&2
       echo "  $KTX" >&2
       echo "  node-exporter braucht container_file_t. Dauerhaft:" >&2
       echo "  semanage fcontext -a -t container_file_t '$OUT(/.*)?'" >&2
       echo "  restorecon -Rv $OUT" >&2 ;;
  esac
fi

# Atomar schreiben. Der node-exporter liest waehrenddessen, und eine
# halb geschriebene datei ist ein scrape-fehler statt einer luecke.
#
# Die zwischendatei MUSS im zielverzeichnis liegen, aus zwei gruenden:
# mv ist nur innerhalb eines dateisystems atomar, und auf RHEL-artigen
# hosts erbt eine datei aus /tmp den SELinux-typ user_tmp_t. Der
# node-exporter-container darf den nicht lesen und meldet dann
# genau nichts - keine fehlermeldung, nur eine fehlende metrik.
TMP=$($SUDO mktemp "$OUT/.$NAME.XXXXXX")
erzeuge | $SUDO tee "$TMP" >/dev/null
if grep -q "cert_expiry_scrape_ok 1" "$TMP"; then
  $SUDO mv "$TMP" "$OUT/$NAME"
  $SUDO chmod 644 "$OUT/$NAME"
  echo "geschrieben: $OUT/$NAME ($(grep -c '^cert_expiry_seconds' "$OUT/$NAME") zertifikate)"
else
  rm -f "$TMP"
  echo "lauf unvollstaendig, alte datei bleibt stehen" >&2
  exit 1
fi
