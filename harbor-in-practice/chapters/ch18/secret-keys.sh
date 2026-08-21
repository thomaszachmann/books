#!/usr/bin/env bash
# The chart's secret hooks, and the key each one insists on.
#
# Seven hooks, seven different key names, two length requirements, and
# none of the names is one you would choose. A wrong key does not fail
# at install time - the component comes up with an empty or generated
# value and misbehaves later, which is worse than an error.
#
#   ./secret-keys.sh                 # print the mapping
#   ./secret-keys.sh check <secret>  # check a live secret against it
set -euo pipefail

# chart value            required key            length
MAP='
existingSecretAdminPassword|HARBOR_ADMIN_PASSWORD|-
existingSecretSecretKey|secretKey|16
core.existingSecret|secret|16
core.existingXsrfSecret|CSRF_KEY|32
jobservice.existingSecret|JOBSERVICE_SECRET|-
registry.existingSecret|REGISTRY_HTTP_SECRET|-
database.external.existingSecret|password|-
'

if [ "${1:-}" != check ]; then
  printf '%-34s %-22s %s\n' 'CHART VALUE' 'KEY IN THE SECRET' 'LEN'
  printf '%s' "$MAP" | while IFS='|' read -r v k l; do
    [ -n "$v" ] || continue
    printf '%-34s %-22s %s\n' "$v" "$k" "$l"
  done
  cat <<'TXT'

The key names are what the chart insists on, not what anybody would
choose. Generate the secret from one definition so that no name is ever
retyped - see the ExternalSecret in Chapter 18, step 4.
TXT
  exit 0
fi

SEC="${2:?a secret name}"
NS="${NS:-harbor}"
json="${SECRET_JSON:-$(kubectl -n "$NS" get secret "$SEC" -o json)}"

# A while loop on the right of a pipe runs in a subshell, so anything it
# sets is lost and the script exits 0 whatever it found. A check that
# cannot fail is not a check. Feed the loop from a here-string instead.
fail=0
while IFS='|' read -r v k l; do
  [ -n "$k" ] || continue
  val=$(printf '%s' "$json" | jq -r --arg k "$k" '.data[$k] // empty')
  if [ -z "$val" ]; then
    printf '  absent  %-22s (for %s)\n' "$k" "$v"
    continue
  fi
  n=$(printf '%s' "$val" | base64 -d 2>/dev/null | wc -c | tr -d ' ')
  if [ "$l" != "-" ] && [ "$n" != "$l" ]; then
    printf '  WRONG   %-22s %s chars, must be %s\n' "$k" "$n" "$l"
    fail=1
  else
    printf '  ok      %-22s %s chars\n' "$k" "$n"
  fi
done <<< "$MAP"

cat <<'TXT'

"absent" is only a problem for the hooks you actually use. A wrong
length is always a problem, and the chart will not tell you.
TXT
exit "$fail"
