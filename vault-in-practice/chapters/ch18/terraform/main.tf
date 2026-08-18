# Chapter 18 - the same configuration applied to either system.
#
# If this applies cleanly against both, the configuration is portable -
# which is the whole of the chapter's recommendation, demonstrated
# rather than claimed.
#
#   terraform apply -var addr=https://127.0.0.1:8200 -var token=...
#   terraform apply -var addr=http://127.0.0.1:8300  -var token=root
#
# Note: state does NOT transfer. Planning against the other system with
# the same state file proposes to create everything, which is correct and
# is the real cost of a migration.

terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

variable "addr"  { type = string }
variable "token" { type = string, sensitive = true }

provider "vault" {
  address = var.addr
  token   = var.token
}

resource "vault_policy" "tracking" {
  name   = "tf-tracking-read"
  policy = <<-POLICY
    path "meridian/data/tracking" {
      capabilities = ["read"]
    }
  POLICY
}

resource "vault_auth_backend" "approle" {
  type = "approle"
  path = "tf-approle"
}

resource "vault_mount" "transit" {
  path = "tf-transit"
  type = "transit"
}
