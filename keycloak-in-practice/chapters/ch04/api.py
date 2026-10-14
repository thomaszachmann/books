"""A resource server in one file. Chapter 4 meets it, Chapter 8 satisfies it.

It does what every API in front of Keycloak has to do with a bearer
token, and nothing else:

  1. verify the RS256 signature with the key the header's kid names,
     taken from the realm's JWKS document (found through discovery)
  2. compare iss with the issuer it was configured with
  3. check exp
  4. check that aud contains its own name, AUDIENCE

The answer is 200 with a line of JSON, or 401 with nothing useful in
it - which is what real APIs send. The reason goes to the log:

  docker compose logs api | tail -1

Standard library only, so the whole check is readable here: RS256 is
PKCS#1 v1.5, which is one modular exponentiation and a comparison.
"""
import base64
import hashlib
import hmac
import json
import os
import ssl
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

ISSUER = os.environ.get("ISSUER", "https://sso.meridian.test/realms/meridian")
AUDIENCE = os.environ.get("AUDIENCE", "meridian-api")
CTX = ssl.create_default_context(cafile=os.environ.get("CA_FILE", "/ca.crt"))

# DER prefix of a SHA-256 DigestInfo, RFC 8017 section 9.2.
SHA256_PREFIX = bytes.fromhex("3031300d060960864801650304020105000420")

_keys = {}


def b64url(s):
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def fetch(url):
    with urllib.request.urlopen(url, context=CTX, timeout=5) as r:
        return json.load(r)


def key_for(kid):
    # Re-read the JWKS when a kid is unknown: that is how a validator
    # follows a key rotation without being restarted.
    if kid not in _keys:
        jwks_uri = fetch(ISSUER + "/.well-known/openid-configuration")["jwks_uri"]
        for k in fetch(jwks_uri)["keys"]:
            if k.get("kty") == "RSA" and k.get("use", "sig") == "sig":
                _keys[k["kid"]] = (int.from_bytes(b64url(k["n"]), "big"),
                                   int.from_bytes(b64url(k["e"]), "big"))
    return _keys.get(kid)


def rs256_ok(signing_input, sig, n, e):
    size = (n.bit_length() + 7) // 8
    em = pow(int.from_bytes(sig, "big"), e, n).to_bytes(size, "big")
    digest = SHA256_PREFIX + hashlib.sha256(signing_input).digest()
    expected = b"\x00\x01" + b"\xff" * (size - 3 - len(digest)) + b"\x00" + digest
    return hmac.compare_digest(em, expected)


def check(token):
    """Return (claims, None) or (None, reason)."""
    try:
        h64, p64, s64 = token.split(".")
        header, claims = json.loads(b64url(h64)), json.loads(b64url(p64))
    except ValueError:
        return None, "not a JWT"
    if header.get("alg") != "RS256":
        return None, f"alg {header.get('alg')} is not RS256"
    key = key_for(header.get("kid"))
    if key is None:
        return None, f"no key with kid {header.get('kid')} in the JWKS"
    if not rs256_ok(f"{h64}.{p64}".encode(), b64url(s64), *key):
        return None, "signature does not verify"
    if claims.get("iss") != ISSUER:
        return None, f"iss {claims.get('iss')} is not {ISSUER}"
    if claims.get("exp", 0) <= time.time():
        return None, "expired"
    aud = claims.get("aud")
    aud = aud if isinstance(aud, list) else [aud]
    if AUDIENCE not in aud:
        return None, f"aud {aud} does not contain {AUDIENCE}"
    return claims, None


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        auth = self.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            claims, reason = None, "no bearer token"
        else:
            claims, reason = check(auth[len("Bearer "):].strip())
        if claims is None:
            print(f"401 {reason}")
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Bearer error="invalid_token"')
            self.end_headers()
            return
        print(f"200 {claims.get('preferred_username') or claims.get('sub')}")
        body = json.dumps({k: claims.get(k) for k in
                           ("sub", "preferred_username", "azp", "aud")})
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body.encode() + b"\n")

    def log_message(self, *args):
        pass  # one line per request, from do_GET, is enough


if __name__ == "__main__":
    print(f"api: issuer {ISSUER}, audience {AUDIENCE}, port 8084")
    HTTPServer(("0.0.0.0", 8084), Handler).serve_forever()
