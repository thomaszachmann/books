#!/usr/bin/env bash
# Chapter 10, Step 3, through the admin API instead of the console.
#
# Builds the meridian-browser flow exactly as the chapter describes:
#
#   meridian-browser forms                          Alternative
#     Level 1                                       Conditional
#       Condition - Level of Authentication         Required (1, 36000 s)
#       Username Password Form                      Required
#     Level 2                                       Conditional
#       Condition - Level of Authentication         Required (2, 300 s)
#       OTP Form                                    Required
#     meridian-browser Browser - Conditional 2FA    Conditional
#       Condition - user role (payments-approver)   Required  <- added
#       ... the copied conditions and OTP Form, unchanged
#
# It does NOT bind the flow; Step 4 does that, on purpose, by hand.
# The console is the better way to learn the shape. This is the way to
# get it back after a reset, and a record of what the clicks mean.
#
#   ./chapters/ch10/build-flow.sh
set -euo pipefail

cd "$(dirname "$0")/../.."
R=(-r meridian)
kc() { docker compose exec -T keycloak /opt/keycloak/bin/kcadm.sh "$@"; }
enc() { printf '%s' "$1" | jq -sRr @uri; }   # flow aliases contain spaces

FLOW=meridian-browser
FORMS="$FLOW forms"
TWOFA="$FLOW Browser - Conditional 2FA"

if kc get authentication/flows "${R[@]}" | jq -e --arg f "$FLOW" \
     'any(.[]; .alias == $f)' >/dev/null; then
  echo "flow $FLOW exists already - bind 'browser', delete it, then rerun" >&2
  exit 1
fi

# id of the direct child of flow $1 with display name $2
child() {
  kc get "authentication/flows/$(enc "$1")/executions" "${R[@]}" \
    | jq -r --arg n "$2" '[.[] | select(.level == 0 and .displayName == $n)][0].id'
}
requirement() {
  kc update "authentication/flows/$(enc "$1")/executions" "${R[@]}" \
    -b "{\"id\":\"$2\",\"requirement\":\"$3\"}"
}
add_step() {   # flow provider requirement
  kc create "authentication/flows/$(enc "$1")/executions/execution" "${R[@]}" \
    -s provider="$2" >/dev/null
  local id
  id=$(kc get "authentication/flows/$(enc "$1")/executions" "${R[@]}" \
         | jq -r --arg p "$2" '[.[] | select(.level == 0 and .providerId == $p)] | last | .id')
  requirement "$1" "$id" "$3"
  echo "$id"
}

kc get roles/payments-approver "${R[@]}" >/dev/null 2>&1 \
  || kc create roles "${R[@]}" -s name=payments-approver

echo "copying browser to $FLOW"
kc create authentication/flows/browser/copy "${R[@]}" -s newName="$FLOW"

echo "adding the role condition to the conditional 2FA subflow"
id=$(add_step "$TWOFA" conditional-user-role REQUIRED)
kc create "authentication/executions/$id/config" "${R[@]}" \
  -s alias=payments-approver-role \
  -s 'config={"condUserRole":"payments-approver","negate":"false"}' >/dev/null

for level in 1 2; do
  echo "adding Level $level"
  kc create "authentication/flows/$(enc "$FORMS")/executions/flow" "${R[@]}" \
    -b "{\"alias\":\"Level $level\",\"type\":\"basic-flow\",\"provider\":\"registration-page-form\",\"description\":\"\"}" >/dev/null
  requirement "$FORMS" "$(child "$FORMS" "Level $level")" CONDITIONAL
  age=36000; [ "$level" = 2 ] && age=300
  id=$(add_step "Level $level" conditional-level-of-authentication REQUIRED)
  kc create "authentication/executions/$id/config" "${R[@]}" \
    -s alias="loa-$level" \
    -s "config={\"loa-condition-level\":\"$level\",\"loa-max-age\":\"$age\"}" >/dev/null
done
add_step "Level 1" auth-username-password-form REQUIRED >/dev/null
add_step "Level 2" auth-otp-form REQUIRED >/dev/null

echo "removing the copied Username Password Form from the forms subflow"
kc delete "authentication/executions/$(child "$FORMS" "Username Password Form")" "${R[@]}"

kc get "authentication/flows/$FLOW/executions" "${R[@]}" \
  | jq -r '.[] | "\("  " * .level)\(.displayName)  [\(.requirement)]"'
echo "done. Not bound - Step 4 binds it."
