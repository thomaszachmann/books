# Chapter 24 - the configuration as code.
#
# Two reasons beyond portability:
#   It is the handover. A repository answers "what is configured" without
#   anybody logging in.
#   It is the recovery. A destroyed cluster is rebuilt by applying this
#   and restoring the data.
#
# What does NOT belong here: secret values. Terraform state records
# everything it manages, in plain text unless the backend encrypts it.
# Manage mounts, policies, roles and engine configuration; let the
# secrets be written by the systems that own them.
#
# On an existing installation, import before you apply:
#   terraform import vault_policy.tracking_read tracking-read
#   terraform plan   # until it proposes nothing

terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

provider "vault" {}

resource "vault_mount" "meridian" {
  path        = "meridian"
  type        = "kv"
  options     = { version = "2" }
  description = "Application secrets"
}

resource "vault_policy" "tracking_read" {
  name = "tracking-read"
  policy = <<-POLICY
    path "meridian/data/tracking" {
      capabilities = ["read"]
    }

    path "meridian/metadata/tracking" {
      capabilities = ["read"]
    }
  POLICY
}

resource "vault_auth_backend" "approle" {
  type = "approle"
}

resource "vault_approle_auth_backend_role" "tracking" {
  backend   = vault_auth_backend.approle.path
  role_name = "tracking"

  token_policies     = [vault_policy.tracking_read.name]
  token_ttl          = 3600
  token_max_ttl      = 14400
  secret_id_ttl      = 600
  secret_id_num_uses = 1
}
