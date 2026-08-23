#!/usr/bin/env bash
# kube-bench gegen RKE2 - mit der zahl, die dazugehoert.
#
# Der punkt dieses skripts ist die BENCHMARK-VERSION. Derselbe
# cluster, dieselbe minute, drei benchmarks:
#
#   rke2-cis-1.24   50 PASS   11 FAIL
#   rke2-cis-1.7    52 PASS    9 FAIL
#   rke2-cis-1.8    73 PASS    3 FAIL
#
# Eine punktzahl ohne benchmark-version ist keine messung. Wer den
# benchmark nach dem ergebnis waehlt, hat noch weniger gezeigt.
#
#   ./bench.sh              der gepinnte benchmark
#   ./bench.sh --all        alle vier, zum vergleich
#   ./bench.sh --json       fuer die nachweismappe
set -uo pipefail

BENCH="${BENCH:-rke2-cis-1.8}"
KB="${KB:-kube-bench}"
CFG="${CFG:-}"
command -v "$KB" >/dev/null 2>&1 || KB=/tmp/kubebench/kube-bench
[ -n "$CFG" ] || { [ -d /tmp/kubebench/cfg ] && CFG=/tmp/kubebench/cfg; }
CFGARG=${CFG:+--config-dir $CFG}

run() { sudo "$KB" run --benchmark "$1" $CFGARG 2>/dev/null; }

case "${1:-}" in
  --all)
    for b in rke2-cis-1.23 rke2-cis-1.24 rke2-cis-1.7 rke2-cis-1.8; do
      s=$(run "$b" | sed -n '/^== Summary total/,$p' | head -3 | tail -2 | tr '\n' ' ')
      printf '  %-16s %s\n' "$b" "$s"
    done
    cat <<'TXT'

  Vier zahlen, ein cluster. Die spanne ist kein fehler: 1.23 und
  1.24 sind nach kubernetes-versionen benannt, 1.7 und 1.8 nach
  versionen des CIS-benchmarks selbst.
TXT
    ;;
  --json)
    sudo "$KB" run --benchmark "$BENCH" $CFGARG --json 2>/dev/null
    ;;
  *)
    echo "== $BENCH gegen $(kubectl version 2>/dev/null | awk '/Server/{print $3}') =="
    run "$BENCH" | sed -n '/^== Summary total/,$p' | head -6
    echo
    echo "== die audit-pruefungen, und was sie wirklich bedeuten =="
    run "$BENCH" | grep -E '^\[(PASS|FAIL)\] (1\.2\.1[7-9]|1\.2\.20|3\.2\.1)' \
      | cut -c1-72
    POL=/etc/rancher/rke2/audit-policy.yaml
    if sudo test -r "$POL"; then
      LVL=$(sudo grep -oE 'level: [A-Za-z]+' "$POL" | head -1 | awk '{print $2}')
      echo
      printf '  Audit-policy: level: %s\n' "${LVL:-?}"
      if [ "$LVL" = "None" ]; then
        echo "  ACHTUNG: alle audit-pruefungen bestehen und es wird"
        echo "  NICHTS aufgezeichnet. Kapitel 12 misst das nach."
        P=$(sudo grep -o 'audit-log-path=[^ ]*' \
            /var/lib/rancher/rke2/agent/pod-manifests/kube-apiserver.yaml \
            2>/dev/null | head -1 | cut -d= -f2)
        [ -n "$P" ] && sudo test -e "$P" \
          && printf '  %s: %s bytes\n' "$P" "$(sudo stat -c%s "$P")"
      fi
    fi
    ;;
esac
