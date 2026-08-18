# Chapter 15 - the agent's own permissions.
#
# The agent removes credential handling from the application. It does not
# remove the permission boundary: this policy is what the application can
# reach through the agent's cache.

path "meridian/data/tracking" {
  capabilities = ["read"]
}
