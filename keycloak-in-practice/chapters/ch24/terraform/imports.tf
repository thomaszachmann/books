# Adopt what Chapters 3 to 8 built by hand, instead of creating it.
# Chapter 24, Step 1.
#
# Every resource in main.tf already exists in the realm. Without these
# blocks `terraform apply` tries to create them again and Keycloak
# answers 409 Conflict for the first one. Importing only the realm, as
# an earlier printing of this book did, gets exactly that.
#
# The ids are UUIDs that differ in every lab, so they are looked up
# rather than written down: the data sources run during `plan`, and an
# import id may be anything `plan` can know.
data "keycloak_openid_client" "portal" {
  realm_id  = "meridian"
  client_id = "meridian-portal"
}

data "keycloak_openid_client_scope" "groups" {
  realm_id = "meridian"
  name     = "groups"
}

import {
  to = keycloak_realm.meridian
  id = "meridian"
}

import {
  to = keycloak_openid_client.portal
  id = "meridian/${data.keycloak_openid_client.portal.id}"
}

import {
  to = keycloak_openid_client_scope.groups
  id = "meridian/${data.keycloak_openid_client_scope.groups.id}"
}

import {
  to = keycloak_openid_group_membership_protocol_mapper.groups
  id = "meridian/client-scope/${data.keycloak_openid_client_scope.groups.id}/${var.groups_mapper_id}"
}

# The one id no data source returns. Chapter 24, Step 1 prints the
# kcadm line that finds it.
variable "groups_mapper_id" { type = string }
