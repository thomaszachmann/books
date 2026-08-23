#!/usr/bin/env bash
# Appendix G, executed.
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
# Point it at the installation you actually run, not at the lab:
#   VAULT_ADDR, VAULT_TOKEN, VAULT_CACERT   the API
#   EVIDENCE=./evidence                     where your pages live
#   DATA_DIR=/opt/vault/data                to check disk headroom
#   K8S=1                                   include the Kubernetes section
#
# Anything missing turns its checks into skips rather than failures.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
EVIDENCE="${EVIDENCE:-$ROOT/evidence}"

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

have_file() { [ -s "$EVIDENCE/$1" ]; }

# --- inputs -----------------------------------------------------------
HAVE_API=
if [ -n "${VAULT_ADDR:-}" ] && vault status -format=json >/dev/null 2>&1; then
  HAVE_API=1
  ST="$(vault status -format=json 2>/dev/null || echo '{}')"
else
  ST='{}'
fi
st() { printf '%s' "$ST" | jq -r ".$1 // empty" 2>/dev/null; }
AP="$(vault operator raft autopilot state -format=json 2>/dev/null || echo '{}')"
ap() { printf '%s' "$AP" | jq -r ".$1 // empty" 2>/dev/null; }

# --- 1 platform -------------------------------------------------------
section platform "1 · Platform (Chapters 2, 4)"
if [ -n "$HAVE_API" ]; then
  S="$(st storage_type)"
  [ "$S" != "inmem" ] && pass 1.1 "storage is $S" || fail 1.1 "storage is in-memory"
else skip 1.1 "storage is not in-memory" "no API access"; fi

N="$(vault operator raft list-peers -format=json 2>/dev/null \
     | jq '.data.config.servers|length' 2>/dev/null)"
[ -n "$N" ] && { [ "$N" -gt 1 ] && pass 1.2 "$N nodes" \
  || fail 1.2 "only $N node"; } || skip 1.2 "more than one node" "no peer list"

case "${VAULT_ADDR:-}" in
  https://*) pass 1.3 "TLS in use" ;;
  "")        skip 1.3 "TLS in use" "VAULT_ADDR unset" ;;
  *)         fail 1.3 "VAULT_ADDR is not https" ;;
esac

V="$(st version)"
[ -n "$V" ] && pass 1.4 "running $V" || skip 1.4 "version recorded" "no API access"
manual decide 1.5 "The node count and their failure domains are written down"
manual decide 1.6 "The TLS certificate's expiry is diarised, and it is not issued by this Vault"
manual rehearse 1.7 "Someone other than you can rebuild a node from the repository"

# --- 2 the cluster ----------------------------------------------------
section cluster "2 · The cluster (Chapters 5, 6)"
FT="$(ap FailureTolerance)"
[ -n "$FT" ] && { [ "$FT" -ge 1 ] && pass 2.1 "failure tolerance $FT" \
  || fail 2.1 "failure tolerance is $FT"; } \
  || skip 2.1 "failure tolerance at least 1" "no autopilot state"

H="$(ap Healthy)"
[ -n "$H" ] && { [ "$H" = true ] && pass 2.2 "autopilot reports healthy" \
  || fail 2.2 "autopilot reports unhealthy"; } \
  || skip 2.2 "autopilot healthy" "no autopilot state"

DEAD="$(printf '%s' "$AP" | jq '[.Servers[]?|select(.Healthy==false)]|length' 2>/dev/null)"
[ -n "$DEAD" ] && { [ "$DEAD" -eq 0 ] && pass 2.3 "no unhealthy peers" \
  || fail 2.3 "$DEAD unhealthy peer(s) still in the configuration"; } \
  || skip 2.3 "no dead peers left in the raft configuration" "no autopilot state"

manual decide 2.4 "The upgrade order is written down: standbys first, leader last"
manual rehearse 2.5 "A node has been lost and replaced, and failure tolerance came back"
manual rehearse 2.6 "A version upgrade has been done without an outage window"

# --- 3 keys and ceremonies -------------------------------------------
section keys "3 · Keys and ceremonies (Chapters 3, 7, 8)"
if [ -n "$HAVE_API" ]; then
  T="$(st t)"; NS="$(st n)"
  if [ -n "$T" ] && [ -n "$NS" ]; then
    [ "$T" -ge 2 ] && pass 3.1 "threshold $T of $NS" \
      || fail 3.1 "threshold is $T - one person can unseal alone"
  else skip 3.1 "threshold is at least 2" "no seal information"; fi
else skip 3.1 "threshold is at least 2" "no API access"; fi

if vault token lookup -format=json 2>/dev/null \
   | jq -e '.data.policies|index("root")' >/dev/null 2>&1; then
  fail 3.2 "you are using a root token right now"
else
  [ -n "$HAVE_API" ] && pass 3.2 "not operating as root" \
    || skip 3.2 "the initial root token is revoked" "no API access"
fi

if [ -f "$ROOT/cluster/init.json" ]; then
  fail 3.3 "init.json is still on disk - keys and root token in one file"
else
  pass 3.3 "no init.json lying around"
fi

manual decide 3.4 "Every share has a named holder, and no two are on one team"
manual decide 3.5 "The operator who runs a ceremony is not a key holder"
manual decide 3.6 "A departure or an exposure triggers a rekey, and somebody outside this team knows that"
manual rehearse 3.7 "Threshold-many holders have been reached on one call, and the time was recorded"
manual rehearse 3.8 "A rekey has been completed, with verification"
manual rehearse 3.9 "A break-glass has been run, and the audit line was found afterwards"

# --- 4 backup and recovery -------------------------------------------
section backup "4 · Backup and recovery (Chapters 9, 10, 11)"
SNAP="$(mktemp -t readiness-snap.XXXXXX)"
if vault operator raft snapshot save "$SNAP" >/dev/null 2>&1; then
  SZ=$(wc -c < "$SNAP" | tr -d ' ')
  pass 4.1 "a snapshot can be taken ($SZ bytes)"
  if vault operator raft snapshot inspect "$SNAP" >/dev/null 2>&1; then
    pass 4.2 "the snapshot inspects cleanly"
  else
    fail 4.2 "the snapshot does not inspect - it was written by a process that died"
  fi
else
  skip 4.1 "a snapshot can be taken" "no API access or not the active node"
  skip 4.2 "the snapshot inspects cleanly" "no snapshot"
fi
rm -f "$SNAP"

have_file restore-drill.txt \
  && pass 4.3 "a restore drill is on file: $(head -1 "$EVIDENCE/restore-drill.txt" | cut -c1-48)" \
  || fail 4.3 "no restore drill recorded in $EVIDENCE/restore-drill.txt"

manual decide 4.4 "Snapshots are stored somewhere the unseal keys are NOT"
manual decide 4.5 "vault.hcl, the TLS material and the version pin are archived beside the snapshot"
manual decide 4.6 "One named person may declare a disaster, with a named deputy and a measurable trigger"
manual rehearse 4.7 "A snapshot has been restored on a host that never held the seal, and timed"
manual rehearse 4.8 "Yesterday's snapshot has been fetched with Vault switched off"

# --- 5 kubernetes -----------------------------------------------------
if [ -n "${K8S:-}" ]; then
  section kubernetes "5 · Kubernetes (Chapter 12)"
  manual decide 5.1 "The chart's raft config has retry_join, or the join is a documented step"
  manual decide 5.2 "Anti-affinity is on, or somebody accepted three pods on one node"
  manual decide 5.3 "Snapshot jobs address vault-active, never the round-robin service"
  manual decide 5.4 "The snapshot destination leaves the cluster"
  manual decide 5.5 "Who unseals a pod that comes back sealed at three in the morning"
  manual rehearse 5.6 "A pod has been deleted and the replacement was unsealed by somebody on the rota"
fi

# --- 6 degradation ----------------------------------------------------
section degradation "6 · Degradation (Chapters 13, 14, 15)"
AUD="$(vault audit list -format=json 2>/dev/null || echo '{}')"
NA="$(printf '%s' "$AUD" | jq 'keys|length' 2>/dev/null)"
if [ -n "$NA" ]; then
  [ "$NA" -ge 2 ] && pass 6.1 "$NA audit devices" \
    || fail 6.1 "only $NA audit device - the collector is a hard dependency"
  if printf '%s' "$AUD" | jq -e 'to_entries[]|select(.value.type=="file")' >/dev/null 2>&1; then
    pass 6.2 "one of them is local"
  else
    fail 6.2 "no local file device - a network sink can lock you out"
  fi
else
  skip 6.1 "two audit devices" "no API access"
  skip 6.2 "one of them is local" "no API access"
fi

manual decide 6.3 "Every dynamic role's creation statement carries an expiry clause"
manual decide 6.4 "VAULT_CLIENT_TIMEOUT is set in every client"
manual decide 6.5 "Each consumer's time-to-notice is recorded, per Chapter 13's table"
manual decide 6.6 "Applications that cannot re-authenticate without a restart are listed, with who restarts them"
manual decide 6.7 "Every dependency loop is written down, dated, with a named owner"
manual rehearse 6.8 "Vault has been stopped and the blast radius observed, including what broke on recovery"
manual rehearse 6.9 "The remote audit sink has been removed for three minutes and Vault kept serving"

# --- 7 growth ---------------------------------------------------------
section growth "7 · Growth (Chapter 16)"
LC="$(vault list -format=json sys/leases/lookup/auth/token/create 2>/dev/null \
      | jq 'length // 0' 2>/dev/null)"
[ -n "$LC" ] && pass 7.1 "token leases readable: $LC" \
  || skip 7.1 "lease counts are readable" "no API access or no permission"

have_file lease-baseline.txt \
  && pass 7.2 "a lease baseline is on file" \
  || fail 7.2 "no lease baseline in $EVIDENCE/lease-baseline.txt - there is no slope without one"

if [ -n "${DATA_DIR:-}" ] && [ -d "$DATA_DIR" ]; then
  PCT="$(df -P "$DATA_DIR" 2>/dev/null | awk 'NR==2{gsub("%","",$5); print 100-$5}')"
  [ -n "$PCT" ] && { [ "$PCT" -ge 20 ] && pass 7.3 "${PCT}% free on the data directory" \
    || fail 7.3 "only ${PCT}% free - and revoking leases will not give it back"; } \
    || skip 7.3 "disk headroom" "df gave nothing"
else
  skip 7.3 "disk headroom on the data directory" "DATA_DIR not set"
fi

manual decide 7.4 "Token type per auth role is decided: batch tokens cannot be revoked"
manual decide 7.5 "Lease counts by prefix are recorded on a schedule, and the alert is on the slope"
manual rehearse 7.6 "A node has been rebuilt to reclaim disk, because revocation does not"

# --- 8 observability --------------------------------------------------
section observability "8 · Observability (Chapters 17, 18, 19)"
if [ -n "${VAULT_ADDR:-}" ]; then
  M="$(curl -s ${VAULT_CACERT:+--cacert "$VAULT_CACERT"} \
       "$VAULT_ADDR/v1/sys/metrics?format=prometheus" 2>/dev/null \
       | grep -c '^# TYPE')"
  [ "${M:-0}" -gt 20 ] && pass 8.1 "metrics endpoint returns $M families" \
    || fail 8.1 "metrics endpoint returned ${M:-0} families - check prometheus_retention_time"
else skip 8.1 "the metrics endpoint returns data" "VAULT_ADDR unset"; fi

manual decide 8.2 "The seal alert uses max without (cluster) - the naive one fires on a healthy leader"
manual decide 8.3 "At least one alert is about absence, because a sealed node stops exporting"
manual decide 8.4 "Every alert names the failure it detects, or it is deleted"
manual decide 8.5 "The audit log can be read during an incident by somebody who is not root"
manual decide 8.6 "Client identity is looked up by entity_id, not display_name"
manual decide 8.7 "Baseline latencies and the harness overhead are recorded"
manual decide 8.8 "Clients reuse connections, and point at the active node rather than a standby"
manual rehearse 8.9 "Each of the ten alerts has fired against the failure it claims to detect"

# --- 9 secret zero ----------------------------------------------------
section secretzero "9 · Secret zero (Chapter 20)"
manual decide 9.1 "Secret zero is delivered wrapped, with a TTL matching real delivery time"
manual decide 9.2 "The consumer checks creation_path before unwrapping"
manual decide 9.3 "A failed unwrap is treated as compromise, not as a retry"
manual decide 9.4 "The deliverer of secret zero does not authenticate against this Vault"
manual decide 9.5 "The last link in the trust chain is named: people, hardware, or a provider"
manual rehearse 9.6 "The trust chain has been walked with somebody from another team"

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
