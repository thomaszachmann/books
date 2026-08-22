# The Linux box the book uses to prove things from inside the network:
# Chapter 3 fetches the discovery document from it, Chapter 13 holds a
# Kerberos ticket in it.
ARG UBUNTU_SERIES=24.04
FROM ubuntu:${UBUNTU_SERIES}

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl jq krb5-user ldap-utils libxml2-utils \
      dnsutils iputils-ping \
 && rm -rf /var/lib/apt/lists/*

# Kerberos needs to know which realm it is in and where the KDC is.
# Without this file kinit fails with "Configuration file does not specify
# default realm", which sounds like a Kerberos problem and is a missing
# file. dc.meridian.test resolves through the compose alias.
RUN printf '%s\n' \
      '[libdefaults]' \
      '  default_realm = MERIDIAN.TEST' \
      '  dns_lookup_realm = false' \
      '  dns_lookup_kdc = false' \
      '  rdns = false' \
      '' \
      '[realms]' \
      '  MERIDIAN.TEST = {' \
      '    kdc = dc.meridian.test' \
      '    admin_server = dc.meridian.test' \
      '  }' \
      '' \
      '[domain_realm]' \
      '  .meridian.test = MERIDIAN.TEST' \
      '  meridian.test = MERIDIAN.TEST' \
      > /etc/krb5.conf

# libldap does not fall back to the system trust store on Debian, and
# the shipped ldap.conf sets nothing. Without this line every ldaps://
# command fails with "Can't contact LDAP server", which names neither
# TLS nor trust and sends everybody looking at the network.
RUN mkdir -p /etc/ldap \
 && printf 'TLS_CACERT /etc/ssl/certs/ca-certificates.crt\n' \
      >> /etc/ldap/ldap.conf

# The root from Chapter 2 is mounted in at run time; refresh the store
# on every start so a reissued CA is picked up without a rebuild.
RUN printf '#!/bin/sh\nupdate-ca-certificates >/dev/null 2>&1\nexec "$@"\n' \
      > /usr/local/bin/entrypoint.sh \
 && chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
