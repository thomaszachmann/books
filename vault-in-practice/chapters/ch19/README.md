# Chapter 19 — SSH, Cloud, and Other Engines

**Starting state:** Vault unsealed, root token exported.

**What this chapter builds:** an SSH certificate authority and a server
that trusts it, so you can log in with a certificate that expires on its
own — and never write to `authorized_keys` again.

```bash
./setup-ssh-ca.sh          # CA, role, and the server's trusted-ca.pem
docker compose up -d sshd  # a server with ONE line of configuration
./sign-and-login.sh        # sign a key, inspect it, log in
```

Wait two minutes and run the login again. It fails, and nothing was
revoked.

`ssh-ca/trusted-ca.pem` is generated and git-ignored.
