# Chapter 24 — Infrastructure as Code, Observability, and Handover

Expects: everything.

```bash
cd chapters/ch24/terraform
terraform init
terraform import keycloak_realm.meridian meridian
terraform plan
```

`plan` against a realm you built by hand is the most useful output in
this chapter: everything it wants to change is drift between what you
did and what you wrote down.

## What Terraform owns

Realms, clients, scopes, mappers, roles, groups. **Not users** — the
directory owns people, and a state file with four thousand user records
is a data protection question nobody asked for.

## Events

Login events and admin events are separate switches with separate
retention, and both default to off or short. Chapter 24 sets them and
says which retention answers which question.
