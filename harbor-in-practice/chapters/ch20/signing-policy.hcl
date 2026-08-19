# The policy a build needs to sign, and nothing more.
#
# update on transit/sign/<key> is the signing operation. read on
# transit/keys/<key> returns public material only - there is no endpoint
# that returns the private half, and the key is created with
# exportable=false so that the export path refuses as well.
#
#   vault policy write harbor-signing chapters/ch20/signing-policy.hcl

path "transit/sign/harbor-signing" {
  capabilities = ["update"]
}

path "transit/keys/harbor-signing" {
  capabilities = ["read"]
}

# Deny explicitly what the two rules above already fail to grant. It
# changes nothing at runtime; it states the intent for whoever reads
# the policy in a year.
path "transit/export/*" {
  capabilities = ["deny"]
}
