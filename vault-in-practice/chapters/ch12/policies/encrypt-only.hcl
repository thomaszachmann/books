# Chapter 12 - for the most exposed tier.
#
# A web front end that accepts customer data can write encrypted records
# and cannot read any existing ones. Decryption belongs to a smaller,
# less exposed service with its own token.

path "transit/encrypt/orders" {
  capabilities = ["update"]
}
