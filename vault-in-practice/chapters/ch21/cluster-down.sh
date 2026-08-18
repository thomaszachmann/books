#!/usr/bin/env bash
# Chapter 21 - remove the cluster. The single-node lab is untouched.
set -uo pipefail
cd "$(dirname "$0")/../.."
docker compose -f docker-compose.cluster.yml down 2>/dev/null
rm -rf cluster/data1 cluster/data2 cluster/data3
echo "Cluster removed. cluster/init.json and the certs are kept."
