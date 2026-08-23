#!/usr/bin/env bash
# Blatt-rotation, mit dem beweis dass sie stattgefunden hat.
#
# Der beweis ist die seriennummer. "certificate check" sagt nur
# datumsangaben; ob wirklich rotiert wurde, sieht man daran, dass
# die serials sich geaendert haben.
#
# WICHTIG zum ablauf: 'rke2 certificate rotate' ERSETZT die
# zertifikate nicht - es LOESCHT sie und ueberlaesst die neuerzeugung
# dem naechsten start. Zwischen befehl und neustart laeuft der knoten
# aus dem speicher, und auf der platte liegt nichts. Ein ungeplanter
# reboot in diesem fenster erzeugt die zertifikate zu einem zeitpunkt,
# den niemand gewaehlt hat. Deshalb rotiert dieses skript UND startet
# neu, in einem lauf.
set -uo pipefail

D="${D:-/var/lib/rancher/rke2/server/tls}"
WATCH="${WATCH:-client-admin.crt serving-kube-apiserver.crt etcd/server-client.crt client-ca.crt}"
RESTART="${RESTART:-yes}"

serials() {
  for f in $WATCH; do
    printf '  %-32s %s\n' "$f" \
      "$(sudo openssl x509 -in "$D/$f" -noout -serial 2>/dev/null \
         | cut -d= -f2)"
  done
}

echo "== vorher =="; serials

echo; echo "== rotate =="
sudo rke2 certificate rotate 2>&1 | grep -oE "backed up certificates to [^,]*" | sed 's/^/  /'

if [ "$RESTART" != yes ]; then
  echo; echo "  RESTART=no - die zertifikate sind jetzt VON DER PLATTE WEG."
  echo "  Der knoten laeuft aus dem speicher weiter. Vor dem neustart"
  echo "  meldet 'rke2 certificate check' nichts, und das sieht aus wie"
  echo "  in ordnung. Nicht in diesem zustand stehen lassen."
  exit 0
fi

echo; echo "== neustart, mit messung des API-fensters =="
t0=$(date +%s); down=0
sudo systemctl restart rke2-server >/dev/null 2>&1 &
for _ in $(seq 1 150); do
  if sudo /var/lib/rancher/rke2/bin/kubectl \
       --kubeconfig=/etc/rancher/rke2/rke2.yaml get --raw /healthz \
       >/dev/null 2>&1; then
    [ "$down" -gt 0 ] && break
  else
    down=$((down+1))
  fi
  sleep 2
done
printf '  API war rund %ss nicht erreichbar, wieder da nach %ss\n' \
  "$(( down * 2 ))" "$(( $(date +%s) - t0 ))"

echo; echo "== nachher =="; serials
cat <<'TXT'

  Die CA muss unveraendert sein. Ist sie es, gelten alle bestehenden
  kubeconfigs weiter - sie vertrauen der CA, nicht dem blatt.
  Hat sich die CA-seriennummer geaendert, wurde rotate-ca gefahren,
  und das ist ein anderes ereignis mit einer anderen tragweite.
TXT
