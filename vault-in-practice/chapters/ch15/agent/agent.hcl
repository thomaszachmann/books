# Chapter 15 - Vault Agent.
#
# remove_secret_id_file_after_reading is false ONLY so the agent can be
# restarted during the lab. Leave it at the default in production: the
# SecretID should exist on disk for milliseconds.

pid_file = "./agent.pid"

vault {
  address = "https://127.0.0.1:8200"
  ca_cert = "../../../tls/vault-cert.pem"
}

auto_auth {
  method "approle" {
    mount_path = "auth/approle"
    config = {
      role_id_file_path   = "./role-id"
      secret_id_file_path = "./secret-id"
      remove_secret_id_file_after_reading = false
    }
  }

  sink "file" {
    config = {
      path = "./agent-token"
      mode = 0600
    }
  }
}

cache {
  use_auto_auth_token = true
}

# 127.0.0.1 only. An agent cache reachable from the network is an
# unauthenticated proxy to Vault.
listener "tcp" {
  address     = "127.0.0.1:8007"
  tls_disable = true
}

template {
  source               = "./app.tpl"
  destination          = "./config.json"
  perms                = 0640
  error_on_missing_key = true
}
