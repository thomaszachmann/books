terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}

provider "vault" {}   # VAULT_ADDR, VAULT_TOKEN, VAULT_CACERT aus der Umgebung

resource "vault_mount" "kv_shop" {
  path    = "shop-kv"
  type    = "kv"
  options = { version = "2" }
}

resource "vault_policy" "webshop_read" {
  name   = "webshop-read-tf"
  policy = <<-EOT
    path "shop-kv/data/webshop/*" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_auth_backend" "approle" {
  type = "approle"
}

resource "vault_approle_auth_backend_role" "webshop" {
  backend        = vault_auth_backend.approle.path
  role_name      = "webshop"
  token_policies = [vault_policy.webshop_read.name]
  token_ttl      = 3600
}
