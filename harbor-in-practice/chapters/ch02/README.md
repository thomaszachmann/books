# Chapter 02 — Building Your Lab

**Starting state:** Docker and Multipass installed. Nothing running.

**What this chapter builds:** the virtual machine, a name that resolves,
a private CA, and a server certificate that Go clients accept.

Harbor is still not installed. That happens in Chapter 3, into a lab
where trust is already solved.

```bash
make check
make vm-up                          # note the printed IP
# add the IP to your hosts file as harbor.meridian.test
./chapters/ch02/make-certs.sh 192.168.64.7
./chapters/ch02/install-ca.sh
```

`make-certs.sh` refuses to finish if the Subject Alternative Name is
missing. That check is there because a certificate without a SAN is
signed correctly, verifies correctly, and is still rejected by every Go
client — Docker, containerd, Harbor and Kubernetes are all Go clients.

Nothing here writes to `certs/` in Git. That directory is ignored.
