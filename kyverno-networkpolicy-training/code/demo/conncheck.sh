#!/usr/bin/env bash
# conncheck.sh - testet eine Verbindung aus einem Pod heraus.
#
#   conncheck.sh <ns>/<pod|app> <url> [allow|deny]
#
#   <ns>/<pod|app>  Quelle: Pod-Name oder Wert des Labels app (erster Running-Pod)
#   <url>           http://host[:port][/pfad]  oder  tcp://host:port
#   allow|deny      optional: Erwartung. Dann Exit 0 = wie erwartet, 1 = Abweichung
#
# Ohne Erwartung: Exit 0 = erlaubt, 1 = blockiert, 2 = Aufruffehler.
# TIMEOUT (Sekunden, Standard 2) steuert, wie lange auf eine Antwort gewartet wird.
set -uo pipefail

if [[ $# -lt 2 || $1 != */* ]]; then
  echo "Aufruf: $0 <ns>/<pod|app> <url> [allow|deny]" >&2
  exit 2
fi
src=$1 url=$2 want=${3:-}
ns=${src%%/*} name=${src#*/}
t=${TIMEOUT:-2}

pod=$(kubectl -n "$ns" get pod "$name" -o name 2>/dev/null)
if [[ -z $pod ]]; then
  pod=$(kubectl -n "$ns" get pod -l "app=$name" \
    --field-selector=status.phase=Running -o name 2>/dev/null | head -n1)
fi
if [[ -z $pod ]]; then
  echo "✘ Quelle $src nicht gefunden" >&2
  exit 2
fi

case $url in
  tcp://*)
    hp=${url#tcp://}
    cmd="nc -z -w $t ${hp%:*} ${hp##*:}" ;;
  http://*|https://*)
    cmd="curl -sk -o /dev/null -w %{http_code}"
    cmd="$cmd --connect-timeout $t -m $((t + 1)) $url" ;;
  *)
    echo "✘ URL muss mit http://, https:// oder tcp:// beginnen" >&2
    exit 2 ;;
esac

out=$(kubectl -n "$ns" exec "$pod" -- sh -c "$cmd" 2>/dev/null)
rc=$?
case $rc in
  0)  res=allow; info="${out:+HTTP $out}" ;;
  6)  res=deny;  info="DNS-Fehler" ;;
  7)  res=deny;  info="abgelehnt" ;;
  28) res=deny;  info="Timeout" ;;
  *)  res=deny;  info="rc=$rc" ;;
esac
[[ $url == tcp://* && $rc -ne 0 ]] && info="keine Verbindung"

if [[ $res == allow ]]; then
  line="✔ erlaubt   $src -> $url${info:+ ($info)}"
else
  line="✘ blockiert $src -> $url ($info)"
fi

if [[ -z $want ]]; then
  echo "$line"
  [[ $res == allow ]]
  exit $?
fi
if [[ $res == "$want" ]]; then
  echo "$line"
  exit 0
fi
echo "$line  <-- erwartet: $want"
exit 1
