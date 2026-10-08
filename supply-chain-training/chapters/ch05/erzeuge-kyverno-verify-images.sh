#!/usr/bin/env bash
# Kapitel 5, Schritt 9 - Befehle wörtlich aus dem Buch.
cd ~/seclab/kap05
{
cat <<'EOF'
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: demo-app-signiert
spec:
  validationFailureAction: Enforce
  webhookTimeoutSeconds: 30
  rules:
    - name: cosign-signatur-pruefen
      match:
        any:
          - resources:
              kinds: ["Pod"]
              namespaces: ["demo"]
      verifyImages:
        - imageReferences:
            - "reg-build:5000/demo-app*"
            - "reg-ziel:5000/demo-app*"
          mutateDigest: true
          verifyDigest: true
          required: true
          attestors:
            - entries:
                - keys:
                    rekor:
                      ignoreTlog: true
                    ctlog:
                      ignoreSCT: true
                    publicKeys: |-
EOF
sed 's/^/                      /' cosign.pub
} > kyverno-verify-images.yaml

yq '.spec.rules[0].verifyImages[0].attestors[0].entries[0].keys.publicKeys' \
  kyverno-verify-images.yaml
