#!/usr/bin/env bash
# Die Abnahme, und der Nachweis daraus.
#
# Kapitel 2 prueft sieben Bedingungen. Dieses Skript prueft
# zwoelf: die sieben, plus fuenf, die dieses Buch selbst
# gemessen hat und die man ohne die Kapitel 12 bis 19 nicht
# kennt.
#
# Es ist zum ZWEIMAL laufen gedacht. Beim ersten Mal soll es
# scheitern - dann weiss man, was noch fehlt. Anhang G geht
# die Befunde einzeln durch.
#
#   . ./scripts/vault-env.sh
#   ./chapters/appendix-g/go-live.sh
#
# Rueckgabe 0, wenn alle zwoelf bestehen.
set -uo pipefail

cd "$(dirname "$0")/../.."

pass=0; fail=0; OPEN=()
NOTE=()

chk() { # $1 label  $2 test  $3 chapter  $4 was man notiert
  printf "  %-44s " "$1"
  if eval "$2" >/dev/null 2>&1; then
    echo "PASS"; pass=$((pass+1))
    [ -n "${4:-}" ] && NOTE+=("$1|$(eval "$4" 2>/dev/null || echo '?')")
  else
    echo "FAIL  ($3)"; fail=$((fail+1)); OPEN+=("$1 -> $3")
  fi
}

echo "== Abnahme =="

# --- die sieben aus Kapitel 2 -----------------------------------------
chk "storage is not in-memory" \
  '[ "$(vault status -format=json | jq -r .storage_type)" != "inmem" ]' \
  "Chapter 2" \
  'vault status -format=json | jq -r .storage_type'

chk "more than one node" \
  '[ "$(vault operator raft list-peers -format=json \
        | jq ".data.config.servers|length")" -gt 1 ]' \
  "Chapter 4" \
  'vault operator raft list-peers -format=json | jq ".data.config.servers|length"'

chk "TLS in use" \
  'echo "${VAULT_ADDR:-}" | grep -q "^https"' \
  "Chapter 2" \
  'echo "${VAULT_ADDR}"'

chk "at least one audit device" \
  '[ "$(vault audit list -format=json | jq "keys|length")" -ge 1 ]' \
  "Chapter 2"

chk "initial root token revoked" \
  '! vault token lookup -format=json | jq -e ".data.policies|index(\"root\")"' \
  "Chapter 2"

chk "a snapshot can be taken" \
  'vault operator raft snapshot save /tmp/golive.snap' \
  "Chapter 9" \
  'stat -c%s /tmp/golive.snap 2>/dev/null || stat -f%z /tmp/golive.snap'

# Autopilot braucht nach dem Entsiegeln einen Moment, bis es die
# Follower zu Votern befoerdert hat - Kapitel 10 hat 16 Sekunden
# gemessen. Ohne dieses Fenster meldet die Abnahme auf einem
# kerngesunden Cluster einen Fehler, und ein Pruefskript, das
# falschen Alarm schlaegt, erzieht zum Wegsehen (Kapitel 17).
ft_ok() {
  local t0; t0=$(date +%s)
  while [ $(( $(date +%s) - t0 )) -lt 45 ]; do
    [ "$(vault operator raft autopilot state -format=json 2>/dev/null \
         | jq .FailureTolerance 2>/dev/null)" -ge 1 ] 2>/dev/null && return 0
    sleep 3
  done
  return 1
}
chk "failure tolerance at least 1" 'ft_ok' \
  "Chapter 5" \
  'vault operator raft autopilot state -format=json | jq .FailureTolerance'

# --- fuenf, die dieses Buch dazugelernt hat ---------------------------

# Kapitel 15: ein einzelnes Audit-Geraet ist eine harte Abhaengigkeit
# vom Log-Kollektor. Faellt er aus, verweigert Vault nach Sekunden
# alles - und laesst sich nicht mehr reparieren.
chk "TWO audit devices, one of them local" \
  '[ "$(vault audit list -format=json | jq "keys|length")" -ge 2 ] &&
   vault audit list -format=json | jq -e "to_entries[]|select(.value.type==\"file\")"' \
  "Chapter 15"

# Kapitel 9: eine Sicherung, die nicht geprueft wurde, ist eine Datei.
chk "the snapshot inspects cleanly" \
  'vault operator raft snapshot inspect /tmp/golive.snap' \
  "Chapter 9"

# Kapitel 17: ohne prometheus_retention_time antwortet der Endpunkt
# leer, und das sieht wie ein Scrape-Problem aus.
chk "metrics endpoint returns data" \
  '[ "$(curl -s --cacert cluster/tls/cert.pem \
        "${VAULT_ADDR}/v1/sys/metrics?format=prometheus" \
        | grep -c "^# TYPE")" -gt 20 ]' \
  "Chapter 17" \
  'curl -s --cacert cluster/tls/cert.pem "${VAULT_ADDR}/v1/sys/metrics?format=prometheus" | grep -c "^# TYPE"'

# Kapitel 16: ohne Ausgangswert gibt es keine Steigung, und ohne
# Steigung faellt eine Lease-Explosion erst auf, wenn sie weh tut.
chk "lease baseline recorded" \
  '[ -f evidence/lease-baseline.txt ]' \
  "Chapter 16" \
  'cat evidence/lease-baseline.txt'

# Kapitel 10: die einzige Zahl, die im Vorfall zaehlt.
chk "a restore has been rehearsed and timed" \
  '[ -f evidence/restore-drill.txt ]' \
  "Chapter 10" \
  'head -1 evidence/restore-drill.txt'

rm -f /tmp/golive.snap
echo "  ---"
echo "  $pass passed, $fail open"

if [ "$fail" -gt 0 ]; then
  echo
  echo "Offen - jeder Punkt nennt das Kapitel, das ihn behandelt:"
  printf '  %s\n' "${OPEN[@]}"
  echo
  echo "Das ist der erwartete erste Lauf. Anhang G geht sie durch."
  exit 1
fi

# --------------------------------------------------------- der Nachweis
echo
echo "== Nachweis-Mappe =="
echo
printf '  %-44s %s\n' "erhoben am" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf '  %-44s %s\n' "Vault" "$(vault status -format=json | jq -r .version)"
for n in "${NOTE[@]}"; do
  printf '  %-44s %s\n' "${n%%|*}" "${n##*|}"
done
echo
echo "  Was dieses Skript NICHT pruefen kann und Du eintragen musst:"
echo "    - wer die Schluessel haelt, und wie lange es dauert,"
echo "      dass genug von ihnen gleichzeitig erreichbar sind"
echo "      (Kapitel 3 - die Zahl, die jede Zielzeit begrenzt)"
echo "    - wo die Snapshots liegen, und dass es nicht dort ist,"
echo "      wo auch die Unseal-Keys liegen  (Kapitel 9)"
echo "    - welche Anwendung einen Ausfall wie lange uebersteht"
echo "      (Kapitel 13)"
echo "    - welche Abhaengigkeitsschleife akzeptiert wurde, von wem,"
echo "      und wann sie zuletzt geprueft wurde  (Kapitel 15)"
