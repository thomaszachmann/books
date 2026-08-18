# Chapter 13 - a workload that may request its own certificates.
#
# Note what this policy does NOT control: which names may be issued.
# That is the role's job (allowed_domains, allow_subdomains, max_ttl).
# The policy only decides who may ask.

path "pki_int/issue/meridian-24h" {
  capabilities = ["create", "update"]
}

path "pki_int/sign/meridian-24h" {
  capabilities = ["create", "update"]
}
