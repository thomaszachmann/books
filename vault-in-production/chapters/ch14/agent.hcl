# Vault Agent for Chapter 14.
#
# The point of this file is NOT the cache. "cache {}" keeps leases
# and tokens, and the responses that came with a lease - a static
# KV read is not among them, so with Vault stopped the proxy answers
# nothing for it. cache_static_secrets = true is a Vault Proxy
# option (Enterprise 1.16+); the agent accepts it and ignores it.
# What survives an outage is the rendered file further down.

vault {
  address = "https://vip-vault-1:8200"
  ca_cert = "/tls/cert.pem"
}

auto_auth {
  method "approle" {
    config = {
      role_id_file_path   = "/creds/role_id"
      secret_id_file_path = "/creds/secret_id"
      # otherwise the secret_id is gone after the first start and
      # the agent does not come back after a restart
      remove_secret_id_file_after_reading = false
    }
  }
  sink "file" { config = { path = "/out/token" } }
}

api_proxy {
  # "force", not true. With true the agent passes on the client's
  # own token if it brings one - a stale VAULT_TOKEN variable is
  # enough - and the call ends in a 403 "permission denied /
  # invalid token" that looks like a policy error and is not.
  use_auto_auth_token = "force"
}

cache {}

listener "tcp" {
  address     = "0.0.0.0:8007"
  tls_disable = true
}

template {
  source      = "/tmpl/config.ctmpl"
  destination = "/out/config.ini"
}
