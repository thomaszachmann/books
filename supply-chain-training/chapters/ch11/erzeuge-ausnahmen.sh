#!/usr/bin/env bash
# Kapitel 11, Schritt 3 - Befehle wörtlich aus dem Buch.
mkdir -p ci
cp ~/seclab/kap10/check-exceptions.sh ~/seclab/kap10/check-trivyignore.sh ci/
CREATED=$(date -u +%F)
EXPIRES=$(date -u -d '+60 days' +%F 2>/dev/null || date -u -v+60d +%F)
CVES="CVE-2023-32681 CVE-2024-35195 CVE-2024-47081 CVE-2026-25645"

cat > exceptions.yaml <<EOF
exceptions:
  - id: EXC-2026-001
    type: vulnerability
    target: demo-app
    reference: "pkg:pypi/requests@2.25.0"
    findings: [$(echo $CVES | sed 's/ /, /g')]
    reason: "Upgrade requests bricht Altclient, Migration in demo-app 1.2.0"
    risk: medium
    compensation: "Kein verify=False (Semgrep-Regel), kein .netrc im Image"
    owner: team-demo@example.org
    approver: security@example.org
    ticket: SEC-123
    created: "${CREATED}"
    expires: "${EXPIRES}"
EOF

echo "vulnerabilities:" > .trivyignore.yaml
for c in $CVES; do
  cat >> .trivyignore.yaml <<EOF
  - id: ${c}
    purls: ["pkg:pypi/requests@2.25.0"]
    statement: "EXC-2026-001: Migration requests in 1.2.0"
    expired_at: ${EXPIRES}
EOF
done

ci/check-exceptions.sh exceptions.yaml
ci/check-trivyignore.sh .trivyignore.yaml exceptions.yaml
