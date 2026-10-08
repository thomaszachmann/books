# Feature-Flags schreiben – nur mit Feld "data"
path "secret/data/webshop/feature-*" {
  capabilities = ["create", "update"]
  required_parameters = ["data"]
}

# Kind-Tokens nur mit webshop-read und TTL 15m/30m (die CLI sendet "15m0s")
path "auth/token/create" {
  capabilities = ["update"]
  allowed_parameters = {
    "policies" = [["webshop-read"]]
    "ttl"      = ["15m0s", "30m0s"]
    "*"        = []
  }
}
