#!/usr/bin/env bash
# Tag 0, Kontrollpunkt - Befehle wörtlich aus dem Buch.
for t in bao kind kubectl helm jq curl docker; do
  command -v "$t" >/dev/null && echo "✔ $t" || echo "✘ $t fehlt"
done
[ -d ~/bao-lab/k8s ] && echo "✔ ~/bao-lab" || echo "✘ ~/bao-lab fehlt"
docker info >/dev/null 2>&1 && echo "✔ Docker-Daemon" || echo "✘ Docker-Daemon"
type labenv >/dev/null 2>&1 && echo "✔ labenv" || echo "✘ labenv"
