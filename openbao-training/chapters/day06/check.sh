#!/usr/bin/env bash
check() { if eval "$2" >/dev/null 2>&1; then echo "✔ $1"; else echo "✘ $1"; fi; }
ENT=$(bao read -field=id identity/entity/name/thomas 2>/dev/null)

check "Entity thomas existiert" "[ -n '$ENT' ]"
check "Entity hat 2 Aliases" \
  "bao read -format=json identity/entity/name/thomas \
  | jq -e '.data.aliases|length == 2'"
check "Gruppe platform-team enthält thomas" \
  "bao read -format=json identity/group/name/platform-team | jq -e --arg e '$ENT' \
  '.data.member_entity_ids|index(\$e)'"
check "Audit-Device file aktiv" "bao audit list | grep -q '^file/'"
check "Audit-Log enthält Einträge" "[ -s ~/bao-lab/tag06/audit.log ]"
