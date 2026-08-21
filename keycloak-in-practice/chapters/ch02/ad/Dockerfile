# A Samba Active Directory domain controller, built rather than pulled.
#
# Community Samba images are mostly linux/amd64 only, which makes them
# unusable on Apple silicon without emulation. Ubuntu publishes both
# architectures and Samba is a distribution package, so this builds and
# runs natively everywhere the book is used.
#
# Samba is not Active Directory. Where they differ, the book says so.
ARG UBUNTU_SERIES=24.04
FROM ubuntu:${UBUNTU_SERIES}

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      samba samba-dsdb-modules samba-vfs-modules smbclient \
      krb5-user krb5-config ldap-utils winbind \
      ca-certificates procps iproute2 \
 && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 53/tcp 53/udp 88/tcp 88/udp 389/tcp 636/tcp 445/tcp
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
