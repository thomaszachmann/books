# Vault Agent fuer Kapitel 14.
#
# Der Punkt dieser Datei ist NICHT der Cache. "cache {}" haelt
# Leases und Token vor, keine Antworten - bei gestopptem Vault
# beantwortet der Proxy gar nichts mehr, auch mit
# cache_static_secrets = true nicht. Was einen Ausfall uebersteht,
# ist ausschliesslich die gerenderte Datei weiter unten.

vault {
  address = "https://vip-vault-1:8200"
  ca_cert = "/tls/cert.pem"
}

auto_auth {
  method "approle" {
    config = {
      role_id_file_path   = "/creds/role_id"
      secret_id_file_path = "/creds/secret_id"
      # sonst ist die secret_id nach dem ersten Start weg und der
      # Agent kommt nach einem Neustart nicht mehr hoch
      remove_secret_id_file_after_reading = false
    }
  }
  sink "file" { config = { path = "/out/token" } }
}

api_proxy {
  # "force", nicht true. Bei true reicht der Agent den Token des
  # Clients durch, falls der einen mitbringt - eine alte
  # VAULT_TOKEN-Variable genuegt - und der Aufruf endet in einem
  # 403 "permission denied / invalid token", der nach einem
  # Policy-Fehler aussieht und keiner ist.
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
