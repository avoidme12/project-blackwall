#!/bin/sh
# DESC: claim the hill with your token and print the checker answer
# REQ: curl or python3

P="${BW_PREFIX:-blk_}"
D="${BW_PREFIX_DIR:-/usr/local/sbin/.kworker}"
DRY="${BW_DRY_RUN:-0}"
HILL="${BW_HILL:-}"
CPORT="${BW_CAPTURE_PORT:-80}"
PATHX="${BW_CAPTURE_PATH:-/}"
TOKEN="${BW_TEAM_TOKEN:-${TEAM_TOKEN:-}}"
KEY="${BW_CAPTURE_KEY:-}"
URL="${BW_CAPTURE_URL:-}"
BODY="${BW_CAPTURE_BODY:-}"

say() { printf '[GRAB] %s\n' "$1"; }

[ -n "$TOKEN" ] || { say "BW_TEAM_TOKEN is not set"; exit 1; }
if [ -z "$URL" ]; then
    [ -n "$HILL" ] || { say "BW_HILL or BW_CAPTURE_URL is required"; exit 1; }
    URL="http://${HILL}:${CPORT}${PATHX}"
fi
if [ -z "$BODY" ]; then
    BODY="team_token=${TOKEN}&team_key=${KEY}&action=capture"
fi

say "target $URL"
if [ "$DRY" = "1" ]; then
    say "dry body: $BODY"
    exit 0
fi

if command -v curl >/dev/null 2>&1; then
    INSECURE=""
    case "$URL" in https://*) [ "${BW_CAPTURE_INSECURE:-0}" = "1" ] && INSECURE="-k" ;; esac
    ANSWER="$(curl -sS $INSECURE --max-time 8 -X POST "$URL" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "X-Team-Token: $TOKEN" \
        -H "X-Team-Key: $KEY" \
        --data-binary "$BODY" 2>&1)"
elif command -v python3 >/dev/null 2>&1; then
    ANSWER="$(python3 - "$URL" "$TOKEN" "$KEY" "$BODY" << 'PY'
import ssl
import sys
import urllib.request

url, token, key, body = sys.argv[1:5]
req = urllib.request.Request(
    url,
    data=body.encode(),
    method="POST",
    headers={
        "Content-Type": "application/x-www-form-urlencoded",
        "X-Team-Token": token,
        "X-Team-Key": key,
    },
)
ctx = None
if url.startswith("https://"):
    ctx = ssl._create_unverified_context()
with urllib.request.urlopen(req, timeout=8, context=ctx) as resp:
    sys.stdout.write(resp.read().decode("utf-8", "replace"))
PY
)"
else
    say "curl and python3 are both absent"
    exit 1
fi

printf '%s\n' "$ANSWER"
mkdir -p "$D" 2>/dev/null || true
printf '%s\n' "$ANSWER" > "$D/${P}capture" 2>/dev/null || true
chmod 600 "$D/${P}capture" 2>/dev/null || true

case "$(printf '%s' "$ANSWER" | tr 'A-Z' 'a-z')" in
    *success*|*captured*|*owned*|*claimed*) say "result: captured" ;;
    *protected*|*cooldown*|*immortal*|*shield*) say "result: protected, wait the window" ;;
    *error*|*denied*|*invalid*) say "result: rejected" ;;
    *) say "result: unknown" ;;
esac
