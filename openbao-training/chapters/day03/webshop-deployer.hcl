# Nur SecretIDs fuer webshop – und nur verpackt
path "auth/approle/role/webshop/secret-id" {
  capabilities = ["update"]
  min_wrapping_ttl = "1m"
  max_wrapping_ttl = "10m"
}
