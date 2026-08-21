#!/usr/bin/env sh
# Answer three questions about the SCAP content, offline.
#
#   ./profiles.sh products              how many products exist
#   ./profiles.sh has <profile>         which products ship that profile
#   ./profiles.sh of <product>          which profiles that product ships
#   ./profiles.sh compare <p> [p ...]   a table for the candidates
#   ./profiles.sh --refresh <clone>     rebuild products.tsv from a clone
#
# products.tsv is a dated snapshot, so this works in an isolated network.
# Refresh it deliberately and read the diff.
set -eu
export LC_ALL=C
D=$(dirname "$0")
T="$D/products.tsv"

rows() { grep -v '^#' "$T"; }

case "${1:-}" in
products) rows | cut -f1 ;;
has)      rows | awk -F'\t' -v p="$2" \
            '{n=split($3,a," "); for(i=1;i<=n;i++) if(a[i]==p) print $1}' ;;
of)       rows | awk -F'\t' -v p="$2" '$1==p {print $3}' | tr ' ' '\n' ;;
compare)  shift
          printf '%-12s %5s  %s\n' product count "bsi stig cis anssi"
          for p in "$@"; do
            l=$(rows | awk -F'\t' -v p="$p" '$1==p {print $3}')
            c=$(rows | awk -F'\t' -v p="$p" '$1==p {print $2}')
            m=""
            for k in bsi stig cis anssi; do
              case "$l" in *"$k"*) m="$m yes" ;; *) m="$m  no" ;; esac
            done
            printf '%-12s %5s %s\n' "$p" "${c:-0}" "$m"
          done ;;
--refresh)
          c="$2"
          { printf '# product\tcount\tprofiles\n'
            printf '# Regenerated from %s\n' "$c"
            for d in "$c"/products/*/profiles; do
              p=$(basename "$(dirname "$d")")
              v=$(ls "$d" | sed 's/\.profile$//' | sort | tr '\n' ' ')
              printf '%s\t%s\t%s\n' "$p" "$(echo "$v" | wc -w | tr -d ' ')" \
                "$(echo "$v" | sed 's/ *$//')"
            done
          } > "$T" ;;
*)        sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//' ;;
esac
