ui            = true
disable_mlock = true

storage "raft" {
  path    = "/vault/data"
  node_id = "vault-1"

  retry_join { leader_api_addr = "https://vip-vault-1:8200"
               leader_ca_cert_file = "/vault/tls/cert.pem" }
  retry_join { leader_api_addr = "https://vip-vault-2:8200"
               leader_ca_cert_file = "/vault/tls/cert.pem" }
  retry_join { leader_api_addr = "https://vip-vault-3:8200"
               leader_ca_cert_file = "/vault/tls/cert.pem" }
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/vault/tls/cert.pem"
  tls_key_file  = "/vault/tls/key.pem"
}

api_addr     = "https://vip-vault-1:8200"
cluster_addr = "https://vip-vault-1:8201"
