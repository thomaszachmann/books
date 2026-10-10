#!/bin/sh
# Führt jeden Testordner einzeln aus und schreibt pro Ordner eine JUnit-Datei.
# kyverno test -o junit mischt Log-Zeilen und Summary in stdout - sed schneidet sie ab.
set -u
mkdir -p reports
rc=0
for d in tests/*/; do
  n=$(basename "$d")
  kyverno test "$d" --remove-color -o junit > "reports/$n.raw" 2>&1 || rc=1
  sed -n '/^<?xml/,/^<\/testsuites>/p' "reports/$n.raw" > "reports/kyverno-$n.xml"
  rm -f "reports/$n.raw"
done
[ "$rc" -eq 0 ] || kyverno test . --remove-color --fail-only
exit "$rc"
