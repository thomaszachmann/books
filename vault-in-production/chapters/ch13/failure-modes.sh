#!/usr/bin/env bash
# How fast does each failure report? The third number is the one
# that decides whether an application degrades or dies.
set -uo pipefail

ms(){ s=$(date +%s%N); eval "$1" >/dev/null 2>&1
      printf '  %-26s %6dms\n' "$2" $(( ($(date +%s%N)-s)/1000000 )); }

ms 'vault read database/config/appdb' 'baseline (healthy)'
echo '  -- now seal, then stop, then black-hole --'
ms 'vault read database/config/appdb' 'sealed / stopped'
ms 'VAULT_ADDR=https://10.255.255.1:8210 \
    vault read database/config/appdb' 'packets dropped'
ms 'VAULT_ADDR=https://10.255.255.1:8210 \
    VAULT_CLIENT_TIMEOUT=5s vault read database/config/appdb' \
   'dropped, timeout 5s'
