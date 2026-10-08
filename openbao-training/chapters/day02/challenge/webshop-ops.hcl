path "secret/data/webshop/*" {
  capabilities = ["create", "read", "update", "patch", "delete"]
}
path "secret/delete/webshop/*" {
  capabilities = ["update"]
}
path "secret/undelete/webshop/*" {
  capabilities = ["update"]
}
path "secret/metadata/webshop/*" {
  capabilities = ["read", "list"]
}
path "secret/destroy/webshop/*" {
  capabilities = ["deny"]
}
