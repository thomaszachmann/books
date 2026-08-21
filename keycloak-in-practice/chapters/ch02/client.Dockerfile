# The Linux box the book uses to prove things from inside the network:
# Chapter 3 fetches the discovery document from it, Chapter 13 holds a
# Kerberos ticket in it.
ARG UBUNTU_SERIES=24.04
FROM ubuntu:${UBUNTU_SERIES}

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl jq krb5-user ldap-utils libxml2-utils \
      dnsutils iputils-ping \
 && rm -rf /var/lib/apt/lists/*

# The root from Chapter 2 is mounted in at run time; refresh the store
# on every start so a reissued CA is picked up without a rebuild.
RUN printf '#!/bin/sh\nupdate-ca-certificates >/dev/null 2>&1\nexec "$@"\n' \
      > /usr/local/bin/entrypoint.sh \
 && chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
