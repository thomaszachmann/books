# Chapter 12 - the migration job policy.
#
# This token can upgrade every ciphertext to the newest key version and
# cannot read a single one of them. It is the strongest single argument
# for the transit engine.

path "transit/rewrap/orders" {
  capabilities = ["update"]
}
