#!/usr/bin/env bash
# Does this machine have what the book needs? Chapter 2, step 1.
set -uo pipefail

fail=0
need() {
  if command -v "$1" >/dev/null 2>&1; then
    printf '  ok      %-12s %s\n' "$1" "$(command -v "$1")"
  else
    printf '  MISSING %-12s %s\n' "$1" "$2"
    fail=1
  fi
}

echo "Tools"
need docker   "Appendix A"
need openssl  "Appendix A"
need jq       "Appendix A"
need xmllint  "libxml2-utils on Debian; preinstalled on macOS"
need python3  "Chapter 5 encodes a SAML request with it"
need git      "Appendix A"

echo
echo "Names"
for n in sso.meridian.test dc.meridian.test app.meridian.test; do
  if getent hosts "$n" >/dev/null 2>&1 \
     || ping -c1 -W1 "$n" >/dev/null 2>&1; then
    printf '  ok      %s\n' "$n"
  else
    printf '  MISSING %s  -> Chapter 2, step 3\n' "$n"
    fail=1
  fi
done

echo
echo "Configuration"
if [ ! -f .env ]; then
  echo "  MISSING .env  -> make env"; fail=1
elif ! grep -q '^KEYCLOAK_VERSION=' .env; then
  echo "  MISSING pinned versions in .env  -> make env"; fail=1
else
  echo "  ok      .env"
fi
[ -f pki/ca.crt ] && echo "  ok      pki/ca.crt" \
  || echo "  note    pki/ca.crt not yet made -> make pki"

echo
[ "$fail" -eq 0 ] && echo "Ready." || echo "Not ready; see above."
exit "$fail"
