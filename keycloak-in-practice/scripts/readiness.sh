#!/usr/bin/env bash
# Appendix I, executed.
#
# Runs every check in the production readiness review that a machine can
# run, and lists the ones it cannot. An item nobody can check for you is
# not a failure - it is an unanswered question, and the summary counts
# those separately on purpose.
#
#   ./scripts/readiness.sh
#   ./scripts/readiness.sh --section tokens
#   ./scripts/readiness.sh --markdown > REVIEW.md
#
# Point it at the installation you actually run, not at the lab:
#   KC_URL=https://sso.example.com     the base URL
#   KC_REALM=meridian                  the realm under review
#   KC_ADMIN / KC_PASS                 an admin that can read the realm
#
# Without them the API checks turn into skips rather than failures. The
# lab's own credentials are picked up from .env if it exists.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
[ -f "$ROOT/.env" ] && . "$ROOT/.env" 2>/dev/null

KC_REALM="${KC_REALM:-meridian}"
# Keycloak has renamed these twice. Accept all three spellings so the
# script works against this book's lab without being told anything.
KC_ADMIN="${KC_ADMIN:-${KC_BOOTSTRAP_ADMIN_USERNAME:-${KEYCLOAK_ADMIN:-admin}}}"
KC_PASS="${KC_PASS:-${KC_BOOTSTRAP_ADMIN_PASSWORD:-${KEYCLOAK_ADMIN_PASSWORD:-}}}"

SECTION=""; MARKDOWN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --section)  SECTION="${2:?a section name}"; shift 2 ;;
    --markdown) MARKDOWN=1; shift ;;
    -h|--help)  sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

A_TOTAL=0; A_PASS=0; A_FAIL=0; A_SKIP=0
D_TOTAL=0; R_TOTAL=0
CUR=""

section() {
  CUR="$1"
  [ -n "$SECTION" ] && [ "$SECTION" != "$1" ] && return
  if [ -n "$MARKDOWN" ]; then printf '\n## %s\n\n' "$2"
  else printf '\n== %s\n' "$2"; fi
}
active() { [ -z "$SECTION" ] || [ "$SECTION" = "$CUR" ]; }

pass() { active || return 0; A_TOTAL=$((A_TOTAL+1)); A_PASS=$((A_PASS+1))
  if [ -n "$MARKDOWN" ]; then printf -- '- [x] **%s** %s\n' "$1" "$2"
  else printf 'PASS      %-5s %s\n' "$1" "$2"; fi; }
fail() { active || return 0; A_TOTAL=$((A_TOTAL+1)); A_FAIL=$((A_FAIL+1))
  if [ -n "$MARKDOWN" ]; then printf -- '- [ ] **%s** %s — **FAIL**\n' "$1" "$2"
  else printf 'FAIL      %-5s %s\n' "$1" "$2"; fi; }
skip() { active || return 0; A_TOTAL=$((A_TOTAL+1)); A_SKIP=$((A_SKIP+1))
  if [ -n "$MARKDOWN" ]; then printf -- '- [ ] **%s** %s — not checked: %s\n' "$1" "$2" "$3"
  else printf 'skip      %-5s %s (%s)\n' "$1" "$2" "$3"; fi; }
manual() { active || return 0
  case "$1" in decide) D_TOTAL=$((D_TOTAL+1)) ;; rehearse) R_TOTAL=$((R_TOTAL+1)) ;; esac
  if [ -n "$MARKDOWN" ]; then printf -- '- [ ] **%s** %s _(%s)_: ______\n' "$2" "$3" "$1"
  else printf '%-9s %-5s %s\n' "$1" "$2" "$3"; fi; }

# --- the admin CLI -----------------------------------------------------
kcadm() { docker compose -f "$ROOT/compose.yaml" exec -T keycloak \
            /opt/keycloak/bin/kcadm.sh "$@" 2>/dev/null; }

# Das Labor faehrt HTTPS-only. KC_HOSTNAME steht in VERSIONS.mk und
# ist der Name, auf den das Zertifikat aus Kapitel 2 ausgestellt ist -
# eine IP oder localhost scheitert an der Pruefung, nicht am Passwort.
# kcadm laeuft ueber 'exec' INNERHALB des containers. Dort lauscht
# Keycloak auf 8443; KC_HOSTNAME nennt den Port, unter dem der HOST es
# erreicht. Von innen mit dem Host-Port anzufragen gibt 'Connection
# refused' - dieselbe Falle wie im make-ziel kcadm-login.
if [ -z "${KC_URL:-}" ] && [ -f "$ROOT/VERSIONS.mk" ]; then
  KC_URL="$(awk -F= '/^KC_HOSTNAME=/{print $2}' "$ROOT/VERSIONS.mk"):8443"
fi
KC_URL="${KC_URL:-https://localhost:8443}"

HAVE_API=
if [ -n "$KC_PASS" ] && kcadm config credentials \
     --server "$KC_URL" --realm master \
     --user "$KC_ADMIN" --password "$KC_PASS" >/dev/null 2>&1; then
  HAVE_API=1
  REALM_JSON="$(kcadm get "realms/$KC_REALM" || echo '{}')"
else
  REALM_JSON='{}'
fi
r() { printf '%s' "$REALM_JSON" | jq -r ".$1 // empty" 2>/dev/null; }
noapi() { skip "$1" "$2" "$NOAPI_WHY"; }
NOAPI_WHY="no admin API access"
[ -z "${HAVE_API:-}" ] && [ -n "${KC_PASS:-}" ] \
  && NOAPI_WHY="admin login failed - run 'make kcadm-init' first"

# --- 1 identity and naming --------------------------------------------
section identity "1 · Identity and naming"
FE="$(r 'attributes.frontendUrl')"
if [ -n "$HAVE_API" ]; then
  [ -n "$FE" ] && pass 1.1 "issuer is fixed: $FE" \
    || fail 1.1 "no frontendUrl - the issuer follows the request Host header"
  case "$FE" in
    https://*:*) fail 1.2 "issuer carries an explicit port" ;;
    https://*)   pass 1.2 "https, default port" ;;
    "")          skip 1.2 "https on the default port" "no frontendUrl set" ;;
    *)           fail 1.2 "issuer is not https" ;;
  esac
else
  noapi 1.1 "the issuer is a fixed, configured value"
  noapi 1.2 "https on the default port"
fi
manual decide 1.3 "The certificate is one every consumer trusts, including out-of-band clients"
ADM="$(r 'attributes.adminUrl')"
if [ -n "$HAVE_API" ]; then
  [ -n "$ADM" ] && [ "$ADM" != "$FE" ] \
    && pass 1.4 "admin console on its own hostname" \
    || fail 1.4 "admin console shares the issuer hostname"
else noapi 1.4 "the admin console is on a separate hostname"; fi

# --- 2 realms and tenancy ---------------------------------------------
section realms "2 · Realms and tenancy"
if [ -n "$HAVE_API" ]; then
  N="$(kcadm get realms --fields realm 2>/dev/null | jq 'length' 2>/dev/null)"
  [ -n "$N" ] && pass 2.1 "$N realm(s) defined" \
    || skip 2.1 "each realm corresponds to a population" "realm list unreadable"
  MU="$(kcadm get users -r master 2>/dev/null | jq 'length' 2>/dev/null)"
  if [ -n "$MU" ]; then
    [ "$MU" -le 5 ] && pass 2.2 "master holds $MU account(s)" \
      || fail 2.2 "master holds $MU accounts - it should hold administrators only"
  else skip 2.2 "master contains only administrators" "user list unreadable"; fi
  if kcadm get users -r master -q username=admin 2>/dev/null \
     | jq -e '.[0].username == "admin"' >/dev/null 2>&1; then
    fail 2.3 "the bootstrap 'admin' account still exists"
  else
    pass 2.3 "no bootstrap 'admin' account in master"
  fi
else
  noapi 2.1 "each realm corresponds to a population"
  noapi 2.2 "master contains only administrators"
  noapi 2.3 "the bootstrap admin account is gone"
fi
manual decide 2.4 "Realm creation is automated, not clicked"

# --- 3 people and permissions -----------------------------------------
section people "3 · People and permissions"
if [ -n "$HAVE_API" ]; then
  IDP="$(kcadm get "identity-provider/instances" -r "$KC_REALM" 2>/dev/null \
         | jq 'length' 2>/dev/null)"
  UF="$(kcadm get "components?type=org.keycloak.storage.UserStorageProvider" \
        -r "$KC_REALM" 2>/dev/null | jq 'length' 2>/dev/null)"
  if [ "${IDP:-0}" -gt 0 ] || [ "${UF:-0}" -gt 0 ]; then
    pass 3.1 "a directory or identity provider is federated"
  else
    fail 3.1 "no federation - accounts are local to Keycloak"
  fi
else noapi 3.1 "the directory owns accounts"; fi
manual decide 3.2 "Roles are granted through groups only"
manual decide 3.3 "You can list who holds a privileged role, on demand"
manual decide 3.4 "Disabling in the directory ends access"
manual rehearse 3.5 "You have measured how long that takes"

# --- 4 tokens ----------------------------------------------------------
section tokens "4 · Tokens"
manual decide 4.1 "Every API validates the aud claim"
if [ -n "$HAVE_API" ]; then
  C="$(kcadm get clients -r "$KC_REALM" --fields clientId 2>/dev/null \
       | jq 'length' 2>/dev/null)"
  [ -n "$C" ] && pass 4.2 "$C clients defined" \
    || skip 4.2 "one client per application" "client list unreadable"
  FS="$(kcadm get clients -r "$KC_REALM" --fields clientId,fullScopeAllowed \
        2>/dev/null | jq '[.[]|select(.fullScopeAllowed==true)]|length' 2>/dev/null)"
  if [ -n "$FS" ]; then
    [ "$FS" -eq 0 ] && pass 4.5 "full scope is off everywhere" \
      || fail 4.5 "$FS client(s) have full scope allowed"
  else skip 4.5 "full scope is switched off where it can be" "client list unreadable"; fi
else
  noapi 4.2 "one client per application"
  noapi 4.5 "full scope is switched off where it can be"
fi
manual decide 4.3 "You have measured your largest token"
manual decide 4.4 "You know your gateway's header limit"

# --- 5 sessions --------------------------------------------------------
section sessions "5 · Sessions"
if [ -n "$HAVE_API" ]; then
  AT="$(r accessTokenLifespan)"; SI="$(r ssoSessionIdleTimeout)"
  SM="$(r ssoSessionMaxLifespan)"
  if [ -n "$AT" ]; then
    pass 5.1 "access ${AT}s, idle ${SI}s, max ${SM}s - confirm these were chosen"
  else skip 5.1 "the lifetimes were chosen deliberately" "realm unreadable"; fi
  OF="$(r offlineSessionMaxLifespanEnabled)"
  [ -n "$OF" ] && pass 5.3 "offline session max lifespan enabled: $OF" \
    || skip 5.3 "you know who holds offline tokens" "realm unreadable"
else
  noapi 5.1 "the lifetimes were chosen deliberately"
  noapi 5.3 "you know who holds offline tokens"
fi
manual decide 5.2 "Back-channel logout is implemented where sessions matter"
manual decide 5.4 "You can revoke offline tokens"

# --- 6 authentication strength ----------------------------------------
section auth "6 · Authentication strength"
if [ -n "$HAVE_API" ]; then
  BF="$(r bruteForceProtected)"
  [ "$BF" = true ] && pass 6.0 "brute force protection on" \
    || fail 6.0 "brute force protection is off"
  OTP="$(kcadm get "authentication/required-actions" -r "$KC_REALM" 2>/dev/null \
         | jq -r '[.[]|select(.alias=="CONFIGURE_TOTP" and .enabled==true)]|length' 2>/dev/null)"
  [ "${OTP:-0}" -gt 0 ] && pass 6.1 "TOTP enrolment is available" \
    || fail 6.1 "TOTP required action is not enabled"
else
  noapi 6.0 "brute force protection"
  noapi 6.1 "a second factor is required, and for whom"
fi
manual decide 6.2 "There is an enrolment path for everyone required to have one"
manual rehearse 6.3 "The recovery process for a lost device has been tested"
manual decide 6.4 "Applications requesting step-up check the acr claim"

# --- 7 kubernetes ------------------------------------------------------
section kubernetes "7 · Kubernetes"
manual decide 7.1 "Keycloak is outside the cluster it authenticates"
manual decide 7.2 "A break-glass kubeconfig exists and works"
manual rehearse 7.3 "It was last tested on a date you can name"
manual decide 7.4 "Client certificates are otherwise removed"
manual decide 7.5 "Proxied applications have a network policy"

# --- 8 secrets ---------------------------------------------------------
section secrets "8 · Secrets"
if [ -f "$ROOT/.env" ] && git -C "$ROOT" check-ignore -q .env 2>/dev/null; then
  pass 8.1 ".env is git-ignored"
elif [ -f "$ROOT/.env" ]; then
  fail 8.1 ".env exists and is NOT git-ignored"
else
  skip 8.1 "the database credential is outside version control" "no .env here"
fi
manual decide 8.2 "Secret rotation is paired with a restart"
manual decide 8.3 "You know when each secret last changed"
manual decide 8.4 "Client secrets are generated rather than chosen"

# --- 9 the cold start --------------------------------------------------
section coldstart "9 · The cold start"
manual decide 9.1 "The start ordering is expressed in code, not documented in prose"
manual decide 9.2 "A break-glass path into Vault exists"
manual decide 9.3 "Its use is alerted on"
manual rehearse 9.4 "It was last tested on a date you can name"
manual decide 9.5 "You have drawn the dependency graph"

# --- 10 availability ---------------------------------------------------
section availability "10 · Availability"
if [ -n "$HAVE_API" ]; then
  SI="$(kcadm get serverinfo 2>/dev/null)"
  V="$(printf '%s' "$SI" | jq -r '.systemInfo.version // empty' 2>/dev/null)"
  [ -n "$V" ] && pass 12.5 "running Keycloak $V - confirm it is still supported" \
    || skip 12.5 "the running version is still supported" "serverinfo unreadable"
else noapi 12.5 "the running version is still supported"; fi
manual decide 10.1 "More than one instance, and the cluster has formed"
manual decide 10.2 "Cluster size is alerted on"
manual decide 10.3 "You size for logins rather than requests"
manual decide 10.4 "The availability target names its dependencies"

# --- 11 recovery -------------------------------------------------------
section recovery "11 · Recovery"
manual decide 11.1 "There is a database backup, not a realm export"
manual rehearse 11.2 "A restore has been performed and the kid compared"
manual decide 11.3 "The runbook says what to do about sessions"
manual decide 11.4 "It names the credential it needs"
manual decide 11.5 "You have a measured recovery time"

# --- 12 change and upgrade ---------------------------------------------
section change "12 · Change and upgrade"
manual decide 12.1 "The realm is reconciled from code"
manual decide 12.2 "There is a console break-glass, and it is reconciled"
manual rehearse 12.3 "An upgrade has been rehearsed against a copy"
manual decide 12.4 "You know your migration window"

# --- 13 evidence -------------------------------------------------------
section evidence "13 · Evidence"
if [ -n "$HAVE_API" ]; then
  EV="$(kcadm get "events/config" -r "$KC_REALM" 2>/dev/null)"
  LE="$(printf '%s' "$EV" | jq -r '.eventsEnabled // empty' 2>/dev/null)"
  AE="$(printf '%s' "$EV" | jq -r '.adminEventsEnabled // empty' 2>/dev/null)"
  AD="$(printf '%s' "$EV" | jq -r '.adminEventsDetailsEnabled // empty' 2>/dev/null)"
  EX="$(printf '%s' "$EV" | jq -r '.eventsExpiration // empty' 2>/dev/null)"
  [ "$LE" = true ] && pass 13.1 "login events on" || fail 13.1 "login events are off"
  if [ "$AE" = true ] && [ "$AD" = true ]; then
    pass 13.2 "admin events on, with details"
  elif [ "$AE" = true ]; then
    fail 13.2 "admin events on but WITHOUT details - the what is missing"
  else
    fail 13.2 "admin events are off"
  fi
  [ -n "$EX" ] && pass 13.4 "event retention ${EX}s" \
    || fail 13.4 "no event expiration set - retention is unbounded or zero"
else
  noapi 13.1 "login events are on, with chosen retention"
  noapi 13.2 "admin events are on, with details"
  noapi 13.4 "retention covers the questions you expect"
fi
manual decide 13.3 "Events carry real client addresses, not the proxy's"

# --- 14 handover -------------------------------------------------------
section handover "14 · Handover"
manual decide 14.1 "There is a list of every credential outside the directory"
manual decide 14.2 "There is a dependency statement"
manual decide 14.3 "There are three rehearsal dates"
manual rehearse 14.4 "Somebody else has followed the runbook unaided"

# --- summary -----------------------------------------------------------
if [ -n "$MARKDOWN" ]; then
  printf '\n## Summary\n\n'
  printf -- '- automated: %s of %s passed, %s failed, %s not checked\n' \
    "$A_PASS" "$A_TOTAL" "$A_FAIL" "$A_SKIP"
  printf -- '- decide: %s items nobody can check for you\n' "$D_TOTAL"
  printf -- '- rehearse: %s items you have to have actually done\n' "$R_TOTAL"
else
  printf '\n== Summary\n'
  printf '  automated  %s of %s passed, %s failed, %s not checked\n' \
    "$A_PASS" "$A_TOTAL" "$A_FAIL" "$A_SKIP"
  printf '  decide     %s items nobody can check for you\n' "$D_TOTAL"
  printf '  rehearse   %s items you have to have actually done\n' "$R_TOTAL"
  printf '\n  A section with an unanswered decide is not a failing section.\n'
  printf '  It is an incomplete review, which is a different and more\n'
  printf '  honest state.\n'
fi

[ "$A_FAIL" -eq 0 ]
