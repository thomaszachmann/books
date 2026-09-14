# Chapter 22 — Auto-Unseal

**Starting state:** the single-node lab from Chapter 20 (Raft), unsealed.

**What this chapter builds:** auto-unseal three ways, none of which
needs a cloud account or a licence.

## Lab 22 — a second instance as the unsealer

The OpenBao container from Chapter 18 holds one transit key:

```bash
./setup-unsealer.sh       # transit key, policy, periodic token
./migrate-to-autounseal.sh
docker compose restart vault && sleep 6 && vault status

./break-circular.sh       # point the seal at itself, watch it never start
./migrate-to-shamir.sh    # and back, because you should know both
./reproduce-errors.sh
```

The point of the chapter is one line of output after a restart:
`Sealed false`, with nobody having done anything.

## Lab 22b — the unsealer unseals itself: PKCS#11

The Chapter 18 unsealer runs in dev mode and would need a human after a
restart. This one does not: OpenBao behind a `pkcs11` seal, with SoftHSM
standing in for the hardware. Requires the `openbao-hsm` image, built
here with SoftHSM added.

```bash
./setup-hsm.sh               # token, key in the HSM, init, transit key
./migrate-to-hsm-unsealer.sh # Vault's transit seal -> the HSM-sealed unsealer
./reproduce-errors-hsm.sh
```

Swapping SoftHSM for a real HSM changes `lib`, `token_label` and the
token directory. Nothing else. The chapter walks through it for a
YubiHSM 2 and a Nitrokey HSM 2.

## Lab 22c — AWS KMS without AWS

moto answers the KMS API on the laptop; Vault's `awskms` seal takes an
`endpoint`. Everything Vault does is the real API.

```bash
./setup-moto.sh              # a CMK and an alias
./migrate-to-awskms.sh       # transit -> awskms, with the RECOVERY keys
./reproduce-errors-awskms.sh
./migrate-from-awskms.sh     # back, while the key still exists
```

moto keeps its keys in memory. `docker compose stop moto` is a deleted
CMK; `pause` is an outage. The error script uses both, on purpose, and
the deletion on a throwaway Vault only.

## Files

| File | Purpose |
|---|---|
| `../../docker-compose.hsm.yml` | the HSM-sealed unsealer |
| `hsm/Dockerfile` | `openbao-hsm` plus SoftHSM and `pkcs11-tool` |
| `hsm/config/openbao-hsm.hcl` | the `seal "pkcs11"` stanza |
| `../../docker-compose.awskms.yml` | moto and the AWS CLI |
