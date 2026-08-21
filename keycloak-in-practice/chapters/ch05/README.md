# Chapter 5 — SAML on the Wire

Expects: Chapter 4 finished.

```bash
pbpaste | ./chapters/ch05/saml-decode.sh response
```

or, on Linux, paste into the terminal and press Ctrl-D.

A `SAMLResponse` is Base64. A `SAMLRequest` is URL-encoded Base64 of raw
DEFLATE, which is why one decodes in a single step and the other does
not:

```bash
./chapters/ch05/saml-decode.sh request <<< "$REQ"
```

The raw DEFLATE part — `-15` for the window bits, no zlib header — is
the usual mistake, and the resulting error message mentions neither
compression nor headers.
