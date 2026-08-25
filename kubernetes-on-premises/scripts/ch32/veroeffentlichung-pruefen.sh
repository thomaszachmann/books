#!/usr/bin/env bash
# Prueft eine Veroeffentlichung: die Oeffnung nach innen und die
# Abschottung nach aussen, in einem Lauf.
#
# Der Anlass ist der Fehler aus Kapitel 32: eine nft-Regel am
# output-Hook schneidet den HOST ab, nicht den Cluster. Pod-Verkehr
# wird geroutet und laeuft am output-Hook vorbei. Gemessen: der Host
# konnte keinen Namen aufloesen, waehrend ein Pod im selben Moment
# eine HTTPS-Verbindung zu Let's Encrypt aufbaute.
#
# Deshalb prueft dieses Skript von INNEN, nicht aus der Shell.
# Kapitel 32.
set -euo pipefail

NS="${NS:-}"
GW="${GW:-}"
PFAD="${PFAD:-/}"
PROBE_ZIEL="${PROBE_ZIEL:-https://acme-v02.api.letsencrypt.org/directory}"
K="${KUBECTL:-kubectl}"

if [ -z "$NS" ] || [ -z "$GW" ]; then
  echo "aufruf: NS=<namespace> GW=<gateway-name> [PFAD=/v2/] $0" >&2
  exit 2
fi

warn=0
melde() { echo "  $*"; }
mangel() { echo "  ACHTUNG: $*"; warn=$((warn+1)); }

echo "=== die oeffnung ==="
ADR=$($K -n "$NS" get gateway "$GW" -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)
[ -n "$ADR" ] || { echo "  kein gateway $GW in $NS" >&2; exit 3; }
melde "adresse:   $ADR"
$K -n "$NS" get gateway "$GW" \
  -o jsonpath='{range .spec.listeners[*]}  listener: {.name} {.protocol}/{.port}{"\n"}{end}' 2>/dev/null

echo "=== was die routen freigeben ==="
$K -n "$NS" get httproute -o jsonpath='{range .items[*]}  route {.metadata.name}: {range .spec.rules[*]}{range .matches[*]}{.path.value} {end}{end}{"\n"}{end}' 2>/dev/null

# Accepted allein genuegt nicht: eine route kann akzeptiert sein und
# ihr backend trotzdem nicht aufloesen. Beides pruefen.
for r in $($K -n "$NS" get httproute -o name 2>/dev/null); do
  A=$($K -n "$NS" get "$r" -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}' 2>/dev/null)
  R=$($K -n "$NS" get "$r" -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}' 2>/dev/null)
  printf "  %-34s Accepted=%s ResolvedRefs=%s\n" "${r#httproute.gateway.networking.k8s.io/}" "$A" "$R"
  [ "$R" = "True" ] || mangel "${r##*/}: backend loest nicht auf"
done

echo "=== der host: was ist wirklich offen ==="
if command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld 2>/dev/null; then
  Z=$(firewall-cmd --get-default-zone 2>/dev/null)
  melde "firewalld zone $Z"
  melde "  dienste: $(firewall-cmd --zone="$Z" --list-services 2>/dev/null)"
  melde "  ports:   $(firewall-cmd --zone="$Z" --list-ports 2>/dev/null)"
else
  mangel "firewalld nicht aktiv - die oeffnung ist dann nicht die"
  mangel "  differenz einer zeile, sondern alles"
fi

echo "=== die abschottung, von INNEN gemessen ==="
# Ein pod, der schon laeuft. Kein neuer: unter PSS restricted scheitert
# ein schnell hingeworfener probe-pod, und das saehe wie abschottung
# aus, waere aber nur ein abgelehnter pod.
POD=$($K -n "$NS" get pods --field-selector status.phase=Running \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -z "$POD" ]; then
  mangel "kein laufender pod in $NS - abschottung UNGEPRUEFT"
else
  melde "probe aus pod/$POD"
  ERG=$($K -n "$NS" exec "$POD" -- timeout 12 sh -c \
        "wget -q -O /dev/null -T 8 '$PROBE_ZIEL' 2>&1 && echo OFFEN || echo ZU" \
        2>/dev/null | tail -1 || echo ZU)
  if [ "$ERG" = "OFFEN" ]; then
    mangel "POD ERREICHT DAS INTERNET - der cluster ist nicht abgeschnitten"
    mangel "  pruefen: hat die nft-tabelle eine forward-chain?"
  else
    melde "pod nach draussen: zu"
  fi
fi

echo "=== nft: beide haken vorhanden ==="
if command -v nft >/dev/null 2>&1; then
  # Regelwerk einmal einlesen statt je Haken zu pipen.
  #
  # "nft list ruleset | grep -q" ist hier falsch: grep -q steigt beim
  # ersten Treffer aus, nft bekommt SIGPIPE und endet mit 141, und
  # "set -o pipefail" meldet die Pipeline als gescheitert. Das Skript
  # meldete daraufhin "hook output fehlt" - auf einem Host, dessen
  # Regelwerk elf Treffer enthielt. Ein Fehlalarm, ausgeloest durch
  # den Erfolg der Suche.
  REGELN=$(nft list ruleset 2>/dev/null || true)
  for h in output forward; do
    if printf '%s\n' "$REGELN" | grep -q "hook $h"; then
      melde "hook $h: vorhanden"
    else
      mangel "hook $h fehlt"
      [ "$h" = "forward" ] && mangel "  ohne forward ist nur der host abgeschnitten"
    fi
  done
fi

echo "=== ergebnis ==="
melde "veroeffentlicht auf $ADR$PFAD"
if [ "$warn" -eq 0 ]; then
  melde "oeffnung schmal, abschottung haelt"
  exit 0
fi
melde "$warn punkt(e) klaeren"
exit 1
