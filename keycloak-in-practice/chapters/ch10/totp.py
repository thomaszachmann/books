#!/usr/bin/env python3
"""A TOTP code from a Base32 secret. Chapter 10.

Twenty lines of standard library, so that the lab needs no oathtool and
no phone. It is also the shortest useful demonstration that a one-time
code is not magic: a shared secret, the clock, and HMAC.

  ./totp.py <base32-secret>
  ./totp.py <base32-secret> --at 1787273455

Verified against RFC 6238: the secret GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ
at Unix time 59 gives 287082, and at 1111111109 gives 081804.
"""
import base64
import hashlib
import hmac
import struct
import sys
import time


def totp(secret_b32: str, when: int, step: int = 30, digits: int = 6) -> str:
    # Keycloak prints the secret without padding; base64 wants it back.
    s = secret_b32.strip().replace(" ", "").upper()
    s += "=" * (-len(s) % 8)
    key = base64.b32decode(s)
    counter = struct.pack(">Q", when // step)
    mac = hmac.new(key, counter, hashlib.sha1).digest()
    offset = mac[-1] & 0x0F
    code = struct.unpack(">I", mac[offset:offset + 4])[0] & 0x7FFFFFFF
    return str(code % (10 ** digits)).zfill(digits)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("usage: totp.py <base32-secret> [--at <unix-seconds>]")
    at = int(sys.argv[3]) if "--at" in sys.argv else int(time.time())
    print(totp(sys.argv[1], at))
