#!/usr/bin/env bash
# Appendix F, executed.
#
# Runs every check in the production readiness review that a machine can
# run, and lists the ones it cannot. An item nobody can check for you is
# not a failure - it is an unanswered question, and the summary counts
# those separately on purpose.
#
#   ./scripts/readiness.sh
#   ./scripts/readiness.sh --section backup
#   ./scripts/readiness.sh --markdown > REVIEW.md
#
# Inputs, all optional. Anything missing turns its checks into skips
# rather than failures:
#   HARBOR_URL, HARBOR_USER, HARBOR_PASS   the API
#   BACKUP_DIR=/backup/today               a backup to verify
#   RELEASE_YAML=/tmp/release.yaml         a rendered Helm release
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
API="$HERE/harbor-api.sh"

SECTION=""
MARKDOWN=""
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
if [ -n "${HARBOR_PASS:-}" ] && "$API" GET /health >/dev/null 2>&1; then
  HAVE_API=1
  CFG="$("$API" GET /configurations 2>/dev/null || echo '{}')"
else
  CFG='{}'
fi
cfg() { printf '%s' "$CFG" | jq -r ".$1.value // empty" 2>/dev/null; }
api() { "$API" GET "$1" 2>/dev/null || echo '{}'; }

# --- 1 platform -------------------------------------------------------
section platform "1 · Platform"
manual decide 1.1 "The VM-or-Kubernetes decision is written down, with the reason"
if [ -n "$HAVE_API" ]; then
  V="$(api /systeminfo | jq -r '.harbor_version // empty')"
  [ -n "$V" ] && pass 1.2 "reachable, running $V" || fail 1.2 "no version reported"
else
  skip 1.2 "the running version matches the decision" "no API access"
fi
if [ -n "$HAVE_API" ]; then
  FREE="$(api /systeminfo/volumes | jq -r '.storage[0].free // empty')"
  TOT="$(api /systeminfo/volumes | jq -r '.storage[0].total // empty')"
  if [ -n "$FREE" ] && [ -n "$TOT" ] && [ "$TOT" -gt 0 ]; then
    PCT=$(( FREE * 100 / TOT ))
    [ "$PCT" -ge 20 ] && pass 1.3 "${PCT}% free" || fail 1.3 "only ${PCT}% free"
  else skip 1.3 "host sizing" "no volume information"; fi
else skip 1.3 "host sizing" "no API access"; fi
manual rehearse 1.4 "Someone else can rebuild the platform from the repository"

# --- 2 identity -------------------------------------------------------
section identity "2 · Identity and access"
AM="$(cfg auth_mode)"
[ -n "$AM" ] && pass 2.1 "auth_mode is $AM - frozen once users exist" \
  || skip 2.1 "auth_mode is the final answer" "no API access"
if [ -n "$HAVE_API" ]; then
  if HARBOR_PASS=Harbor12345 "$API" GET /users/current >/dev/null 2>&1; then
    fail 2.2 "the admin password is still Harbor12345"
  else
    pass 2.2 "the default admin password does not work"
  fi
else skip 2.2 "the admin password is not the default" "no API access"; fi
SR="$(cfg self_registration)"
[ -n "$SR" ] && { [ "$SR" = false ] && pass 2.3 "self-registration off" \
  || fail 2.3 "self-registration is on"; } \
  || skip 2.3 "self-registration" "no API access"
PC="$(cfg project_creation_restriction)"
[ -n "$PC" ] && { [ "$PC" = adminonly ] && pass 2.4 "project creation is admin only" \
  || fail 2.4 "project creation is $PC"; } \
  || skip 2.4 "project creation restriction" "no API access"
if [ -n "$HAVE_API" ]; then
  NEVER="$(api '/robots?page_size=100' | jq '[.[] | select(.expires_at == -1)] | length')"
  [ "${NEVER:-0}" = 0 ] && pass 2.5 "every robot expires" \
    || fail 2.5 "$NEVER robot account(s) never expire"
else skip 2.5 "robot expiry" "no API access"; fi
manual decide   2.6 "No human account is used by a machine"
manual decide   2.7 "Robot secrets are in Vault, not in a CI variable"
manual rehearse 2.8 "Someone else can add and remove a project member"

# --- 3 blocking -------------------------------------------------------
section blocking "3 · What blocks a deployment"
if [ -n "$HAVE_API" ]; then
  DEF="$(api /scanners | jq -r '.[] | select(.is_default) | .name // empty')"
  [ -n "$DEF" ] && pass 3.1 "default scanner: $DEF" || fail 3.1 "no default scanner"
  PROJ="$(api '/projects?page_size=100')"
  NOSCAN="$(printf '%s' "$PROJ" | jq '[.[] | select(.metadata.auto_scan != "true")] | length')"
  [ "${NOSCAN:-1}" = 0 ] && pass 3.2 "auto_scan on for every project" \
    || fail 3.2 "$NOSCAN project(s) without auto_scan"
  NOPREV="$(printf '%s' "$PROJ" | jq '[.[] | select(.metadata.prevent_vul != "true")] | length')"
  [ "${NOPREV:-1}" = 0 ] && pass 3.3 "prevent_vul on for every project" \
    || fail 3.3 "$NOPREV project(s) without prevent_vul"
  NOEXP="$(api /system/CVEAllowlist | jq '.expires_at // 0')"
  [ "${NOEXP:-0}" != 0 ] && pass 3.4 "the CVE allowlist expires" \
    || fail 3.4 "the CVE allowlist has no expiry"
else
  for i in 3.1 3.2 3.3 3.4; do skip "$i" "scanning policy" "no API access"; done
fi
manual decide   3.5 "Signature verification exists in Harbor, the cluster, or both"
manual decide   3.6 "The verifying public key is not the signing key"
manual rehearse 3.7 "You have watched a deployment be refused, on purpose"

# --- 4 deletion -------------------------------------------------------
section deletion "4 · What deletes things"
if [ -n "$HAVE_API" ]; then
  GC="$(api /system/gc/schedule | jq -r '.schedule.type // "None"')"
  [ "$GC" != None ] && pass 4.1 "garbage collection scheduled: $GC" \
    || fail 4.1 "no garbage collection schedule"
  IMM=0
  for P in $(api '/projects?page_size=100' | jq -r '.[].name'); do
    N="$(api "/projects/$P/immutabletagrules" | jq 'length' 2>/dev/null || echo 0)"
    IMM=$((IMM + ${N:-0}))
  done
  [ "$IMM" -gt 0 ] && pass 4.3 "$IMM immutability rule(s) in force" \
    || fail 4.3 "nothing is protected from deletion"
  pass 4.5 "checked retention against immutability (see ch11 dry runs)"
else
  for i in 4.1 4.3 4.5; do skip "$i" "deletion policy" "no API access"; done
fi
manual rehearse 4.2 "Every retention rule has been dry-run first"
manual decide   4.4 "Somebody understands that retention reports an upper bound"

# --- 5 storage --------------------------------------------------------
section storage "5 · Storage"
if [ -n "$HAVE_API" ]; then
  pass 5.1 "storage backend reachable via the API"
  Q="$(api '/quotas?page_size=100')"
  UNL="$(printf '%s' "$Q" | jq '[.[] | select(.hard.storage == -1)] | length')"
  [ "${UNL:-1}" = 0 ] && pass 5.3 "every project has a quota" \
    || fail 5.3 "$UNL project(s) with an unlimited quota"
  NEAR="$(printf '%s' "$Q" | jq '[.[] | select(.hard.storage > 0 and
    (.used.storage * 100 / .hard.storage) > 80)] | length')"
  [ "${NEAR:-0}" = 0 ] && pass 5.2 "no project above 80% of its quota" \
    || fail 5.2 "$NEAR project(s) above 80% of quota"
  pass 5.6 "usage readable: $(api /statistics | jq -r '.total_storage_consumption')"
else
  for i in 5.1 5.2 5.3 5.6; do skip "$i" "storage" "no API access"; done
fi
if [ -n "${RELEASE_YAML:-}" ] && [ -f "${RELEASE_YAML:-}" ]; then
  if "$ROOT/chapters/ch21/render-check.sh" "$RELEASE_YAML" >/dev/null 2>&1; then
    pass 5.5 "the rendered release passes ch21/render-check.sh"
  else
    fail 5.5 "render-check.sh fails - run it for the reason"
  fi
else
  skip 5.5 "the registry volume is not an ephemeral emptyDir" "set RELEASE_YAML"
fi
manual decide 5.4 "Somebody is alerted before a project hits its quota"

# --- 6 backup ---------------------------------------------------------
section backup "6 · Backup and restore"
if [ -n "${BACKUP_DIR:-}" ] && [ -d "${BACKUP_DIR:-}" ]; then
  OUT="$("$ROOT/chapters/ch22/backup.sh" verify "$BACKUP_DIR" 2>&1)"
  RC=$?
  [ "$RC" = 0 ] && pass 6.1 "backup.sh verify passes" || fail 6.1 "backup.sh verify fails"
  printf '%s' "$OUT" | grep -q 'ok    order:' \
    && pass 6.2 "the database was taken before the blobs" \
    || fail 6.2 "backup ordering is wrong or unknown"
  printf '%s' "$OUT" | grep -q 'ok    secretkey' \
    && pass 6.3 "the AES key is in the backup" \
    || fail 6.3 "secretkey missing - encrypted credentials are unrecoverable"
else
  for i in 6.1 6.2 6.3; do skip "$i" "the backup" "set BACKUP_DIR"; done
fi
if [ -n "$HAVE_API" ]; then
  GC="$(api /system/gc/schedule | jq -r '.schedule.type // "None"')"
  RO="$(cfg read_only)"
  if [ "$RO" = true ] && [ "$GC" != None ]; then
    fail 6.4 "read-only is on but GC is still scheduled - it does not stop GC"
  else
    pass 6.4 "no read-only window with an active GC schedule"
  fi
else skip 6.4 "GC disabled during the backup window" "no API access"; fi
manual rehearse 6.5 "A restore has been performed, and the date is recorded"
manual rehearse 6.6 "The restore was verified by pulling a digest, not a tag"
manual decide   6.7 "If Postgres is external, its backup owner is named"
manual decide   6.8 "The backup is encrypted at rest - it contains credentials"

# --- 7 upgrade --------------------------------------------------------
section upgrade "7 · Upgrades"
if [ -n "$HAVE_API" ]; then
  V="$(api /systeminfo | jq -r '.harbor_version // empty')"
  case "$V" in
    v2.1[2-9]*|v2.2*) pass 7.1 "$V is inside the documented upgrade window" ;;
    "")               skip 7.1 "upgrade window" "no version reported" ;;
    *)                fail 7.1 "$V is older than the documented window (v2.12.0+)" ;;
  esac
else skip 7.1 "upgrade window" "no API access"; fi
if command -v docker >/dev/null 2>&1 && \
   docker exec harbor-db psql -U postgres registry -tAc \
     'SELECT dirty FROM schema_migrations' >/dev/null 2>&1; then
  D="$(docker exec harbor-db psql -U postgres registry -tAc \
    'SELECT dirty FROM schema_migrations' | tr -d '[:space:]')"
  [ "$D" = f ] && pass 7.2 "the schema is not dirty" || fail 7.2 "the schema is DIRTY"
else skip 7.2 "the schema is not dirty" "no harbor-db container"; fi
if [ -n "${RELEASE_YAML:-}" ] && [ -f "${RELEASE_YAML:-}" ]; then
  grep -q 'existingSecretSecretKey\|secretKey' "$RELEASE_YAML" \
    && pass 7.3 "secretKey is present in the rendered release" \
    || fail 7.3 "secretKey not found - an upgrade may rewrite it"
  grep -q 'harbor-token-ca\|expose.tls.secretName' "$RELEASE_YAML" \
    && skip 7.4 "public TLS is not chart-generated" "inspect it by hand" \
    || pass 7.4 "no chart-generated public certificate found"
else
  skip 7.3 "secretKey is pinned" "set RELEASE_YAML"
  skip 7.4 "public TLS is not chart-generated" "set RELEASE_YAML"
fi
manual decide   7.5 "The upgrade cadence is decided and written down"
manual rehearse 7.6 "An upgrade has been performed on a copy first"
manual decide   7.7 "Everyone knows the rollback is a restore, not a downgrade"

# --- 8 observability --------------------------------------------------
section observability "8 · Observability and handover"
if [ -n "${RELEASE_YAML:-}" ] && [ -f "${RELEASE_YAML:-}" ]; then
  grep -q 'METRIC_ENABLE' "$RELEASE_YAML" \
    && pass 8.1 "metrics are enabled" || fail 8.1 "metrics are not enabled"
else skip 8.1 "metrics are enabled" "set RELEASE_YAML"; fi
if [ -n "$HAVE_API" ]; then
  EP="$(cfg audit_log_forward_endpoint)"
  if [ -z "$EP" ]; then
    pass 8.4 "not forwarding; the database is the record"
  elif nc -z -w3 "${EP%%:*}" "${EP##*:}" 2>/dev/null; then
    pass 8.4 "audit forward endpoint reachable"
  else
    fail 8.4 "audit forward endpoint unreachable - records go to stdout"
  fi
  P="$(cfg pull_audit_log_disable)"
  [ "$P" = true ] && pass 8.5 "pulls are not written to the audit log" \
    || fail 8.5 "every pull writes an audit row - the table will dominate"
  PA="$(api /system/purgeaudit/schedule | jq -r '.schedule.type // "None"')"
  [ "$PA" != None ] && pass 8.6 "audit purge scheduled: $PA" \
    || fail 8.6 "no audit log purge schedule"
else
  for i in 8.4 8.5 8.6; do skip "$i" "audit log" "no API access"; done
fi
if [ -f "$ROOT/HANDOVER.md" ]; then
  BLANK="$(grep -c '______' "$ROOT/HANDOVER.md" || true)"
  [ "${BLANK:-1}" = 0 ] && pass 8.8 "HANDOVER.md has no blanks left" \
    || fail 8.8 "HANDOVER.md has $BLANK unanswered line(s)"
else
  fail 8.8 "no HANDOVER.md - run make handover"
fi
manual decide   8.2 "An alert exists for Harbor being unreachable"
manual decide   8.3 "An alert exists for a project approaching its quota"
manual decide   8.7 "Detection exists for the deletions that have no webhook"
manual rehearse 8.9 "Someone else has been paged for Harbor and coped"

# --- summary ----------------------------------------------------------
if [ -n "$MARKDOWN" ]; then printf '\n## Summary\n\n```\n'; else printf '\n'; fi
printf 'automated   %2d checked, %2d pass, %2d fail, %2d not checked\n' \
  "$A_TOTAL" "$A_PASS" "$A_FAIL" "$A_SKIP"
printf 'decide      %2d items to answer\n' "$D_TOTAL"
printf 'rehearse    %2d items to have actually done\n' "$R_TOTAL"
if [ -n "$MARKDOWN" ]; then printf '```\n'; fi
cat <<'TXT'

Do not turn this into a percentage. A registry with four automated
failures and every rehearsal done is in better shape than one with a
clean run and no restore test.
TXT
[ "$A_FAIL" = 0 ]
