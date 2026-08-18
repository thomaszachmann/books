# Chapter 18 — OpenBao

**Starting state:** the Chapter 2 Vault container running and unsealed.
For Lab 18B, the Chapter 16 cluster.

**What this chapter builds:** OpenBao alongside Vault, and evidence about
what is actually compatible.

```bash
docker compose up -d openbao
./compat-report.sh > compat-$(date +%F).txt   # the deliverable
./run-book-against-openbao.sh                 # chapters 6, 9, 12 unchanged
./openbao-k8s.sh                              # Lab 18B
```

`compat-report.sh` is the point of the chapter. Its dated output is
evidence; a feature table in a book is a claim about one moment.
