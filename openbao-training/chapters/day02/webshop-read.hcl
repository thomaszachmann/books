# Inhalte lesen (KV v2: data/)
path "secret/data/webshop/*" {
  capabilities = ["read"]
}

# Auflisten und Versionen sehen (KV v2: metadata/)
path "secret/metadata/webshop/*" {
  capabilities = ["read", "list"]
}

# Admin-Secret sperren – deny gewinnt immer
path "secret/data/webshop/admin" {
  capabilities = ["deny"]
}
