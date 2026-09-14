# Chapter 22 - an OpenBao that unseals from a PKCS#11 HSM.
#
# Two things have to be true at once, and the base image provides only
# the first: the binary must be built with PKCS#11 support (cgo), and
# the PKCS#11 library must be INSIDE the container, because it is loaded
# into the bao process, not spoken to over the network. SoftHSM stands
# in for the hardware; swapping it for a real HSM means swapping the .so
# and the token directory, nothing else.
#
# The HSM distribution is discontinued after 2.6 in favour of an
# external KMS plugin that is drop-in compatible - see the chapter.
FROM docker.io/openbao/openbao-hsm:2.6.2
USER root
RUN apk add --no-cache softhsm opensc \
 && mkdir -p /var/lib/softhsm/tokens \
 && chown -R openbao:openbao /var/lib/softhsm
USER openbao
