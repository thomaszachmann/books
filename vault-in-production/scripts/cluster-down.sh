#!/usr/bin/env bash
# Stop the nodes. Data, certificates and configs survive.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1
docker compose down
echo "Stopped. Data kept - 'make reset' removes it."
