#!/usr/bin/env bash
# Build a dockerconfigjson the way the operator's template does, and
# check one that already exists.
#
# A pull secret is a JSON document with a particular shape, and clients
# disagree about which part they read. Docker's client reads
# username/password and constructs auth itself; containerd reads auth.
# Emit both, or a laptop keeps working while the cluster stops - the
# worst possible split, because the person debugging it can pull.
#
#   ./dockerconfig.sh build 'robot$platform+cluster-pull' "$SECRET"
#   ./dockerconfig.sh check  <namespace> [secret-name]
set -euo pipefail

HOST="${HARBOR_HOSTNAME:-harbor.meridian.test}"

case "${1:-}" in
  build)
    U="${2:?robot name, in SINGLE quotes}"
    P="${3:?robot secret}"
    jq -n --arg h "$HOST" --arg u "$U" --arg p "$P" \
      '{auths: {($h): {username: $u, password: $p,
                       auth: ($u + ":" + $p | @base64)}}}'
    ;;
  check)
    NS="${2:?namespace}"
    SEC="${3:-harbor}"
    json="${DOCKERCONFIG_JSON:-$(kubectl -n "$NS" get secret "$SEC" \
      -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d)}"

    fail=0
    while IFS= read -r host; do
      u=$(printf '%s' "$json" | jq -r --arg h "$host" '.auths[$h].username // ""')
      p=$(printf '%s' "$json" | jq -r --arg h "$host" '.auths[$h].password // ""')
      a=$(printf '%s' "$json" | jq -r --arg h "$host" '.auths[$h].auth // ""')

      echo "host      $host"
      echo "username  $u"

      case "$u" in
        *'$'*) ;;
        robot*)
          echo "  WARNING the name has no \$ - a shell ate the project"
          echo "          before this reached Vault. See Chapter 16."
          fail=1 ;;
      esac

      if [ -z "$a" ]; then
        echo "  WARNING no auth field. containerd reads auth; Docker's"
        echo "          client does not, so a laptop will keep working"
        echo "          while the cluster stops."
        fail=1
      elif [ "$(printf '%s' "$a" | base64 -d 2>/dev/null)" != "$u:$p" ]; then
        echo "  WRONG   auth is not base64 of username:password"
        fail=1
      else
        echo "  ok      auth matches username:password"
      fi
    done <<< "$(printf '%s' "$json" | jq -r '.auths | keys[]')"
    exit "$fail"
    ;;
  *) echo "usage: $0 build <user> <secret> | check <ns> [name]" >&2; exit 2 ;;
esac
