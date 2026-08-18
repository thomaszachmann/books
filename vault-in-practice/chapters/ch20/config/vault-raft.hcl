# Chapter 20 - Integrated Storage.
#
# cluster_addr is not optional here. Without it Vault runs single-node
# with HA Enabled false, and everything else works - so it goes unnoticed
# until the second node is added.

ui            = true
disable_mlock = false

storage "raft" {
  path    = "/vault/raft"
  node_id = "vault-1"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/vault/tls/vault-cert.pem"
  tls_key_file  = "/vault/tls/vault-key.pem"
}

api_addr     = "https://127.0.0.1:8200"
cluster_addr = "https://127.0.0.1:8201"
