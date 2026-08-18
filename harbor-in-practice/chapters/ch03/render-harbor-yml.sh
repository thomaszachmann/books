#!/usr/bin/env bash
# Chapter 3, step 5. Render harbor.yml from the template.
#
# In Chapter 18 this script is replaced by a Vault Agent template that
# renders the same fields from Vault. The placeholder names are kept
# identical so that the two versions can be compared side by side.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../../scripts/versions.sh"

: "${HARBOR_HOSTNAME:=harbor.meridian.test}"

# Generated, not chosen. A password somebody typed is a password
# somebody reuses.
: "${HARBOR_ADMIN_PASSWORD:=$(openssl rand -base64 24)}"
: "${HARBOR_DB_PASSWORD:=$(openssl rand -base64 24)}"

export HARBOR_HOSTNAME HARBOR_ADMIN_PASSWORD HARBOR_DB_PASSWORD

OUT="${1:-harbor.yml}"
envsubst < "$ROOT/vm/harbor.yml.tpl" > "$OUT"
chmod 600 "$OUT"

cat <<TXT
Written $OUT with mode 600.

  hostname  $HARBOR_HOSTNAME

The admin and database passwords are in that file in plain text, and
they will also be written into common/config once prepare runs. That is
what a service needs in order to start unattended, and it is the reason
Part VI exists. Do not commit this file: .gitignore already refuses it.

Print the admin password once, then put it in a password manager:

  grep harbor_admin_password $OUT
TXT
