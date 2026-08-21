#!/usr/bin/env bash
# Provision the domain on first start, then run Samba in the foreground.
set -euo pipefail

REALM="${AD_REALM:-MERIDIAN.TEST}"
DOMAIN="${AD_DOMAIN:-MERIDIAN}"
PASS="${AD_ADMIN_PASSWORD:?AD_ADMIN_PASSWORD must be set}"

if [ ! -f /var/lib/samba/private/sam.ldb ]; then
  echo "provisioning $REALM - this takes about a minute"

  # The packaged smb.conf is for a file server and blocks provisioning.
  rm -f /etc/samba/smb.conf

  samba-tool domain provision \
    --use-rfc2307 \
    --realm="$REALM" \
    --domain="$DOMAIN" \
    --server-role=dc \
    --dns-backend=SAMBA_INTERNAL \
    --adminpass="$PASS"

  # Forward anything that is not ours, so the container can still
  # resolve the outside world.
  sed -i 's/^\(\s*\)dns forwarder = .*/\1dns forwarder = 1.1.1.1/' \
    /etc/samba/smb.conf || true

  cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
  echo "provisioned"
else
  echo "domain already provisioned; starting"
fi

exec samba -i --debuglevel=1
