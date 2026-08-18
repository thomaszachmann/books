# Chapter 9 - recoverable deletion, never permanent destruction.
#
# The security value of this policy is in what is absent:
#   no destroy/  -> no version can be made unrecoverable
#   no delete on metadata/ -> history cannot be wiped

path "meridian/data/tracking" {
  capabilities = ["read", "update", "patch"]
}

path "meridian/metadata/tracking" {
  capabilities = ["read"]
}

path "meridian/delete/tracking" {
  capabilities = ["update"]
}

path "meridian/undelete/tracking" {
  capabilities = ["update"]
}
