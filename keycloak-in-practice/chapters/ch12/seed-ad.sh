#!/usr/bin/env bash
# Put some people and groups in the directory. Chapter 12.
#
# Nine users, three groups. Small enough to read, large enough that a
# group mapper has something to say. Passwords are chosen for typing;
# Samba enforces a complexity policy and rejects anything shorter.
#
# The group names are Chapter 7's, lower case and all: logistics and
# finance. The directory takes over groups the realm used to hold, and
# the groups claim carries the name exactly as written here - Chapters
# 16 to 18 compare it case-sensitively.
set -euo pipefail

cd "$(dirname "$0")/../.."
dc() { docker compose exec -T dc "$@"; }

PW='Meridian-Lab-2026'

echo "groups"
for g in logistics finance contractors; do
  dc samba-tool group add "$g" 2>/dev/null || echo "  $g exists"
done

echo "users"
add() {  # username, given, surname, group
  # No --use-username-as-cn: in Active Directory the cn IS the display
  # name, and Keycloak's AD preset creates a full-name mapper that reads
  # cn and splits it. Make cn the username and every imported user
  # arrives with no first name and no explanation.
  dc samba-tool user create "$1" "$PW" \
      --given-name="$2" --surname="$3" \
      --mail-address="$1@meridian.test" 2>/dev/null \
    || echo "  $1 exists"
  dc samba-tool group addmembers "$4" "$1" 2>/dev/null || true
}

add anna     Anna     Voss      logistics
add bjoern   Bjoern   Kessler   logistics
add carla    Carla    Nunes     logistics
add dmorel   Denis    Morel     contractors
add erika    Erika    Lund      finance
add farid    Farid    Haddad    finance
add greta    Greta    Ohlsen    finance
add hugo     Hugo     Baumann   logistics
add ines     Ines     Rocha     contractors

# Chapter 8 gave Anna an employee number in Keycloak. In the directory
# it is an ordinary attribute, and Chapter 12 maps it back into the
# same user-profile attribute. samba-tool has no option for it.
echo "anna's employee number"
docker compose exec -T client sh -c "ldapmodify -x \
  -H ldaps://dc.meridian.test \
  -D 'Administrator@MERIDIAN.TEST' -w \"\$0\"" "${AD_ADMIN_PASSWORD:?source .env first}" \
  >/dev/null <<'LDIF'
dn: CN=Anna Voss,CN=Users,DC=meridian,DC=test
changetype: modify
replace: employeeNumber
employeeNumber: MF-4471
LDIF

echo
echo "in the directory now:"
dc samba-tool user list | sort | sed 's/^/  /'
