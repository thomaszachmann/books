#!/usr/bin/env bash
# Every robot account, system and project level, as one JSON array.
#
#   ./scripts/list-robots.sh | jq -r '.[] | "\(.name)\t\(.expires_at)"'
#
# GET /robots alone returns only system-level robots. Project robots
# have to be asked for per project, with the query Harbor expects:
# q=Level=project,ProjectID=<id>. Chapter 6 is where this first bites.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API="$ROOT/scripts/harbor-api.sh"

{
  "$API" GET '/robots?page_size=100'
  "$API" GET '/projects?page_size=100' | jq -r '.[].project_id' \
    | while read -r pid; do
        "$API" GET "/robots?page_size=100&q=Level%3Dproject%2CProjectID%3D$pid"
      done
} | jq -s 'add | unique_by(.id) | sort_by(.name)'
