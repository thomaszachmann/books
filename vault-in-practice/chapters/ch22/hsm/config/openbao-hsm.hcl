# Chapter 22 - the unsealer, sealed by an HSM.
#
# Compare with Chapter 18: no BAO_DEV_*, real storage, and a seal
# stanza. The PIN sits in this file because it is a lab; in production
# it arrives as BAO_HSM_PIN from the platform and this line is absent.

ui = false

storage "raft" {
  path    = "/openbao/data"
  node_id = "unsealer"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

api_addr     = "http://openbao-hsm:8200"
cluster_addr = "http://openbao-hsm:8201"

seal "pkcs11" {
  lib         = "/usr/lib/softhsm/libsofthsm2.so"
  token_label = "openbao"
  pin         = "1234"
  key_label   = "openbao-unseal"
  mechanism   = "0x1087"   # CKM_AES_GCM
}
