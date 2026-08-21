#!/usr/bin/env bash
# Chapter 2 - every error the chapter prints, on purpose.
#
# Builds its own throwaway Vault under /tmp with deliberately broken
# certificates, so your lab keeps working while you watch these fail.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh

W=$(mktemp -d); trap 'rm -rf "$W"; docker rm -f wwr02 >/dev/null 2>&1' EXIT
mkdir -p "$W/tls" "$W/config" "$W/data"
IMG="hashicorp/vault:1.18"; PORT=18790
ADDR="https://127.0.0.1:$PORT"

# One certificate WITHOUT an IP SAN, one with. Everything else identical.
openssl req -x509 -newkey rsa:2048 -sha256 -days 1 -nodes \
  -keyout "$W/tls/no-san.key" -out "$W/tls/no-san.pem" \
  -subj "/CN=127.0.0.1" 2>/dev/null
openssl req -x509 -newkey rsa:2048 -sha256 -days 1 -nodes \
  -keyout "$W/tls/good.key" -out "$W/tls/good.pem" \
  -subj "/CN=vault" -addext "subjectAltName=IP:127.0.0.1,DNS:localhost" 2>/dev/null
chmod 644 "$W/tls/"*

start() {  # start <cert-base>
  docker rm -f wwr02 >/dev/null 2>&1
  cat > "$W/config/vault.hcl" <<CFG
disable_mlock = true
storage "file" { path = "/vault/data" }
listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/vault/tls/$1.pem"
  tls_key_file  = "/vault/tls/$1.key"
}
api_addr = "$ADDR"
CFG
  docker run -d --rm --name wwr02 -p "$PORT:8200" \
    -v "$W/config:/vault/config:ro" -v "$W/tls:/vault/tls:ro" \
    -v "$W/data:/vault/data" "$IMG" \
    vault server -config=/vault/config/vault.hcl >/dev/null
  for _ in $(seq 30); do
    curl -sk -o /dev/null --max-time 2 "$ADDR/v1/sys/health" && return 0
    sleep 1
  done
}

wwr_case "x509: cannot validate certificate for 127.0.0.1 ... no IP SANs"
start no-san
echo "The certificate has CN=127.0.0.1 and no SAN at all:"
openssl x509 -in "$W/tls/no-san.pem" -noout -subject -ext subjectAltName 2>&1 \
  | grep -v "^No extensions" | sed 's/^/  /'
echo
VAULT_ADDR="$ADDR" VAULT_CACERT="$W/tls/no-san.pem" \
  wwr_expect "legacy Common Name" vault status
echo "Modern TLS clients do not look at the Common Name at all."

wwr_case "x509: certificate signed by unknown authority"
start good
echo "The certificate is fine. The client simply does not trust it:"
VAULT_ADDR="$ADDR" wwr_expect "unknown authority" env -u VAULT_CACERT vault status
echo "VAULT_CACERT is unset, wrong, or was never exported in this shell:"
echo '  $ echo $VAULT_CACERT'
echo "With it set, the same command works:"
VAULT_ADDR="$ADDR" VAULT_CACERT="$W/tls/good.pem" vault status 2>/dev/null \
  | grep -E "Initialized|Sealed" | sed 's/^/  /'
echo
echo "VAULT_SKIP_VERIFY=true also makes it go away, by turning off the"
echo "only protection you have against someone impersonating your Vault:"
VAULT_ADDR="$ADDR" VAULT_SKIP_VERIFY=true vault status 2>/dev/null \
  | grep -E "Initialized" | sed 's/^/  works: /'
echo "It has a way of migrating from a laptop into a deployment script."

wwr_case "failed to initialize barrier: permission denied"
docker rm -f wwr02 >/dev/null 2>&1
chmod 500 "$W/data"
start good
sleep 2
VAULT_ADDR="$ADDR" VAULT_CACERT="$W/tls/good.pem" \
  vault operator init -key-shares=1 -key-threshold=1 2>&1 \
  | sed -n '1,6p' | grep -v '^$' | sed 's/^/  /'
docker logs wwr02 2>&1 | grep -iE "permission denied|barrier" | tail -2 | sed 's/^/  /'
echo "The container runs as an unprivileged user; the host directory"
echo "belongs to you. chmod 777 on a lab directory is acceptable."
chmod 777 "$W/data"

wwr_case "vault: command not found"
if command -v vault >/dev/null; then
  printf '  vault is on this PATH: %s\n' "$(command -v vault)"
  echo "  If it were not, every command in this book would need the"
  echo "  container route instead:"
  echo '    $ docker compose exec -T vault vault status'
else
  echo "  vault is not on this PATH - use the container route:"
  echo '    $ docker compose exec -T vault vault status'
fi
wwr_done
