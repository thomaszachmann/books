#!/usr/bin/env bash
# check-exceptions.sh - prueft das Ausnahmeregister.
# Exit-Code 0 = gueltig, 1 = mindestens ein Fehler.
set -euo pipefail

FILE="${1:-exceptions.yaml}"
MAX_DAYS="${MAX_DAYS:-90}"     # laengste erlaubte Laufzeit
WARN_DAYS="${WARN_DAYS:-14}"   # Vorwarnzeit vor Ablauf

[ -f "$FILE" ] || { echo "FEHLER: $FILE nicht gefunden" >&2; exit 1; }

REQUIRED='["id","type","target","reference","reason","risk",
  "compensation","owner","approver","ticket","created","expires"]'

REPORT=$(yq -o=json '.' "$FILE" | jq -r \
  --argjson req "$REQUIRED" \
  --argjson max "$MAX_DAYS" \
  --argjson warn "$WARN_DAYS" '
  def isdate: type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$");
  def ts: . + "T00:00:00Z" | fromdateiso8601;
  now as $now
  | (.exceptions // []) as $all
  | ($all | map(.id) | group_by(.) | map(select(length > 1) | .[0])) as $dups
  | ($dups[] | "FEHLER \(.): ID mehrfach vergeben"),
    ($all[] |
      ($req - [to_entries[] | select(.value != null and .value != "") | .key])
        as $missing
      | (.id // "ohne-id") as $id
      | if ($missing | length) > 0 then
          "FEHLER \($id): fehlende Felder: \($missing | join(", "))"
        elif ((.created | isdate) and (.expires | isdate) | not) then
          "FEHLER \($id): created/expires nicht im Format JJJJ-MM-TT"
        elif (.expires | ts) <= $now then
          "FEHLER \($id): abgelaufen seit \(.expires)"
        elif ((.expires | ts) - (.created | ts)) > ($max * 86400) then
          "FEHLER \($id): Laufzeit laenger als \($max) Tage"
        elif ((.expires | ts) - $now) < ($warn * 86400) then
          "WARNUNG \($id): laeuft am \(.expires) ab"
        else
          "OK \($id): gueltig bis \(.expires)"
        end)
')

echo "$REPORT"
if grep -q '^FEHLER' <<<"$REPORT"; then
  echo "Ergebnis: Ausnahmeregister ungueltig" >&2
  exit 1
fi
echo "Ergebnis: Ausnahmeregister gueltig"
