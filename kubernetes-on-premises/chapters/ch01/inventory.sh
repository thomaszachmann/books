#!/usr/bin/env sh
# Extract the external dependencies of a manifest bundle.
#
# Three classes, and the class is the useful part:
#
#   image     something that has to be pulled from a registry
#   control   a request that needs a controller to fulfil it
#   endpoint  a network destination outside the cluster
#
# What it does NOT find is the subject of the exercises in Chapter 1:
# dependencies expressed as bare hostnames rather than URLs, and Helm
# repository aliases resolved on the client. Both are in the bundle.
set -eu
export LC_ALL=C

DIR="${1:-workload}"

body() {
  find "$DIR" -type f \( -name '*.yaml' -o -name '*.yml' \) | sort |
  while IFS= read -r f; do
    b=$(basename "$f")

    sed -n 's/^ *image: *//p' "$f" |
      while IFS= read -r v; do printf 'image,%s,%s\n' "$v" "$b"; done

    sed -n 's/^ *type: *\(LoadBalancer\) *$/\1/p' "$f" |
      while IFS= read -r v; do printf 'control,%s,%s\n' "$v" "$b"; done

    sed -n 's/^ *storageClassName: *//p' "$f" |
      while IFS= read -r v; do printf 'control,%s,%s\n' "$v" "$b"; done

    sed -n 's/^ *ingressClassName: *//p' "$f" |
      while IFS= read -r v; do printf 'control,%s,%s\n' "$v" "$b"; done

    # A kind the API server does not know without a controller having
    # installed the definition first.
    sed -n 's/^kind: *\(Certificate\) *$/\1/p' "$f" |
      while IFS= read -r v; do printf 'control,%s,%s\n' "$v" "$b"; done

    grep -ohE 'https?://[^"[:space:]]+' "$f" 2>/dev/null |
      sed -e 's|https\{0,1\}://||' -e 's|/.*||' | sort -u |
      while IFS= read -r v; do printf 'endpoint,%s,%s\n' "$v" "$b"; done
  done
}

printf 'class,value,source\n'
body | sort -t, -k1,1 -k2,2 -u
