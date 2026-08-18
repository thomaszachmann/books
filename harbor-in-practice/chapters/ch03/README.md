# Chapter 03 — Harbor on a Virtual Machine

**Starting state:** Chapter 2 finished. The VM runs, the name resolves,
`certs/` holds a root and a server certificate.

**What this chapter builds:** a working Harbor, with a real certificate,
reachable by name.

```bash
# on your laptop
multipass exec harbor -- sudo mkdir -p /data/cert
multipass transfer certs/harbor.crt harbor:/tmp/
multipass transfer certs/harbor.key harbor:/tmp/
multipass exec harbor -- sudo mv /tmp/harbor.crt /tmp/harbor.key /data/cert/

# on the VM, in /opt/harbor
./verify-installer.sh offline        # before anything runs as root
./render-harbor-yml.sh harbor.yml
sudo ./install.sh --with-trivy
```

Then, from your laptop:

```bash
../../scripts/wait-for-harbor.sh https://harbor.meridian.test
```

`verify-installer.sh` is not optional ceremony. It is the first control
in the book, and the two `--certificate-` flags are the whole of it —
without them the check confirms that somebody signed the file.

`render-harbor-yml.sh` generates both passwords rather than asking for
them. Chapter 18 replaces the whole script with a Vault Agent template
that renders the same fields, which is why the placeholder names match.
