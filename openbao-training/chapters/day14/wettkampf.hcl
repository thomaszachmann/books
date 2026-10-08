# Nur Tag 14: Secret reparieren (Szenario 4, 5, 8), Leak im Audit-Log suchen (6)
path "secret/data/webshop/config" { capabilities = ["create","read","update","delete"] }
path "secret/metadata/webshop/config" { capabilities = ["read"] }
path "secret/undelete/webshop/config" { capabilities = ["update"] }
path "sys/audit-hash/datei" { capabilities = ["update"] }
