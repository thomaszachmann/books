#!/usr/bin/env bash
# Put some people and groups in the directory. Chapter 12.
#
# Nine users, three groups. Small enough to read, large enough that a
# group mapper has something to say. Passwords are chosen for typing;
# Samba enforces a complexity policy and rejects anything shorter.
set -euo pipefail

cd "$(dirname "$0")/../.."
dc() { docker compose exec -T dc "$@"; }

PW='Meridian-Lab-2026'

echo "groups"
for g in Dispatchers Finance Contractors; do
  dc samba-tool group add "$g" 2>/dev/null || echo "  $g exists"
done

echo "users"
add() {  # username, given, surname, group
  dc samba-tool user create "$1" "$PW" \
      --given-name="$2" --surname="$3" \
      --use-username-as-cn 2>/dev/null || echo "  $1 exists"
  dc samba-tool group addmembers "$4" "$1" 2>/dev/null || true
}

add anna     Anna     Voss      Dispatchers
add bjoern   Bjoern   Kessler   Dispatchers
add carla    Carla    Nunes     Dispatchers
add dmorel   Denis    Morel     Contractors
add erika    Erika    Lund      Finance
add farid    Farid    Haddad    Finance
add greta    Greta    Ohlsen    Finance
add hugo     Hugo     Baumann   Dispatchers
add ines     Ines     Rocha     Contractors

echo
echo "in the directory now:"
dc samba-tool user list | sort | sed 's/^/  /'
