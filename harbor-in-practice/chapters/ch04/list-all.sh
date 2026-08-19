#!/usr/bin/env bash
# Page through a Harbor list endpoint correctly.
#
# Harbor paginates every list and puts the total in X-Total-Count rather
# than in the body. A script that reads the body and stops has silently
# processed the first ten of four hundred, and nothing about the output
# says so.
#
#   HARBOR_PASS=... ./list-all.sh /projects
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

EP="${1:?an endpoint, for example /projects}"
SIZE="${PAGE_SIZE:-100}"
SEP='?'; [[ "$EP" == *'?'* ]] && SEP='&'

total=$("$ROOT/scripts/harbor-api.sh" GET "$EP${SEP}page_size=1" \
        -D - -o /dev/null \
        | tr -d '\r' \
        | awk -F': ' 'tolower($1)=="x-total-count"{print $2+0}')

: "${total:=0}"
pages=$(( (total + SIZE - 1) / SIZE ))
echo "total $total, $pages page(s) of $SIZE" >&2

for p in $(seq 1 "$pages"); do
  "$ROOT/scripts/harbor-api.sh" GET "$EP${SEP}page=$p&page_size=$SIZE"
done
