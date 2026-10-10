#!/usr/bin/env bash
# Rauchtest für Open WebUI: Login, Modelle, eine Chat-Antwort über LiteLLM.
# Aufruf: OWUI=http://chat.ki.localtest.me EMAIL=... PASS=... ./smoke.sh
set -euo pipefail
OWUI=${OWUI:-http://chat.ki.localtest.me}
EMAIL=${EMAIL:-admin@ki.lab}
PASS=${PASS:?PASS fehlt}
MODEL=${MODEL:-chat-small}

TOKEN=$(jq -n --arg e "$EMAIL" --arg p "$PASS" '{email: $e, password: $p}' \
  | curl -sf "$OWUI/api/v1/auths/signin" -H 'Content-Type: application/json' \
      -d @- | jq -r .token)
[ -n "$TOKEN" ] && [ "$TOKEN" != null ] || { echo "✘ Login"; exit 1; }
echo "✔ Login als $EMAIL"

MODELS=$(curl -sf "$OWUI/api/models" -H "Authorization: Bearer $TOKEN" \
  | jq -r '[.data[].id] | join(" ")')
echo "✔ Modelle: $MODELS"

ANSWER=$(jq -n --arg m "$MODEL" \
    '{model: $m, stream: false,
      messages: [{role: "user", content: "Antworte nur mit: OK"}]}' \
  | curl -sf "$OWUI/api/chat/completions" -H "Authorization: Bearer $TOKEN" \
      -H 'Content-Type: application/json' -d @- \
  | jq -r '.choices[0].message.content')
echo "✔ $MODEL antwortet: $ANSWER"
