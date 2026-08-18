# Chapter 10 - read dynamic database credentials and nothing else.
# Deny-by-default covers everything not listed. No explicit deny needed.

path "database/creds/tracking-ro" {
  capabilities = ["read"]
}
