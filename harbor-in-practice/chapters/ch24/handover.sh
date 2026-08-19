#!/usr/bin/env bash
# Produce the handover document: what the system does, and blanks for
# why it does it.
#
# The blanks are the point. A handover that lists commands is a runbook;
# a handover answers the eight questions the next person will ask, and
# only you can answer the second half of each one.
#
#   ./handover.sh > HANDOVER.md
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
API="$HERE/../../scripts/harbor-api.sh"

live() { "$API" GET "$1" 2>/dev/null || echo '{}'; }

CFG="$(live /configurations)"
val() { printf '%s' "$CFG" | jq -r ".$1.value // \"unknown\""; }

cat <<EOF
# Harbor handover

Generated $(date -u +%Y-%m-%dT%H:%M:%SZ). The **why** lines are blank on
purpose. Fill them in; nobody else can.

## 1. Platform — VM or Kubernetes (Chapter 17)

- Running on: _______________________
- Why: _______________________

## 2. Identity and access (Chapters 5, 6, 7)

- auth_mode: \`$(val auth_mode)\` — **frozen once users exist**
- Self-registration: \`$(val self_registration)\`
- Project creation restricted to: \`$(val project_creation_restriction)\`
- Robot accounts and where their secrets live: _______________________
- Why this model: _______________________

## 3. What blocks a deployment (Chapters 9, 10, 16)

- Scanning: $(live /scanners | jq -r '.[] | select(.is_default) | .name // "none"')
- Projects with prevent_vul, and the severity: _______________________
- Signature verification, and where the public key lives: ____________
- Why these and not others: _______________________

## 4. What deletes things (Chapter 11)

- GC schedule: \`$(live /system/gc/schedule | jq -r '.schedule.type // "None"')\`
- Retention policies in force: _______________________
- Immutability rules: _______________________
- Why: _______________________

## 5. Storage (Chapters 12, 21)

- Backend: _______________________
- Quota defaults: \`$(val storage_per_project)\`
- What happens when it fills, and who is told: _______________________

## 6. Backup and restore (Chapter 22)

- Backup location: _______________________
- Schedule: _______________________
- **Last verified restore:** _______________________
- Who owns the database backup: _______________________

## 7. Upgrades (Chapter 23)

- Current version: $(live /systeminfo | jq -r '.harbor_version // "unknown"')
- Cadence: _______________________
- Rollback is a restore, not a downgrade. Rehearsed on: ______________

## 8. Observability (Chapter 24)

- Metrics scraped: _______________________
- Webhook policies: $(live /projects | jq -r 'length') projects to review
- audit_log_forward_endpoint: \`$(val audit_log_forward_endpoint)\`
- skip_audit_log_database: \`$(val skip_audit_log_database)\`
- pull_audit_log_disable: \`$(val pull_audit_log_disable)\`
- Who is paged, and what they are expected to do: ____________________

---

Nine of Harbor's nineteen event topics have no webhook, including every
project, repository, tag and robot creation and deletion. Anything you
need to know about those comes from the audit log — check the forward
endpoint is reachable, because a failed dial falls back to stdout after
one error line.
EOF
