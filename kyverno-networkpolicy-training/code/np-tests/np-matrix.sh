#!/usr/bin/env bash
# np-matrix.sh - Testmatrix für NetworkPolicies: von -> nach, Soll gegen Ist
#
#   np-matrix.sh [--md] <matrix.tsv>
#
#   matrix.tsv  Zeilen "<ns>/<pod|app> <url> allow|deny", # = Kommentar
#   --md        Ausgabe als Markdown-Tabelle (z. B. für $GITHUB_STEP_SUMMARY)
#
# Exit 0 = alles wie erwartet, 1 = mindestens eine Abweichung, 2 = Aufruffehler.
# CC zeigt auf conncheck.sh (Standard: ~/guard-lab/code/demo/conncheck.sh).
set -uo pipefail

md=false
[[ ${1:-} == --md ]] && { md=true; shift; }
file=${1:-}
cc=${CC:-$HOME/guard-lab/code/demo/conncheck.sh}
if [[ -z $file || ! -r $file ]]; then
  echo "Aufruf: $0 [--md] <matrix.tsv>" >&2
  exit 2
fi

if $md; then
  echo "| von | nach | soll | ist |"
  echo "|---|---|---|---|"
else
  printf '%-22s %-34s %-6s %s\n' VON NACH SOLL IST
fi

ok=0 bad=0
while read -r src url want _; do
  [[ -z ${src:-} || $src == \#* ]] && continue
  "$cc" "$src" "$url" </dev/null >/dev/null 2>&1
  case $? in
    0) got=allow ;;
    1) got=deny ;;
    *) got=error ;;
  esac
  if [[ $got == "$want" ]]; then mark="✔"; ok=$((ok + 1))
  else mark="✘"; bad=$((bad + 1)); fi
  if $md; then
    echo "| \`$src\` | \`$url\` | $want | $mark $got |"
  else
    printf '%-22s %-34s %-6s %s %s\n' "$src" "$url" "$want" "$mark" "$got"
  fi
done < "$file"

echo
echo "$((ok + bad)) Tests: $ok ✔, $bad ✘"
[[ $bad -eq 0 ]]
