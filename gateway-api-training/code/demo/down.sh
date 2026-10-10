#!/usr/bin/env bash
# Löscht den Lab-Cluster komplett.
set -euo pipefail
kind delete cluster --name "${CLUSTER:-gw-lab}"
