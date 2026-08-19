# Chapter 10 — Signing and Verification

**Starting state:** Chapter 9 finished, `prevent_vul` off again.

**What this chapter builds:** a signature, a policy that requires one,
and a demonstration that the policy is narrower than its label.

```bash
COSIGN_PASSWORD=lab ./sign.sh \
  harbor.meridian.test/platform/signed:1.0
./signed-artifacts.sh platform
```

## The one thing to take away

Harbor's signature policy checks that an accessory of type
`signature.cosign` **exists**. It does not verify it.

There is no public key to configure, no certificate identity, no
transparency-log lookup — because Harbor has no field in which to be
told whose signatures are acceptable. An image signed with a key
generated thirty seconds ago satisfies the policy exactly as well as one
signed by your pipeline.

That is not a defect. A registry can see that an object exists; deciding
whether it was made by your build system needs a policy about identity,
and that lives elsewhere:

| Question | Answered by |
|---|---|
| Is there a signature? | Harbor's policy, this chapter |
| Is it one we accept? | admission control, Chapter 16 |
| Can the key be stolen? | Vault transit, Chapter 20 |

## Three ways past the policy

Reasonable individually, and together they define what the control is
for:

- a robot with `scanner-pull` bypasses, or Chapter 9 would deadlock
  against this chapter
- pulling the signature artifact itself bypasses, or you could never
  fetch one to verify
- a caller with **push** rights whose `User-Agent` contains `cosign` or
  `notation` bypasses, because cosign must pull a manifest before
  signing it

The third means the policy is not a boundary against somebody who can
push. It is a guard rail for consumers, and a good one.

## enable_content_trust is Notation now

Not Notary v1, which is removed, and not cosign.

| Setting | Refuses with |
|---|---|
| `enable_content_trust_cosign` | The image is not signed by cosign. |
| `enable_content_trust` | The image is not signed by notation. |

Documentation written before the change says otherwise.
