#!/bin/bash

kg_style() {
    printf '[GRAB] %s\n' "$1"
}

kg_show_found() {
    local found
    local cur
    local by
    cur="$(i3-msg -t get_workspaces 2>/dev/null | sed -n 's/.*"name":"\([^"]*\)","visible":true.*/\1/p' | head -n 1)"
    found=$( { find / -maxdepth 5 \( -path /proc -o -path /sys -o -path /dev -o -path /run \) -prune -o \( -iname '*hill*' -o -iname '*flag*' -o -iname '*owner*' -o -iname '*token*' \) -type f -print 2>/dev/null; } | grep -ivE '^/(usr/lib/python|usr/share|var/lib/dpkg)' | head -n 60 )
    printf '%s\n' "----- OWNER MAP -----"
    printf '%s\n' "WORKSPACE ${cur:-?}"
    printf '%s\n' "BASE ${BASE_DIR}"
    printf '%s\n' "HOST $(hostname 2>/dev/null)"
    printf '%s\n' "IP $(hostname -I 2>/dev/null)"
    printf '%s\n' "KERNEL $(uname -a 2>/dev/null)"
    printf '%s\n' "----- CANDIDATES -----"
    printf '%s\n' "$found"
    printf '%s\n' "----- BINARIES -----"
    { command -v hill-ctl 2>/dev/null; command -v koth 2>/dev/null; command -v claim 2>/dev/null; command -v king 2>/dev/null; command -v kingofhill 2>/dev/null; }
}

kg_show_matrix() {
    local host="$1"
    local mode="${2:-all}"
    local out
    out=$( { find /opt /srv /srv/www /var/www /usr/local/bin /usr/local/sbin /usr/bin /root -maxdepth 4 -type f -perm -4000 -print 2>/dev/null | head -n 30; } )
    printf '%s\n' "SETUID $out"
    printf '%s\n' "SUDO-L $(sudo -n -l 2>/dev/null)"
    printf '%s\n' "TOKEN-ENV ${TEAM_TOKEN:-${TOKEN:-${KING_TOKEN:-}}}" | head -c 200
    printf '\n'
    printf '%s\n' "TOKEN-CHECK $host"
}

kg_show_cap() {
    local host="$1"
    local port="$2"
    local token="$3"
    printf '[GRAB] TARGET %s:%s\n' "$host" "$port"
    printf '[GRAB] TOKEN %s\n' "${token:-EMPTY}"
    printf '[GRAB] KEY %s\n' "$4"
    printf '[GRAB] MODE %s\n' "${5:-queue}"
    printf '[GRAB] WINDOW %s\n' "${6:-none}"
    printf '[GRAB] RESULT %s\n' "$7"
}

kg_send() {
    local host="$1"
    local port="$2"
    local body="$3"
    local token="$4"

    if command -v curl >/dev/null 2>&1; then
        curl -s --max-time 5 -X POST "http://${host}:${port}/" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -H "X-Team-Token: ${token:-${TEAM_TOKEN:-}}" \
            -H "X-Team-Key: ${CAPTURE_KEY}" \
            --data-binary "$body" 2>/dev/null
        return 0
    fi

    printf 'POST / HTTP/1.0\r\nHost: %s\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: %d\r\nX-Team-Token: %s\r\nX-Team-Key: %s\r\nConnection: close\r\n\r\n%s' \
        "$host" "${#body}" "${token:-${TEAM_TOKEN:-}}" "${CAPTURE_KEY}" "$body" >/dev/tcp/"$host"/"$port" 2>/dev/null
}

kg_handle_cap() {
    local host="$1"
    local port="$2"
    local token="$3"
    local body="$4"
    local key="$5"
    local answer
    local result="failed"
    local window="unknown"

    kg_show_cap "$host" "$port" "$token" "$key" "queue" "unknown" "running"

    answer=$(kg_send "$host" "$port" "$body" "$token")
    printf '%s' "$answer" > "${BASE_DIR}/artifacts/cap_${host}_${port}.http" 2>/dev/null

    if printf '%s' "$answer" | grep -qi 'success\|captured\|owned\|claimed'; then
        result="captured"
    elif printf '%s' "$answer" | grep -qi 'protected\|cooldown\|immortal\|shield'; then
        result="protected"
    elif printf '%s' "$answer" | grep -qi 'error\|denied\|invalid'; then
        result="rejected"
    fi

    window=$(printf '%s' "$answer" | sed -n 's/.*\([0-9]\{1,4\}\)[[:space:]]*second.*/\1/p' | head -n 1)

    kg_show_cap "$host" "$port" "$token" "$key" "sent" "${window:-none}" "$result"
}

kw_capture_plot() {
    local host="$1"
    local port="$2"
    local token="${3:-}"
    local key="${4:-}"
    local body="${5:-}"
    local mode="${6:-solo}"

    if [ -z "$host" ] || [ -z "$port" ]; then
        echo -e "\n${TXT_RED_HELLFIRE}[ ! ] CAPTURE REQUIRES --host AND --port${NC}"
        return 1
    fi

    if [ -z "$token" ]; then
        echo -e "\n${TXT_RED_HELLFIRE}[ ! ] CAPTURE REQUIRES --token OR TEAM_TOKEN ENV${NC}"
        return 1
    fi

    if [ -z "$body" ]; then
        body="team_token=${token}&team_key=${key}&action=capture"
    fi

    [ -n "$key" ] || key="$(printf '%s' "${KOTH_TOKEN:-blk}" | sha1sum 2>/dev/null | cut -c1-12)"

    kg_handle_cap "$host" "$port" "$token" "$body" "$key"

    if [ "$mode" == "seed" ]; then
        kw_seed_store "$host" "$port" "$token" "$key" "route"
    fi
}

kw_seed_store() {
    local host="$1"
    local port="$2"
    local token="$3"
    local key="$4"
    local path="${5:-route}"
    local seed_file="${STATE[kw_kit_dir]:-${BASE_DIR}/artifacts/kit}/seed_${host}_${port}"
    local url

    case "$host" in
        http://*|https://*) url="$host" ;;
        *:*) url="http://$host/$path" ;;
        *) url="http://$host:$port/$path" ;;
    esac

    mkdir -p "$(dirname "$seed_file")" 2>/dev/null
    {
        printf '%s\n' "$url"
        printf '%s\n' "$token"
    } > "$seed_file"
    chmod 600 "$seed_file" 2>/dev/null
    echo -e "\n${TXT_VOID}├─${TXT_MID_RED}[ i ] CAPTURE SEED SEALED:${NC} ${TXT_RED_SUPERNOVA}${seed_file}${NC}"
    echo -e "${TXT_VOID}│${NC}   ${TXT_RED_MAGMA}endpoint ${url} // token ${token:0:4}${NC}"
}

kw_capture_help() {
    echo -e "\n${TXT_RED_PLASMA}MX:// CAPTURE ENGINE // HELP${NC}"
    echo -e "${TXT_VOID}──────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${TXT_RED_SUPERNOVA}USAGE${NC}     ${TXT_CORE}./blackwall.sh -K -G <hill-ctl> --host <HILL> --port <PORT> --token <TOKEN> [--key K] [--seed]${NC}"
    echo -e "${TXT_RED_SUPERNOVA}SEED${NC}      ${TXT_RED_MAGMA}--seed persists the capture seed so Hydra re-captures with your token, never a generic one.${NC}"
    echo -e "${TXT_RED_SUPERNOVA}RESPONSES${NC} ${TXT_RED_MAGMA}captured = you own the hill. protected = over-claim shield is up, wait out the window.${NC}"
    echo ""
    echo -e "${TXT_VOID}${ITLC}\"The little window will only be five milliseconds. I hope you're watching.\"${NC}"
}
