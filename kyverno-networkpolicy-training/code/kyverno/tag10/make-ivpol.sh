#!/usr/bin/env bash
# make-ivpol.sh <cosign.pub> <glob> > verify-shop-images.yaml  (Tag 10)
set -euo pipefail
PUB=${1:-cosign.pub}; GLOB=${2:-kind-registry:5000/shop/*}
cat <<EOF
# Lab-Policy (Tag 10): Shop-Images aus kind-registry nur signiert und mit SBOM
apiVersion: policies.kyverno.io/v1
kind: ImageValidatingPolicy
metadata:
  name: verify-shop-images
spec:
  validationActions: [Deny]
  webhookConfiguration:
    timeoutSeconds: 15
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: [v1]
        operations: [CREATE, UPDATE]
        resources: [pods]
  matchImageReferences:
    - glob: "${GLOB}"
  attestors:
    - name: lab
      cosign:
        key:
          data: |
$(sed 's/^/            /' "$PUB")
        ctlog:
          insecureIgnoreTlog: true
          insecureIgnoreSCT: true
  attestations:
    - name: sbom
      intoto:
        type: https://spdx.dev/Document
  validations:
    - message: "Image ist nicht mit dem Lab-Key signiert."
      expression: >-
        images.containers.map(i, verifyImageSignatures(i, [attestors.lab]))
        .all(n, n > 0)
    - message: "Keine signierte SPDX-SBOM am Image."
      expression: >-
        images.containers.map(i, verifyAttestationSignatures(i,
          attestations.sbom, [attestors.lab])).all(n, n > 0)
    - message: "SBOM ist kein SPDX-2.3-Dokument mit Paketen."
      expression: >-
        images.containers.map(i, extractPayload(i, attestations.sbom))
        .all(p, p.predicate.spdxVersion == 'SPDX-2.3' &&
          size(p.predicate.packages) > 0)
EOF
