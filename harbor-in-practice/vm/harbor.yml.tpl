# Template for Harbor's own configuration file.
#
# Chapter 3 fills the placeholders with envsubst. Chapter 18 replaces
# this file with a Vault Agent template that renders the same fields
# from Vault and restarts Harbor when they change - the placeholders are
# named the same way so the two versions stay comparable.

hostname: ${HARBOR_HOSTNAME}

http:
  port: 80

https:
  port: 443
  certificate: /data/cert/harbor.crt
  private_key: /data/cert/harbor.key

# Chapter 3 sets this once. Chapter 6 explains why nothing in CI should
# ever use it, and Chapter 18 stops it being written to disk at all.
harbor_admin_password: ${HARBOR_ADMIN_PASSWORD}

database:
  password: ${HARBOR_DB_PASSWORD}
  max_idle_conns: 100
  max_open_conns: 900

data_volume: /data

trivy:
  ignore_unfixed: false
  skip_update: false
  offline_scan: false
  security_check: vuln

jobservice:
  max_job_workers: 10

log:
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
    location: /var/log/harbor

_version: 2.15.0

proxy:
  http_proxy:
  https_proxy:
  no_proxy:
  components:
    - core
    - jobservice
    - trivy
