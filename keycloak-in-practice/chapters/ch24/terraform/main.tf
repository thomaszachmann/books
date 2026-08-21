# The realm as reviewed code. Chapter 24.
#
# What belongs here: realms, clients, client scopes, mappers, roles,
# groups - the things that are configuration and that change through a
# review.
#
# What does not: users. The directory owns people (Chapter 12), and a
# Terraform state file containing four thousand user records is both a
# migration hazard and a data protection question nobody asked for.
terraform {
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "~> 5.0"
    }
  }
}

provider "keycloak" {
  client_id = "admin-cli"
  username  = var.admin_username
  password  = var.admin_password
  url       = "https://sso.meridian.test"
  # The lab's private CA. In production this is a public certificate and
  # this line does not exist - see Chapter 16, design review 3.
  root_ca_certificate = file("${path.module}/../../../pki/ca.crt")
}

variable "admin_username" { type = string }
variable "admin_password" {
  type      = string
  sensitive = true
}

resource "keycloak_realm" "meridian" {
  realm                 = "meridian"
  enabled               = true
  display_name          = "Meridian Freight"
  ssl_required          = "external"
  access_token_lifespan = "5m"

  # Chapter 9 chose these deliberately. Here they are reviewable.
  sso_session_idle_timeout = "30m"
  sso_session_max_lifespan = "10h"
}

resource "keycloak_openid_client" "portal" {
  realm_id                     = keycloak_realm.meridian.id
  client_id                    = "meridian-portal"
  enabled                      = true
  access_type                  = "PUBLIC"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false
  valid_redirect_uris          = ["https://app.meridian.test/callback"]

  # Chapter 4 made this mandatory rather than optional, and the
  # difference matters: a client that MAY use PKCE is a client that
  # might not.
  pkce_code_challenge_method = "S256"
}

resource "keycloak_openid_client_scope" "groups" {
  realm_id = keycloak_realm.meridian.id
  name     = "groups"
}

resource "keycloak_openid_group_membership_protocol_mapper" "groups" {
  realm_id        = keycloak_realm.meridian.id
  client_scope_id = keycloak_openid_client_scope.groups.id
  name            = "groups"
  claim_name      = "groups"
  # Chapter 8: decide once. Changing it invalidates every Kubernetes
  # binding at the same moment.
  full_path = false
}
