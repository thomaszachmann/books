# Chapter 4 — OAuth2 and OIDC on the Wire

Expects: Chapter 3 finished, the `meridian` realm exists.

```bash
source chapters/kcadm.sh
```

The chapter runs a complete OIDC login by hand — no library, no
framework. Do that first. `decode-token.sh` here is the same three steps
afterwards, for the chapters that follow:

```bash
./chapters/ch04/decode-token.sh payload < tokens.json
./chapters/ch04/decode-token.sh header  < tokens.json
```

Base64URL is Base64 with two characters swapped and the padding dropped.
The script puts both back, which is the step that makes `base64` stop
complaining.
