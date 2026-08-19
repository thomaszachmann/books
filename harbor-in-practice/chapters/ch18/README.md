# Chapter 18 — Vault Supplies Harbor

**Starting state:** Chapter 17 finished. `make vault-up` for a
development Vault.

```bash
./secret-keys.sh                          # the mapping
NS=harbor ./secret-keys.sh check harbor-from-vault
```

## Seven hooks, six key names, two length rules

| Chart value | Key the secret must contain | Length |
|---|---|---|
| `existingSecretAdminPassword` | `HARBOR_ADMIN_PASSWORD` | |
| `existingSecretSecretKey` | `secretKey` | 16 |
| `core.existingSecret` | `secret` | 16 |
| `core.existingXsrfSecret` | `CSRF_KEY` | 32 |
| `jobservice.existingSecret` | `JOBSERVICE_SECRET` | |
| `registry.existingSecret` | `REGISTRY_HTTP_SECRET` | |
| `database.external.existingSecret` | `password` | |

None of those names is one anybody would choose, and a wrong one **does
not fail at install time** — the component comes up with an empty or
generated value and misbehaves later. `secret-keys.sh check` compares a
live secret against the table and exits non-zero on a wrong length.

Generate the secret from one definition — the `ExternalSecret` in the
chapter — so that no key name is ever retyped into a values file.

## Rotation is three links with three timings

```
Vault changes   ->  refreshInterval  ->  the k8s secret changes
                ->  component restart ->  Harbor uses it
```

And the admin password is not reread at all — Chapter 3, exercise 3.2.
Rotating it is an API call. Say that in the runbook.
