# Chapter 18. What Harbor's own deployment needs to read.
#
# kv v2 splits the path: data/ for the value, metadata/ for versions.
# A policy that grants only "secret/harbor" grants nothing, because the
# real path is "secret/data/harbor".

path "secret/data/harbor" {
  capabilities = ["read"]
}

path "secret/metadata/harbor" {
  capabilities = ["read", "list"]
}

# The TLS certificate Harbor serves. issue/ mints one; the role bounds
# what it may ask for.
path "pki/issue/harbor" {
  capabilities = ["update"]
}
