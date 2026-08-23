#!/usr/bin/env bash
# Chapter 24's checklist, executed.
#
# Chapter 24 lists fifty-two things that must be true before other
# people depend on your Vault. This runs the ones a machine can run and
# lists the ones it cannot. An item nobody can check for you is not a
# failure - it is an unanswered question, and the summary counts those
# separately on purpose.
#
#   ./scripts/readiness.sh
#   ./scripts/readiness.sh --section seal
#   ./scripts/readiness.sh --markdown > REVIEW.md
#
# Point it at the installation you actually run, not at the lab:
#   VAULT_ADDR, VAULT_TOKEN, VAULT_CACERT   the API
#   VAULT_CONFIG=/etc/vault.d/vault.hcl     the server configuration
#   DATA_DIR=/opt/vault/data                permissions and headroom
#   DOCS=./docs                             where the runbooks live
#
# Anything missing turns its checks into skips rather than failures.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
DOCS="${DOCS:-$ROOT/docs}"

SECTION=""; MARKDOWN=""
while [ $# -gt 0 ]; do
  case "$1" in
    --section)  SECTION="${2:?a section name}"; shift 2 ;;
    --markdown) MARKDOWN=1; shift ;;
    -h|--help)  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

# --- inputs -----------------------------------------------------------
HAVE_API=
if [ -n "${VAULT_ADDR:-}" ] && vault status -format=json >/dev/null 2>&1; then
  HAVE_API=1
  ST="$(vault status -format=json 2>/dev/null || echo '{}')"
else
  ST='{}'
fi
st() { printf '%s' "$ST" | jq -r ".$1 // empty" 2>/dev/null; }
cfg_has() { [ -n "${VAULT_CONFIG:-}" ] && [ -r "$VAULT_CONFIG" ] \
            && grep -qE "$1" "$VAULT_CONFIG"; }
have_cfg() { [ -n "${VAULT_CONFIG:-}" ] && [ -r "${VAULT_CONFIG:-}" ]; }

# --- 1 deployment -----------------------------------------------------
section deployment "1 · Deployment"
manual decide 1.1 "Configuration is in version control and deployed by automation"

case "${VAULT_ADDR:-}" in
  https://*) pass 1.2 "clients reach Vault over TLS" ;;
  "")        skip 1.2 "TLS with a certificate clients trust" "VAULT_ADDR unset" ;;
  *)         fail 1.2 "VAULT_ADDR is not https" ;;
esac

if have_cfg; then
  if cfg_has '^\s*disable_mlock\s*=\s*true'; then
    manual decide 1.3 "disable_mlock is true - confirm swap is off on this host"
  else
    pass 1.3 "disable_mlock is not set true"
  fi
else skip 1.3 "disable_mlock matches the platform" "VAULT_CONFIG not readable"; fi

if [ -n "${DATA_DIR:-}" ] && [ -d "$DATA_DIR" ]; then
  OWN="$(stat -c '%U' "$DATA_DIR" 2>/dev/null || stat -f '%Su' "$DATA_DIR")"
  [ "$OWN" != "root" ] && pass 1.4 "data directory owned by $OWN, not root" \
    || fail 1.4 "data directory is owned by root"
  MODE="$(stat -c '%a' "$DATA_DIR" 2>/dev/null || stat -f '%Lp' "$DATA_DIR")"
  [ "$MODE" = "700" ] && pass 1.5 "data directory is 0700" \
    || fail 1.5 "data directory is $MODE, expected 0700"
else
  skip 1.4 "Vault runs as a dedicated unprivileged user" "DATA_DIR not set"
  skip 1.5 "data directory is 0700" "DATA_DIR not set"
fi

if have_cfg; then
  cfg_has '^\s*api_addr' && pass 1.6 "api_addr set explicitly" \
    || fail 1.6 "api_addr is not set"
  cfg_has '^\s*cluster_addr' && pass 1.7 "cluster_addr set explicitly" \
    || fail 1.7 "cluster_addr is not set"
else
  skip 1.6 "api_addr set explicitly" "VAULT_CONFIG not readable"
  skip 1.7 "cluster_addr set explicitly" "VAULT_CONFIG not readable"
fi

S="$(st storage_type)"
if [ -n "$S" ]; then
  case "$S" in
    raft|consul) pass 1.8 "storage is $S" ;;
    *)           fail 1.8 "storage is $S - not Raft or Consul" ;;
  esac
else skip 1.8 "storage backend is Raft or Consul" "no API access"; fi

N="$(vault operator raft list-peers -format=json 2>/dev/null \
     | jq '.data.config.servers|length' 2>/dev/null)"
[ -n "$N" ] && { [ "$N" -ge 3 ] && pass 1.9 "$N nodes" \
  || fail 1.9 "only $N node(s) - three is the minimum"; } \
  || skip 1.9 "at least three nodes" "no peer list"

manual decide 1.10 "The load balancer accepts only HTTP 200 from /sys/health"

# --- 2 seal -----------------------------------------------------------
section seal "2 · Seal"
SEALTYPE="$(st type)"
if [ -n "$SEALTYPE" ]; then
  if [ "$SEALTYPE" = "shamir" ]; then
    manual decide 2.1 "Shamir seal: the manual unseal procedure is documented and rehearsed"
  else
    pass 2.1 "auto-unseal configured ($SEALTYPE)"
  fi
else skip 2.1 "auto-unseal or a rehearsed manual procedure" "no API access"; fi

if have_cfg; then
  if grep -qiE '(secret_key|client_secret|password|token)\s*=\s*"[^"]{8,}"' \
       "$VAULT_CONFIG" 2>/dev/null; then
    fail 2.2 "a credential appears to be inline in the configuration file"
  else
    pass 2.2 "no inline credential found in the configuration"
  fi
else skip 2.2 "seal credential outside the configuration file" "VAULT_CONFIG not readable"; fi

manual decide 2.3 "The seal token is periodic, and its TTL is monitored"
manual decide 2.4 "The unsealer does not depend on the thing it unseals"
manual decide 2.5 "Recovery keys are with different people, retrievable out of hours"
[ -s "$DOCS/unsealing.md" ] && pass 2.6 "docs/unsealing.md exists" \
  || fail 2.6 "no docs/unsealing.md naming who holds which share"
manual decide 2.7 "A share holder leaving triggers a rekey - revoking a share is not possible"
manual rehearse 2.8 "The current quorum has actually been assembled, and the time recorded"

# --- 3 identity and access -------------------------------------------
section identity "3 · Identity and access"
if [ -n "$HAVE_API" ]; then
  if vault token lookup -format=json 2>/dev/null \
     | jq -e '.data.policies|index("root")' >/dev/null 2>&1; then
    fail 3.1 "you are operating as root right now"
  else
    pass 3.1 "not operating as root"
  fi
else skip 3.1 "the initial root token is revoked" "no API access"; fi

AUTHS="$(vault auth list -format=json 2>/dev/null || echo '{}')"
if [ "$AUTHS" != '{}' ]; then
  if printf '%s' "$AUTHS" | jq -e 'to_entries[]|select(.value.type=="oidc" or .value.type=="ldap" or .value.type=="jwt")' >/dev/null 2>&1; then
    pass 3.2 "a corporate identity method is enabled"
  else
    fail 3.2 "no OIDC, JWT or LDAP - humans are using local credentials"
  fi
  if printf '%s' "$AUTHS" | jq -e 'to_entries[]|select(.value.type=="approle" or .value.type=="kubernetes" or .value.type=="aws" or .value.type=="gcp" or .value.type=="azure")' >/dev/null 2>&1; then
    pass 3.3 "a machine identity method is enabled"
  else
    fail 3.3 "no machine auth method - applications are using tokens by hand"
  fi
else
  skip 3.2 "humans authenticate through the identity provider" "no API access"
  skip 3.3 "machines use platform identity or AppRole" "no API access"
fi

SUDO=0
for p in $(vault policy list -format=json 2>/dev/null | jq -r '.[]?' 2>/dev/null); do
  case "$p" in root|default) continue ;; esac
  vault policy read "$p" 2>/dev/null | grep -q '"sudo"' && SUDO=$((SUDO+1))
done
if [ -n "$HAVE_API" ]; then
  [ "$SUDO" -eq 0 ] && pass 3.4 "no non-default policy grants sudo" \
    || fail 3.4 "$SUDO policies grant sudo - each needs a written reason"
else skip 3.4 "no policy grants sudo without a written reason" "no API access"; fi

manual decide 3.5 "Root tokens are generated for a task and revoked afterwards"
manual decide 3.6 "AppRole SecretIDs are response-wrapped and single-use"
manual decide 3.7 "Every policy is scoped to a path, not to a mount"
manual decide 3.8 "destroy and metadata delete are withheld from applications"
manual decide 3.9 "Token TTLs are deliberate, not left at 768 hours"

# --- 4 secrets --------------------------------------------------------
section secrets "4 · Secrets"
MOUNTS="$(vault secrets list -format=json 2>/dev/null || echo '{}')"
if [ "$MOUNTS" != '{}' ]; then
  KV2=$(printf '%s' "$MOUNTS" | jq '[to_entries[]|select(.value.options.version=="2")]|length' 2>/dev/null)
  [ "${KV2:-0}" -ge 1 ] && pass 4.1 "$KV2 kv-v2 mount(s)" \
    || fail 4.1 "no kv version 2 mount - no versioning, no cas"
else skip 4.1 "static secrets are in key/value v2" "no API access"; fi

manual decide 4.2 "max_versions is set per path, not left at the default"
manual decide 4.3 "cas-required on any path more than one system writes"
manual decide 4.4 "Dynamic credentials wherever the target system permits them"
manual decide 4.5 "rotate-root has been run on every database and cloud connection"
manual decide 4.6 "An emergency account exists OUTSIDE Vault for each such system"
manual decide 4.7 "PKI: root offline, intermediate in Vault, tidy scheduled"
manual decide 4.8 "The CA's own expiry is monitored, not only the leaf certificates"

# --- 5 audit and monitoring ------------------------------------------
section audit "5 · Audit and monitoring"
AUD="$(vault audit list -format=json 2>/dev/null || echo '{}')"
NA="$(printf '%s' "$AUD" | jq 'keys|length' 2>/dev/null)"
if [ -n "$NA" ]; then
  [ "$NA" -ge 2 ] && pass 5.1 "$NA audit devices" \
    || fail 5.1 "only $NA audit device - one sink is a hard dependency"
  if printf '%s' "$AUD" | jq -e '[to_entries[]|.value.options.log_raw]|any(.=="true")' >/dev/null 2>&1; then
    fail 5.2 "log_raw is true on at least one device - secrets in the clear"
  else
    pass 5.2 "log_raw is false everywhere"
  fi
else
  skip 5.1 "two audit devices with different failure modes" "no API access"
  skip 5.2 "log_raw is false everywhere" "no API access"
fi

if [ -n "${VAULT_ADDR:-}" ]; then
  M="$(curl -s ${VAULT_CACERT:+--cacert "$VAULT_CACERT"} \
       "$VAULT_ADDR/v1/sys/metrics?format=prometheus" 2>/dev/null \
       | grep -c '^# TYPE')"
  [ "${M:-0}" -gt 20 ] && pass 5.3 "telemetry returns $M metric families" \
    || fail 5.3 "telemetry returned ${M:-0} families - check prometheus_retention_time"
else skip 5.3 "telemetry enabled and scraped" "VAULT_ADDR unset"; fi

manual decide 5.4 "Audit logs are shipped off the host as they are written"
manual decide 5.5 "Log rotation is configured, with copytruncate"
manual decide 5.6 "Free space on the audit volume is alerted before it matters"
manual decide 5.7 "Alerts exist on: /sys/health, lease growth, seal token TTL, certificate expiry"

# --- 6 operations -----------------------------------------------------
section operations "6 · Operations"
SNAP="$(mktemp -t readiness-snap.XXXXXX)"
if vault operator raft snapshot save "$SNAP" >/dev/null 2>&1; then
  pass 6.1 "a snapshot can be taken ($(wc -c < "$SNAP" | tr -d ' ') bytes)"
else
  skip 6.1 "snapshots on a schedule" "no API access, or not Raft, or not the active node"
fi
rm -f "$SNAP"

manual decide 6.2 "Encryption key rotation happens, automatically or on a calendar"
manual decide 6.3 "The seal type is recorded alongside every snapshot"
manual decide 6.4 "The upgrade procedure is written: standbys first, step-down, leader last"
manual decide 6.5 "Configuration is applied by Terraform, not by hand"
manual rehearse 6.6 "A restore has been rehearsed on a calendar, and recorded"
manual rehearse 6.7 "Quorum-loss recovery has been rehearsed at least once"
manual rehearse 6.8 "Somebody other than the author has performed each procedure"

# --- 7 documentation --------------------------------------------------
section documentation "7 · Documentation"
[ -s "$DOCS/runbook.md" ] && pass 7.1 "docs/runbook.md exists" \
  || fail 7.1 "no docs/runbook.md - sealed, quorum lost, audit stuck, KMS down"
if [ -d "$DOCS" ] && ls "$DOCS"/adr* >/dev/null 2>&1; then
  pass 7.2 "architecture decision records present"
else
  fail 7.2 "no architecture decision records in $DOCS"
fi
manual decide 7.3 "A named owner, and a named deputy"

# --- summary ----------------------------------------------------------
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
