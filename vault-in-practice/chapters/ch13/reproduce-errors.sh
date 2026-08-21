#!/usr/bin/env bash
# Chapter 13 - every error the chapter prints, on purpose.
#
# Self-contained: its own mounts, prefixed wwr-, removed at the end. It
# does not touch the pki_int the chapter builds.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh
wwr_env

vault secrets disable wwr-pki >/dev/null 2>&1 || true
vault secrets enable -path=wwr-pki pki >/dev/null
vault secrets tune -max-lease-ttl=8760h wwr-pki >/dev/null
vault write -field=certificate wwr-pki/root/generate/internal \
  common_name="WWR Root" ttl=8760h >/dev/null
vault write wwr-pki/roles/strict \
  allowed_domains="meridian.internal" allow_subdomains=true \
  allow_bare_domains=false max_ttl=24h >/dev/null

wwr_case "common name X not allowed by this role"
echo "allow_bare_domains=false: the domain itself is refused..."
wwr_expect "not allowed by this role" vault write wwr-pki/issue/strict \
  common_name=meridian.internal ttl=1h
echo "...while a subdomain is fine:"
vault write -field=serial_number wwr-pki/issue/strict \
  common_name=api.meridian.internal ttl=1h | cut -c1-30
echo "A distinction that surprises people the first time. The role says so:"
vault read -format=json wwr-pki/roles/strict \
  | jq -c '{allowed_domains:.data.allowed_domains, allow_subdomains:.data.allow_subdomains, allow_bare_domains:.data.allow_bare_domains}'

wwr_case "the certificate is much shorter than requested"
echo "Asked for 200h against a role whose max_ttl is 24h."
# PKI reports lease_duration as 0; the truth is in the certificate.
vault write -field=certificate wwr-pki/issue/strict \
  common_name=api.meridian.internal ttl=200h > /tmp/wwr-200.crt
openssl x509 -in /tmp/wwr-200.crt -noout -dates | sed 's/^/  /'
echo "  which is 24 hours, not 200."
echo "Check in order: the role's max_ttl, then the mount's max_lease_ttl,"
echo "then the system default of 768 hours."
vault read -field=max_ttl wwr-pki/roles/strict | sed 's/^/  role max_ttl:  /'
vault read -format=json sys/mounts/wwr-pki/tune \
  | jq -r '"  mount max_lease_ttl: \(.data.max_lease_ttl) s"'

wwr_case "unable to get local issuer certificate when verifying"
vault write -format=json wwr-pki/issue/strict \
  common_name=api.meridian.internal ttl=1h > /tmp/wwr-cert.json
jq -r .data.certificate /tmp/wwr-cert.json > /tmp/wwr-leaf.crt
jq -r '.data.ca_chain[]' /tmp/wwr-cert.json > /tmp/wwr-chain.crt
echo "Verifying the leaf alone, with no chain:"
openssl verify /tmp/wwr-leaf.crt 2>&1 | sed -n '1,3p' | sed 's/^/  /'
echo "and with the chain from the same response:"
openssl verify -CAfile /tmp/wwr-chain.crt /tmp/wwr-leaf.crt 2>&1 \
  | sed -n '1,2p' | sed 's/^/  /'
echo "Use ca_chain from the issue response, not just certificate."

wwr_case "the intermediate CA expires in 32 days"
echo "The mount ceiling bounds the CA's own certificate. A mount tuned to"
echo "768h (the default) cannot hold a ten-year intermediate:"
vault secrets disable wwr-short >/dev/null 2>&1 || true
vault secrets enable -path=wwr-short pki >/dev/null
vault write -format=json wwr-short/root/generate/internal \
  common_name="WWR Short" ttl=87600h \
  | jq -r '"  asked for 87600h, expires: \(.data.expiration | todate)"'
echo "Raise max-lease-ttl BEFORE generating, not after:"
vault read -format=json sys/mounts/wwr-short/tune \
  | jq -r '"  mount max_lease_ttl: \(.data.max_lease_ttl) s = \(.data.max_lease_ttl/3600) h"'
vault secrets disable wwr-short >/dev/null

wwr_case "storage grows steadily on a PKI mount"
n=$(vault list -format=json wwr-pki/certs | jq 'length')
printf '  certificates stored after this run: %s\n' "$n"
echo "Every issued certificate is stored. At 24-hour lifetimes that adds"
echo "up quickly. Schedule tidy, with a safety_buffer longer than your"
echo "longest certificate:"
vault write wwr-pki/tidy tidy_cert_store=true tidy_revoked_certs=true \
  safety_buffer=72h >/dev/null && echo "   ok: tidy accepted"

vault secrets disable wwr-pki >/dev/null 2>&1 || true
rm -f /tmp/wwr-200.crt /tmp/wwr-cert.json /tmp/wwr-leaf.crt /tmp/wwr-chain.crt
wwr_done
