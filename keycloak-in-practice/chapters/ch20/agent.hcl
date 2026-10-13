# Vault Agent for Keycloak. Chapter 20.
#
# Logs in to Vault as a machine - AppRole, no browser, no Keycloak - and
# writes Keycloak's database credential to a file Keycloak reads at
# start. This is the machine edge of the chapter's graph.
#
# Started by chapters/ch20/compose.yaml; the role id and secret id are
# written to vault/approle/ by chapters/ch20/setup.sh.

vault {
  address = "http://vault:8200"
}

auto_auth {
  method "approle" {
    # A sealed or stopped Vault is retried, but never more than ten
    # seconds apart: the chapter waits for this to recover, and the
    # default backoff grows to five minutes.
    min_backoff = "1s"
    max_backoff = "10s"
    config = {
      role_id_file_path                   = "/vault/approle/role_id"
      secret_id_file_path                 = "/vault/approle/secret_id"
      remove_secret_id_file_after_reading = false
    }
  }
}

template_config {
  # Keep trying while Vault is unavailable instead of giving up after
  # the default number of attempts.
  exit_on_retry_failure = false
  static_secret_render_interval = "1m"
}

template {
  destination = "/vault/out/db.env"
  perms       = "0600"
  contents    = <<EOT
{{ with secret "database/static-creds/keycloak-static" -}}
KC_DB_USERNAME='{{ .Data.username }}'
KC_DB_PASSWORD='{{ .Data.password }}'
{{- end }}
EOT
}
