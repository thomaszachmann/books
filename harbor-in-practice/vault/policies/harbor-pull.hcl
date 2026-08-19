# Chapter 19. What a cluster needs to build an image pull secret.
#
# Read only, one path. The robot token behind it expires - Chapter 6 -
# so this policy grants access to a credential that is already bounded
# in time, which is the point of the arrangement.

path "secret/data/harbor-pull" {
  capabilities = ["read"]
}

path "secret/metadata/harbor-pull" {
  capabilities = ["read", "list"]
}
