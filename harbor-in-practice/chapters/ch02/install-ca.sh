#!/usr/bin/env bash
# Chapter 2, step 7. Install the root into the local trust store.
#
# Three operating systems, three different ideas of what a trust store
# is. This is not Docker being inconsistent.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CA="$ROOT/certs/ca.crt"
HOST="${1:-harbor.meridian.test}"

[ -f "$CA" ] || { echo "No $CA. Run make-certs.sh first." >&2; exit 1; }

case "$(uname -s)" in
  Darwin)
    echo "macOS: adding to the System keychain as a trusted root."
    sudo security add-trusted-cert -d -r trustRoot \
      -k /Library/Keychains/System.keychain "$CA"
    echo
    echo "Now restart Docker Desktop. It reads the keychain at start"
    echo "and not after, which is why this looks like it did nothing."
    ;;
  Linux)
    echo "Linux: Docker reads a directory named after the registry."
    sudo mkdir -p "/etc/docker/certs.d/$HOST"
    sudo cp "$CA" "/etc/docker/certs.d/$HOST/ca.crt"
    echo "Installed to /etc/docker/certs.d/$HOST/ca.crt"
    echo "No restart needed. The directory name must match the host"
    echo "exactly, including the port if you use a non-default one."
    ;;
  *)
    cat <<TXT
Windows, in an Administrator PowerShell:

  Import-Certificate -FilePath certs\\ca.crt \`
    -CertStoreLocation Cert:\\LocalMachine\\Root

Then restart Docker Desktop.
TXT
    ;;
esac
